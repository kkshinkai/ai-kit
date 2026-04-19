import Foundation

public protocol ConvertibleFromGeneratedContent: Sendable {
    init(_ content: GeneratedContent) throws
}

public protocol ConvertibleToGeneratedContent: Sendable {
    var generatedContent: GeneratedContent { get }
}

public protocol Generable: ConvertibleFromGeneratedContent, ConvertibleToGeneratedContent {
    associatedtype PartiallyGenerated: ConvertibleFromGeneratedContent = Self

    static var generationSchema: GenerationSchema { get }
}

extension Generable {
    public func asPartiallyGenerated() -> Self.PartiallyGenerated {
        try! Self.PartiallyGenerated(generatedContent)
    }
}

extension Optional where Wrapped: Generable {
    public typealias PartiallyGenerated = Wrapped.PartiallyGenerated
}

extension Optional: ConvertibleFromGeneratedContent where Wrapped: ConvertibleFromGeneratedContent {
    public init(_ content: GeneratedContent) throws {
        if content.kind == .null {
            self = nil
        } else {
            self = try Wrapped(content)
        }
    }
}

extension Optional: ConvertibleToGeneratedContent where Wrapped: ConvertibleToGeneratedContent {
    public var generatedContent: GeneratedContent {
        switch self {
        case let .some(value):
            value.generatedContent
        case .none:
            GeneratedContent(kind: .null)
        }
    }
}

extension String: Generable {
    public static var generationSchema: GenerationSchema {
        try! GenerationSchema(root: DynamicGenerationSchema(type: Self.self), dependencies: [])
    }

    public init(_ content: GeneratedContent) throws {
        guard case let .string(value) = content.kind else {
            throw GeneratedContentError.typeMismatch(expected: "string", actual: String(describing: content.kind))
        }
        self = value
    }

    public var generatedContent: GeneratedContent {
        GeneratedContent(kind: .string(self))
    }
}

extension Bool: Generable {
    public static var generationSchema: GenerationSchema {
        try! GenerationSchema(root: DynamicGenerationSchema(type: Self.self), dependencies: [])
    }

    public init(_ content: GeneratedContent) throws {
        guard case let .bool(value) = content.kind else {
            throw GeneratedContentError.typeMismatch(expected: "bool", actual: String(describing: content.kind))
        }
        self = value
    }

    public var generatedContent: GeneratedContent {
        GeneratedContent(kind: .bool(self))
    }
}

extension Int: Generable {
    public static var generationSchema: GenerationSchema {
        try! GenerationSchema(root: DynamicGenerationSchema(type: Self.self), dependencies: [])
    }

    public init(_ content: GeneratedContent) throws {
        guard case let .number(value) = content.kind else {
            throw GeneratedContentError.typeMismatch(expected: "number", actual: String(describing: content.kind))
        }

        let intValue = NSDecimalNumber(decimal: value).intValue
        guard Decimal(intValue) == value else {
            throw GeneratedContentError.typeMismatch(expected: "integer", actual: "\(value)")
        }

        self = intValue
    }

    public var generatedContent: GeneratedContent {
        GeneratedContent(kind: .number(Decimal(self)))
    }
}

extension Double: Generable {
    public static var generationSchema: GenerationSchema {
        try! GenerationSchema(root: DynamicGenerationSchema(type: Self.self), dependencies: [])
    }

    public init(_ content: GeneratedContent) throws {
        guard case let .number(value) = content.kind else {
            throw GeneratedContentError.typeMismatch(expected: "number", actual: String(describing: content.kind))
        }
        self = NSDecimalNumber(decimal: value).doubleValue
    }

    public var generatedContent: GeneratedContent {
        GeneratedContent(kind: .number(Decimal(self)))
    }
}

extension Float: Generable {
    public static var generationSchema: GenerationSchema {
        try! GenerationSchema(root: DynamicGenerationSchema(type: Self.self), dependencies: [])
    }

    public init(_ content: GeneratedContent) throws {
        guard case let .number(value) = content.kind else {
            throw GeneratedContentError.typeMismatch(expected: "number", actual: String(describing: content.kind))
        }
        self = NSDecimalNumber(decimal: value).floatValue
    }

    public var generatedContent: GeneratedContent {
        GeneratedContent(kind: .number(Decimal(Double(self))))
    }
}

extension Decimal: Generable {
    public static var generationSchema: GenerationSchema {
        try! GenerationSchema(root: DynamicGenerationSchema(type: Self.self), dependencies: [])
    }

    public init(_ content: GeneratedContent) throws {
        guard case let .number(value) = content.kind else {
            throw GeneratedContentError.typeMismatch(expected: "number", actual: String(describing: content.kind))
        }
        self = value
    }

    public var generatedContent: GeneratedContent {
        GeneratedContent(kind: .number(self))
    }
}

extension Array: ConvertibleFromGeneratedContent where Element: ConvertibleFromGeneratedContent {
    public init(_ content: GeneratedContent) throws {
        guard case let .array(elements) = content.kind else {
            throw GeneratedContentError.typeMismatch(expected: "array", actual: String(describing: content.kind))
        }

        self = try elements.map { try Element($0) }
    }
}

extension Array: ConvertibleToGeneratedContent where Element: ConvertibleToGeneratedContent {
    public var generatedContent: GeneratedContent {
        GeneratedContent(elements: map { $0 })
    }
}

extension Array: Generable where Element: Generable {
    public typealias PartiallyGenerated = [Element.PartiallyGenerated]

    public static var generationSchema: GenerationSchema {
        let element = GenerationSchema.fragment(for: Element.self)
        return try! GenerationSchema(
            root: DynamicGenerationSchema(arrayOf: element.schema),
            dependencies: element.dependencies
        )
    }
}

extension Never: Generable {
    public static var generationSchema: GenerationSchema {
        try! GenerationSchema(root: DynamicGenerationSchema(storage: .any), dependencies: [])
    }

    public init(_ content: GeneratedContent) throws {
        throw GeneratedContentError.invalidValue("Never cannot be decoded from generated content.")
    }

    public var generatedContent: GeneratedContent {
        switch self {}
    }
}
