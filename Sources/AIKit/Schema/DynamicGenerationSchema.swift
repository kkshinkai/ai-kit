import Foundation

public struct DynamicGenerationSchema: Codable, Equatable, Sendable {
    indirect enum Storage: Codable, Equatable, Sendable {
        case null
        case string([GenerationGuide<String>.Rule])
        case boolean
        case integer([GenerationGuide<Int>.Rule])
        case number([GenerationGuide<Decimal>.Rule])
        case array(item: DynamicGenerationSchema, minimumElements: Int?, maximumElements: Int?)
        case object(name: String, description: String?, properties: [Property])
        case anyOf(name: String, description: String?, choices: [String])
        case reference(name: String)
        case any
    }

    let storage: Storage

    public static var null: Self {
        Self(storage: .null)
    }

    public init(name: String, description: String? = nil, properties: [Property]) {
        storage = .object(name: name, description: description, properties: properties)
    }

    public init(name: String, description: String? = nil, anyOf choices: [String]) {
        storage = .anyOf(name: name, description: description, choices: choices)
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
        } else if Value.self == Double.self {
            storage = .number(guides.compactMap { $0 as? GenerationGuide<Double> }.flatMap(\.rules).map(\.asDecimalRule))
        } else if Value.self == Decimal.self {
            storage = .number(guides.compactMap { $0 as? GenerationGuide<Decimal> }.flatMap(\.rules))
        } else if Value.self == Never.self || Value.self == GeneratedContent.self {
            storage = .any
        } else {
            storage = Value.generationSchema.root.applyingArrayRules(guides.flatMap(\.rules)).storage
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
        case let .object(name, description, properties):
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
        case let .anyOf(name, description, choices):
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
        case .null, .string, .boolean, .integer, .number, .anyOf, .any:
            return []
        case let .array(item, _, _):
            return item.referencedNames
        case let .object(_, _, properties):
            return properties.reduce(into: []) { references, property in
                references.formUnion(property.schema.referencedNames)
            }
        case let .reference(name):
            return [name]
        }
    }

    var name: String? {
        switch storage {
        case let .object(name, _, _), let .anyOf(name, _, _), let .reference(name):
            name
        case .null, .string, .boolean, .integer, .number, .array, .any:
            nil
        }
    }

    private func applyingArrayRules<Value>(_ rules: [GenerationGuide<Value>.Rule]) -> DynamicGenerationSchema {
        guard case let .array(item, currentMinimumElements, currentMaximumElements) = storage else {
            return self
        }

        var minimumElements = currentMinimumElements
        var maximumElements = currentMaximumElements

        for rule in rules {
            switch rule {
            case let .minimumCount(value):
                minimumElements = value
            case let .maximumCount(value):
                maximumElements = value
            case .stringConstant, .stringAnyOf, .stringPattern, .integerMinimum, .integerMaximum, .numberMinimum, .numberMaximum:
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
            case .integerMinimum, .integerMaximum, .numberMinimum, .numberMaximum, .minimumCount, .maximumCount:
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
            case .stringConstant, .stringAnyOf, .stringPattern, .numberMinimum, .numberMaximum, .minimumCount, .maximumCount:
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
            case .stringConstant, .stringAnyOf, .stringPattern, .integerMinimum, .integerMaximum, .minimumCount, .maximumCount:
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
        case let .minimumCount(value):
            .minimumCount(value)
        case let .maximumCount(value):
            .maximumCount(value)
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
