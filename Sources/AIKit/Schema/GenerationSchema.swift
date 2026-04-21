import Foundation

public struct GenerationSchema: Codable, CustomDebugStringConvertible, Equatable, Sendable {
    public var root: DynamicGenerationSchema
    public var dependencies: [DynamicGenerationSchema]

    public init(type: any Generable.Type, description: String? = nil, properties: [Property]) {
        self.init(
            type: type,
            description: description,
            representNilExplicitlyInGeneratedContent: false,
            properties: properties
        )
    }

    public init(
        type: any Generable.Type,
        description: String? = nil,
        representNilExplicitlyInGeneratedContent explicitNil: Bool,
        properties: [Property]
    ) {
        root = DynamicGenerationSchema(
            name: String(describing: type),
            description: description,
            representNilExplicitlyInGeneratedContent: explicitNil,
            properties: properties.map(\.dynamicProperty)
        )
        dependencies = Self.uniqueDependencies(properties.flatMap(\.dependencies))
    }

    public init(type: any Generable.Type, description: String? = nil, anyOf choices: [String]) {
        root = DynamicGenerationSchema(name: String(describing: type), description: description, anyOf: choices)
        dependencies = []
    }

    public init(type: any Generable.Type, description: String? = nil, anyOf types: [any Generable.Type]) {
        let fragments = types.map(Self.fragment(for:))
        root = DynamicGenerationSchema(
            name: String(describing: type),
            description: description,
            anyOf: fragments.map(\.schema)
        )
        dependencies = Self.uniqueDependencies(fragments.flatMap(\.dependencies))
    }

    public init(root: DynamicGenerationSchema, dependencies: [DynamicGenerationSchema]) throws {
        self.root = root
        self.dependencies = dependencies
        try validate()
    }

    public var jsonSchema: JSONValue {
        var object = root.jsonSchema.objectValue

        if !dependencies.isEmpty {
            object["$defs"] = .object(Dictionary(uniqueKeysWithValues: dependencies.compactMap { dependency in
                guard let name = dependency.name else {
                    return nil
                }
                return (name, dependency.jsonSchema)
            }))
        }

        return .object(object)
    }

    public var debugDescription: String {
        jsonSchema.description
    }

    public struct Property: Codable, Equatable, Sendable {
        let dynamicProperty: DynamicGenerationSchema.Property
        let dependencies: [DynamicGenerationSchema]

        public init<Value>(
            name: String,
            description: String? = nil,
            type: Value.Type,
            guides: [GenerationGuide<Value>] = []
        ) where Value: Generable {
            let fragment = GenerationSchema.fragment(for: type, guides: guides)
            dynamicProperty = DynamicGenerationSchema.Property(
                name: name,
                description: description,
                schema: fragment.schema,
                isOptional: false
            )
            dependencies = fragment.dependencies
        }

        public init<Output>(
            name: String,
            description: String? = nil,
            type: String.Type,
            guides: [Regex<Output>]
        ) {
            self.init(
                name: name,
                description: description,
                type: type,
                guides: guides.map(GenerationGuide<String>.pattern)
            )
        }

        public init<Value>(
            name: String,
            description: String? = nil,
            type: Value?.Type,
            guides: [GenerationGuide<Value>] = []
        ) where Value: Generable {
            let fragment = GenerationSchema.fragment(for: Value.self, guides: guides)
            dynamicProperty = DynamicGenerationSchema.Property(
                name: name,
                description: description,
                schema: fragment.schema,
                isOptional: true
            )
            dependencies = fragment.dependencies
        }

        public init<Output>(
            name: String,
            description: String? = nil,
            type: String?.Type,
            guides: [Regex<Output>]
        ) {
            self.init(
                name: name,
                description: description,
                type: type,
                guides: guides.map(GenerationGuide<String>.pattern)
            )
        }
    }

    public enum SchemaError: Error, Equatable, LocalizedError, Sendable {
        public struct Context: Equatable, Sendable {
            public let debugDescription: String

            public init(debugDescription: String) {
                self.debugDescription = debugDescription
            }
        }

        case duplicateType(schema: String?, type: String, context: Context)
        case duplicateProperty(schema: String, property: String, context: Context)
        case emptyTypeChoices(schema: String, context: Context)
        case undefinedReferences(schema: String?, references: [String], context: Context)

        public var errorDescription: String? {
            switch self {
            case let .duplicateType(schema, type, _):
                if let schema {
                    "Duplicate type '\(type)' in schema '\(schema)'."
                } else {
                    "Duplicate type '\(type)'."
                }
            case let .duplicateProperty(schema, property, _):
                "Duplicate property '\(property)' in schema '\(schema)'."
            case let .emptyTypeChoices(schema, _):
                "Schema '\(schema)' must contain at least one type choice."
            case let .undefinedReferences(schema, references, _):
                if let schema {
                    "Schema '\(schema)' has undefined references: \(references.joined(separator: ", "))."
                } else {
                    "Schema has undefined references: \(references.joined(separator: ", "))."
                }
            }
        }

