import Foundation

public struct DynamicGenerationSchema: Codable, Equatable, Sendable {
    indirect enum Storage: Codable, Equatable, Sendable {
        case null
        case string([GenerationGuide<String>.Rule])
        case boolean
        case integer([GenerationGuide<Int>.Rule])
        case number([GenerationGuide<Decimal>.Rule])
        case array(item: DynamicGenerationSchema, minimumElements: Int?, maximumElements: Int?)
        case object(name: String, description: String?, explicitNil: Bool, properties: [Property])
        case schemaChoices(name: String, description: String?, choices: [DynamicGenerationSchema])
        case stringChoices(name: String, description: String?, choices: [String])
        case reference(name: String)
        case any
    }

    let storage: Storage

    public static var null: Self {
        Self(storage: .null)
    }

    public init(name: String, description: String? = nil, properties: [Property]) {
        self.init(
            name: name,
            description: description,
            representNilExplicitlyInGeneratedContent: false,
            properties: properties
        )
    }

    public init(
        name: String,
        description: String? = nil,
        representNilExplicitlyInGeneratedContent explicitNil: Bool,
        properties: [Property]
    ) {
        storage = .object(name: name, description: description, explicitNil: explicitNil, properties: properties)
    }

    public init(name: String, description: String? = nil, anyOf choices: [DynamicGenerationSchema]) {
        storage = .schemaChoices(name: name, description: description, choices: choices)
    }

    public init(name: String, description: String? = nil, anyOf choices: [String]) {
        storage = .stringChoices(name: name, description: description, choices: choices)
    }

    public init(arrayOf itemSchema: DynamicGenerationSchema, minimumElements: Int? = nil, maximumElements: Int? = nil) {
        storage = .array(item: itemSchema, minimumElements: minimumElements, maximumElements: maximumElements)
    }

    public init<Value>(type: Value.Type, guides: [GenerationGuide<Value>] = []) where Value: Generable {
        if Value.self == String.self {
            storage = .string(guides.compactMap { $0 as? GenerationGuide<String> }.flatMap(\.rules))
        } else if Value.self == Bool.self {
            storage = .boolean
        } else if Value.self == Int.self {
            storage = .integer(guides.compactMap { $0 as? GenerationGuide<Int> }.flatMap(\.rules))
        } else if Value.self == Float.self {
            storage = .number(guides.compactMap { $0 as? GenerationGuide<Float> }.flatMap(\.rules).map(\.asDecimalRule))
        } else if Value.self == Double.self {
            storage = .number(guides.compactMap { $0 as? GenerationGuide<Double> }.flatMap(\.rules).map(\.asDecimalRule))
        } else if Value.self == Decimal.self {
            storage = .number(guides.compactMap { $0 as? GenerationGuide<Decimal> }.flatMap(\.rules))
        } else if Value.self == Never.self || Value.self == GeneratedContent.self {
            storage = .any
        } else {
            let root = Value.generationSchema.root
            if case .array = root.storage {
                storage = root.applyingArrayRules(guides.flatMap(\.rules)).storage
            } else if let name = root.name, root.isNamedDefinition {
                storage = .reference(name: name)
            } else {
                storage = root.storage
            }
        }
    }

    public init(referenceTo name: String) {
        storage = .reference(name: name)
    }

    init(storage: Storage) {
        self.storage = storage
    }

    public struct Property: Codable, Equatable, Sendable {
        public var name: String
        public var description: String?
        public var schema: DynamicGenerationSchema
        public var isOptional: Bool

        public init(name: String, description: String? = nil, schema: DynamicGenerationSchema, isOptional: Bool = false) {
            self.name = name
            self.description = description
            self.schema = schema
            self.isOptional = isOptional
        }
    }
}

extension DynamicGenerationSchema {
    var jsonSchema: JSONValue {
        switch storage {
        case .null:
            return .object(["type": .string("null")])
        case let .string(rules):
            return .object(applying(rules, to: ["type": .string("string")]))
        case .boolean:
            return .object(["type": .string("boolean")])
        case let .integer(rules):
            return .object(applying(rules, to: ["type": .string("integer")]))
        case let .number(rules):
            return .object(applying(rules, to: ["type": .string("number")]))
        case let .array(item, minimumElements, maximumElements):
            var object: [String: JSONValue] = [
                "type": .string("array"),
                "items": item.jsonSchema
            ]
            if let minimumElements {
                object["minItems"] = .number(Decimal(minimumElements))
            }
            if let maximumElements {
                object["maxItems"] = .number(Decimal(maximumElements))
            }
            return .object(object)
        case let .object(name, description, _, properties):
            var propertiesObject: [String: JSONValue] = [:]
            var required: [JSONValue] = []

            for property in properties {
                var propertySchema = property.schema.jsonSchema.objectValue
                if let description = property.description {
                    propertySchema["description"] = .string(description)
                }
                propertiesObject[property.name] = .object(propertySchema)

                if !property.isOptional {
                    required.append(.string(property.name))
                }
            }

            var object: [String: JSONValue] = [
                "type": .string("object"),
                "title": .string(name),
                "properties": .object(propertiesObject),
                "required": .array(required),
                "additionalProperties": .bool(false)
            ]

            if let description {
                object["description"] = .string(description)
            }

            return .object(object)
        case let .schemaChoices(name, description, choices):
            var object: [String: JSONValue] = [
                "title": .string(name),
                "anyOf": .array(choices.map(\.jsonSchema))
            ]

            if let description {
                object["description"] = .string(description)
            }

            return .object(object)
        case let .stringChoices(name, description, choices):
            var object: [String: JSONValue] = [
                "type": .string("string"),
                "title": .string(name),
                "enum": .array(choices.map { .string($0) })
            ]

            if let description {
                object["description"] = .string(description)
            }

            return .object(object)
        case let .reference(name):
            return .object(["$ref": .string("#/$defs/\(name)")])
        case .any:
            return .object([:])
        }
    }

