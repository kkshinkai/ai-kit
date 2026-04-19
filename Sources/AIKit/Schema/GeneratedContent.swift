import Foundation

public struct GeneratedContent: Equatable, Sendable {
    public var id: GenerationID?
    public var kind: Kind

    public enum Kind: Equatable, Sendable {
        case null
        case bool(Bool)
        case number(Decimal)
        case string(String)
        case array([GeneratedContent])
        case structure(properties: [String: GeneratedContent], orderedKeys: [String])
    }

    public init(kind: Kind, id: GenerationID? = nil) {
        self.id = id
        self.kind = kind
    }

    public init(properties: KeyValuePairs<String, any ConvertibleToGeneratedContent>, id: GenerationID? = nil) {
        var propertiesByName: [String: GeneratedContent] = [:]
        var orderedKeys: [String] = []

        for (name, value) in properties {
            propertiesByName[name] = value.generatedContent
            orderedKeys.append(name)
        }

        self.init(kind: .structure(properties: propertiesByName, orderedKeys: orderedKeys), id: id)
    }

    public init<S>(
        properties: S,
        id: GenerationID? = nil
    ) where S: Sequence, S.Element == (name: String, value: any ConvertibleToGeneratedContent) {
        var propertiesByName: [String: GeneratedContent] = [:]
        var orderedKeys: [String] = []

        for (name, value) in properties {
            propertiesByName[name] = value.generatedContent
            orderedKeys.append(name)
        }

        self.init(kind: .structure(properties: propertiesByName, orderedKeys: orderedKeys), id: id)
    }

    public init<S>(
        properties: S,
        id: GenerationID? = nil,
        uniquingKeysWith combine: (GeneratedContent, GeneratedContent) throws -> any ConvertibleToGeneratedContent
    ) rethrows where S: Sequence, S.Element == (name: String, value: any ConvertibleToGeneratedContent) {
        var propertiesByName: [String: GeneratedContent] = [:]
        var orderedKeys: [String] = []

        for (name, value) in properties {
            let generatedContent = value.generatedContent

            if let existing = propertiesByName[name] {
                propertiesByName[name] = try combine(existing, generatedContent).generatedContent
            } else {
                propertiesByName[name] = generatedContent
                orderedKeys.append(name)
            }
        }

        self.init(kind: .structure(properties: propertiesByName, orderedKeys: orderedKeys), id: id)
    }

    public init<S>(elements: S, id: GenerationID? = nil) where S: Sequence, S.Element == any ConvertibleToGeneratedContent {
        self.init(kind: .array(elements.map(\.generatedContent)), id: id)
    }

    public init(_ value: some ConvertibleToGeneratedContent) {
        self = value.generatedContent
    }

    public init(_ value: some ConvertibleToGeneratedContent, id: GenerationID) {
        self = value.generatedContent
        self.id = id
    }

    public init(json: String) throws {
        guard let data = json.data(using: .utf8) else {
            throw GeneratedContentError.invalidJSON("The JSON string is not valid UTF-8.")
        }

        do {
            let jsonValue = try JSONDecoder().decode(JSONValue.self, from: data)
            self = GeneratedContent(jsonValue: jsonValue)
        } catch {
            throw GeneratedContentError.invalidJSON(error.localizedDescription)
        }
    }

    public var isComplete: Bool {
        switch kind {
        case .null, .bool, .number, .string:
            true
        case let .array(elements):
            elements.allSatisfy(\.isComplete)
        case let .structure(properties, _):
            properties.values.allSatisfy(\.isComplete)
        }
    }

    public var jsonValue: JSONValue {
        switch kind {
        case .null:
            .null
        case let .bool(value):
            .bool(value)
        case let .number(value):
            .number(value)
        case let .string(value):
            .string(value)
        case let .array(elements):
            .array(elements.map(\.jsonValue))
        case let .structure(properties, _):
            .object(properties.mapValues(\.jsonValue))
        }
    }

    public var jsonString: String {
        let data = try! JSONEncoder().encode(jsonValue)
        return String(data: data, encoding: .utf8)!
    }

    public func value<Value>(_ type: Value.Type = Value.self) throws -> Value where Value: ConvertibleFromGeneratedContent {
        try Value(self)
    }

    public func value<Value>(
        _ type: Value.Type = Value.self,
        forProperty property: String
    ) throws -> Value where Value: ConvertibleFromGeneratedContent {
        guard case let .structure(properties, _) = kind else {
            throw GeneratedContentError.typeMismatch(expected: "structure", actual: kind.debugName)
        }

        guard let value = properties[property] else {
            throw GeneratedContentError.missingProperty(property)
        }

        return try Value(value)
    }

    public func value<Value>(
        _ type: Value?.Type = Value?.self,
        forProperty property: String
    ) throws -> Value? where Value: ConvertibleFromGeneratedContent {
        guard case let .structure(properties, _) = kind else {
            throw GeneratedContentError.typeMismatch(expected: "structure", actual: kind.debugName)
        }

        guard let value = properties[property], value.kind != .null else {
            return nil
        }

        return try Value(value)
    }
}

extension GeneratedContent: Codable {
    public init(from decoder: Decoder) throws {
        let jsonValue = try JSONValue(from: decoder)
        self.init(jsonValue: jsonValue)
    }

    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

extension GeneratedContent: ConvertibleFromGeneratedContent, ConvertibleToGeneratedContent, Generable {
    public static var generationSchema: GenerationSchema {
        try! GenerationSchema(root: DynamicGenerationSchema(storage: .any), dependencies: [])
    }

    public init(_ content: GeneratedContent) {
        self = content
    }

    public var generatedContent: GeneratedContent {
        self
    }
}

private extension GeneratedContent {
    init(jsonValue: JSONValue, id: GenerationID? = nil) {
        switch jsonValue {
        case .null:
            self.init(kind: .null, id: id)
        case let .bool(value):
            self.init(kind: .bool(value), id: id)
        case let .number(value):
            self.init(kind: .number(value), id: id)
        case let .string(value):
            self.init(kind: .string(value), id: id)
        case let .array(value):
            self.init(kind: .array(value.map { GeneratedContent(jsonValue: $0) }), id: id)
        case let .object(value):
            self.init(
                kind: .structure(
                    properties: value.mapValues { GeneratedContent(jsonValue: $0) },
                    orderedKeys: Array(value.keys)
                ),
                id: id
            )
        }
    }
}

private extension GeneratedContent.Kind {
    var debugName: String {
        switch self {
        case .null: "null"
        case .bool: "bool"
        case .number: "number"
        case .string: "string"
        case .array: "array"
        case .structure: "structure"
        }
    }
}