        public var recoverySuggestion: String? {
            switch self {
            case .duplicateType:
                "Remove the duplicate dependency or merge the referenced schema definitions."
            case .duplicateProperty:
                "Give each property in the schema a unique name."
            case .emptyTypeChoices:
                "Provide at least one type or string choice."
            case .undefinedReferences:
                "Add every referenced schema to the dependencies array."
            }
        }
    }
}

extension GenerationSchema {
    struct Fragment {
        var schema: DynamicGenerationSchema
        var dependencies: [DynamicGenerationSchema]
    }

    static func fragment<Value>(
        for type: Value.Type,
        guides: [GenerationGuide<Value>] = []
    ) -> Fragment where Value: Generable {
        let schema = DynamicGenerationSchema(type: type, guides: guides)
        let source = Value.generationSchema
        return Fragment(schema: schema, dependencies: dependencies(for: schema, source: source))
    }

    static func fragment(for type: any Generable.Type) -> Fragment {
        let source = type.generationSchema
        let schema: DynamicGenerationSchema

        if let name = source.root.name, source.root.isNamedDefinition {
            schema = DynamicGenerationSchema(referenceTo: name)
        } else {
            schema = source.root
        }

        return Fragment(schema: schema, dependencies: dependencies(for: schema, source: source))
    }

    static func uniqueDependencies(_ dependencies: [DynamicGenerationSchema]) -> [DynamicGenerationSchema] {
        var seen: Set<String> = []
        var result: [DynamicGenerationSchema] = []

        for dependency in dependencies {
            guard let name = dependency.name else {
                continue
            }

            guard seen.insert(name).inserted else {
                continue
            }

            result.append(dependency)
        }

        return result
    }

    private static func dependencies(
        for schema: DynamicGenerationSchema,
        source: GenerationSchema
    ) -> [DynamicGenerationSchema] {
        var dependencies = source.dependencies

        if schema.isReference, source.root.isNamedDefinition {
            dependencies.insert(source.root, at: 0)
        }

        return uniqueDependencies(dependencies)
    }
}

private extension GenerationSchema {
    func validate() throws {
        try validateDuplicateTypes()
        try validateSchema(root)

        for dependency in dependencies {
            try validateSchema(dependency)
        }

        let references = root.referencedNames.union(dependencies.reduce(into: Set<String>()) { result, dependency in
            result.formUnion(dependency.referencedNames)
        })
        let dependencyNames = Set(dependencies.compactMap(\.name))
        let missingReferences = references.subtracting(dependencyNames)

        if !missingReferences.isEmpty {
            throw SchemaError.undefinedReferences(
                schema: root.name,
                references: Array(missingReferences).sorted(),
                context: .init(debugDescription: "Every reference must point to a dependency schema.")
            )
        }
    }

    func validateDuplicateTypes() throws {
        var seen: Set<String> = []

        for dependency in dependencies {
            guard let name = dependency.name else {
                continue
            }

            guard seen.insert(name).inserted else {
                throw SchemaError.duplicateType(
                    schema: root.name,
                    type: name,
                    context: .init(debugDescription: "Each dependency name must be unique.")
                )
            }
        }
    }

    func validateSchema(_ schema: DynamicGenerationSchema) throws {
        switch schema.storage {
        case let .object(name, _, _, properties):
            try validateDuplicateProperties(schema: name, properties: properties)
            for property in properties {
                try validateSchema(property.schema)
            }
        case let .array(item, _, _):
            try validateSchema(item)
        case let .schemaChoices(name, _, choices):
            guard !choices.isEmpty else {
                throw SchemaError.emptyTypeChoices(
                    schema: name,
                    context: .init(debugDescription: "Dynamic type choices cannot be empty.")
                )
            }

            for choice in choices {
                try validateSchema(choice)
            }
        case let .stringChoices(name, _, choices):
            guard !choices.isEmpty else {
                throw SchemaError.emptyTypeChoices(
                    schema: name,
                    context: .init(debugDescription: "String choices cannot be empty.")
                )
            }
        case .null, .string, .boolean, .integer, .number, .reference, .any:
            break
        }
    }

    func validateDuplicateProperties(
        schema name: String,
        properties: [DynamicGenerationSchema.Property]
    ) throws {
        var seen: Set<String> = []

        for property in properties {
            guard seen.insert(property.name).inserted else {
                throw SchemaError.duplicateProperty(
                    schema: name,
                    property: property.name,
                    context: .init(debugDescription: "Each property name must be unique within a schema.")
                )
            }
        }
    }
}

private extension JSONValue {
    var objectValue: [String: JSONValue] {
        guard case let .object(value) = self else {
            return [:]
        }
        return value
    }
}

private extension JSONValue {
    var description: String {
        let data = try? JSONEncoder().encode(self)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\(self)"
    }
}