    var referencedNames: Set<String> {
        switch storage {
        case .null, .string, .boolean, .integer, .number, .stringChoices, .any:
            return []
        case let .array(item, _, _):
            return item.referencedNames
        case let .object(_, _, _, properties):
            return properties.reduce(into: []) { references, property in
                references.formUnion(property.schema.referencedNames)
            }
        case let .schemaChoices(_, _, choices):
            return choices.reduce(into: []) { references, choice in
                references.formUnion(choice.referencedNames)
            }
        case let .reference(name):
            return [name]
        }
    }

    var name: String? {
        switch storage {
        case let .object(name, _, _, _),
             let .schemaChoices(name, _, _),
             let .stringChoices(name, _, _),
             let .reference(name):
            name
        case .null, .string, .boolean, .integer, .number, .array, .any:
            nil
        }
    }

    var isReference: Bool {
        if case .reference = storage {
            return true
        }
        return false
    }

    var isNamedDefinition: Bool {
        switch storage {
        case .object, .schemaChoices, .stringChoices:
            return true
        case .null, .string, .boolean, .integer, .number, .array, .reference, .any:
            return false
        }
    }

    private func applyingArrayRules<Value>(_ rules: [GenerationGuide<Value>.Rule]) -> DynamicGenerationSchema {
        guard case let .array(currentItem, currentMinimumElements, currentMaximumElements) = storage else {
            return self
        }

        var item = currentItem
        var minimumElements = currentMinimumElements
        var maximumElements = currentMaximumElements

        for rule in rules {
            switch rule {
            case let .minimumCount(value):
                minimumElements = value
            case let .maximumCount(value):
                maximumElements = value
            case let .element(schema):
                item = schema
            case .stringConstant, .stringAnyOf, .stringPattern, .stringRegex, .integerMinimum, .integerMaximum, .numberMinimum, .numberMaximum:
                break
            }
        }

        return DynamicGenerationSchema(arrayOf: item, minimumElements: minimumElements, maximumElements: maximumElements)
    }

    private func applying(_ rules: [GenerationGuide<String>.Rule], to object: [String: JSONValue]) -> [String: JSONValue] {
        rules.reduce(into: object) { result, rule in
            switch rule {
            case let .stringConstant(value):
                result["const"] = .string(value)
            case let .stringAnyOf(values):
                result["enum"] = .array(values.map { .string($0) })
            case let .stringPattern(pattern):
                result["pattern"] = .string(pattern)
            case .stringRegex, .integerMinimum, .integerMaximum, .numberMinimum, .numberMaximum, .minimumCount, .maximumCount, .element:
                break
            }
        }
    }

    private func applying(_ rules: [GenerationGuide<Int>.Rule], to object: [String: JSONValue]) -> [String: JSONValue] {
        rules.reduce(into: object) { result, rule in
            switch rule {
            case let .integerMinimum(value):
                result["minimum"] = .number(Decimal(value))
            case let .integerMaximum(value):
                result["maximum"] = .number(Decimal(value))
            case .stringConstant, .stringAnyOf, .stringPattern, .stringRegex, .numberMinimum, .numberMaximum, .minimumCount, .maximumCount, .element:
                break
            }
        }
    }

    private func applying(_ rules: [GenerationGuide<Decimal>.Rule], to object: [String: JSONValue]) -> [String: JSONValue] {
        rules.reduce(into: object) { result, rule in
            switch rule {
            case let .numberMinimum(value):
                result["minimum"] = .number(value)
            case let .numberMaximum(value):
                result["maximum"] = .number(value)
            case .stringConstant, .stringAnyOf, .stringPattern, .stringRegex, .integerMinimum, .integerMaximum, .minimumCount, .maximumCount, .element:
                break
            }
        }
    }
}

private extension GenerationGuide.Rule {
    var asDecimalRule: GenerationGuide<Decimal>.Rule {
        switch self {
        case let .numberMinimum(value):
            .numberMinimum(value)
        case let .numberMaximum(value):
            .numberMaximum(value)
        case let .integerMinimum(value):
            .numberMinimum(Decimal(value))
        case let .integerMaximum(value):
            .numberMaximum(Decimal(value))
        case let .stringConstant(value):
            .stringConstant(value)
        case let .stringAnyOf(values):
            .stringAnyOf(values)
        case let .stringPattern(pattern):
            .stringPattern(pattern)
        case let .stringRegex(description):
            .stringRegex(description)
        case let .minimumCount(value):
            .minimumCount(value)
        case let .maximumCount(value):
            .maximumCount(value)
        case let .element(schema):
            .element(schema)
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
