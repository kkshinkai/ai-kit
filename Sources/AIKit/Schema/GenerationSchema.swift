import Foundation

public struct GenerationSchema: Codable, Equatable, Sendable {
    public var root: DynamicGenerationSchema
    public var dependencies: [DynamicGenerationSchema]

    public init(type: any Generable.Type, description: String? = nil, properties: [Property]) {
        root = DynamicGenerationSchema(
            name: String(describing: type),
            description: description,
            properties: properties.map(\.dynamicProperty)
        )
        dependencies = []
    }

    public init(type: any Generable.Type, description: String? = nil, anyOf choices: [String]) {
        root = DynamicGenerationSchema(name: String(describing: type), description: description, anyOf: choices)
        dependencies = []
    }

    public init(root: DynamicGenerationSchema, dependencies: [DynamicGenerationSchema] = []) throws {
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

    public struct Property: Codable, Equatable, Sendable {
        let dynamicProperty: DynamicGenerationSchema.Property

        public init<Value>(
            name: String,
            description: String? = nil,
            type: Value.Type,
            guides: [GenerationGuide<Value>] = []
        ) where Value: Generable {
            dynamicProperty = DynamicGenerationSchema.Property(
                name: name,
                description: description,
                schema: DynamicGenerationSchema(type: type, guides: guides),
                isOptional: false
            )
        }

        public init<Value>(
            name: String,
            description: String? = nil,
            type: Value?.Type,
            guides: [GenerationGuide<Value>] = []
        ) where Value: Generable {
            dynamicProperty = DynamicGenerationSchema.Property(
                name: name,
                description: description,
                schema: DynamicGenerationSchema(type: Value.self, guides: guides),
                isOptional: true
            )
        }
    }
}

public enum GenerationSchemaError: Error, Equatable, Sendable {
    case duplicateProperty(schema: String, property: String)
    case duplicateType(String)
    case undefinedReferences([String])
}

private extension GenerationSchema {
    func validate() throws {
        var dependencyNames: Set<String> = []

        for dependency in dependencies {
            guard let name = dependency.name else {
                continue
            }
            guard dependencyNames.insert(name).inserted else {
                throw GenerationSchemaError.duplicateType(name)
            }
        }

        let references = root.referencedNames.union(dependencies.reduce(into: Set<String>()) { result, dependency in
            result.formUnion(dependency.referencedNames)
        })
        let missingReferences = references.subtracting(dependencyNames)

        if !missingReferences.isEmpty {
            throw GenerationSchemaError.undefinedReferences(Array(missingReferences).sorted())
        }

        try validateDuplicateProperties(in: root)
        for dependency in dependencies {
            try validateDuplicateProperties(in: dependency)
        }
    }

    func validateDuplicateProperties(in schema: DynamicGenerationSchema) throws {
        guard case let .object(name, _, properties) = schema.storage else {
            return
        }

        var seen: Set<String> = []
        for property in properties {
            guard seen.insert(property.name).inserted else {
                throw GenerationSchemaError.duplicateProperty(schema: name, property: property.name)
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
