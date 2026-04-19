@testable import AIKitMacros
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Test func generableStructMacroExpansion() {
    assertMacroExpansion(
        """
        @Generable(description: "Arguments.")
        struct Arguments {
            @Guide(description: "City")
            var city: String
        }
        """,
        expandedSource:
        """
        struct Arguments {
            var city: String

            public static var generationSchema: AIKit.GenerationSchema {
                AIKit.GenerationSchema(
                    type: Self.self, description: "Arguments.",
                    properties: [
                        AIKit.GenerationSchema.Property(name: "city", description: "City", type: String.self)
                    ]
                )
            }

            public var generatedContent: AIKit.GeneratedContent {
                let explicitNil = false
                var properties = [(name: String, value: any AIKit.ConvertibleToGeneratedContent)]()
                addProperty(name: "city", value: self.city)
                return AIKit.GeneratedContent(
                    properties: properties,
                    uniquingKeysWith: { _, second in
                        second
                    }
                )

                func addProperty(name: String, value: some AIKit.Generable) {
                    properties.append((name: name, value: value))
                }

                func addProperty(name: String, value: (some AIKit.Generable)?) {
                    if explicitNil || value != nil {
                        properties.append((name: name, value: value))
                    }
                }
            }

            public struct PartiallyGenerated: Swift.Identifiable, AIKit.ConvertibleFromGeneratedContent {
                public var id: AIKit.GenerationID
                public var city: String.PartiallyGenerated?

                public init(_ content: AIKit.GeneratedContent) throws {
                    self.id = content.id ?? AIKit.GenerationID()
                    self.city = try content.value(forProperty: "city")
                }
            }
        }

        extension Arguments: AIKit.Generable {
            public init(_ content: AIKit.GeneratedContent) throws {
                self.city = try content.value(forProperty: "city")
            }
        }
        """,
        macros: testMacros
    )
}

@Test func explicitNilGenerableStructMacroExpansion() {
    assertMacroExpansion(
        """
        @Generable(description: "Arguments.", representNilExplicitlyInGeneratedContent: true)
        struct Arguments {
            var city: String?
        }
        """,
        expandedSource:
        """
        struct Arguments {
            var city: String?

            public static var generationSchema: AIKit.GenerationSchema {
                AIKit.GenerationSchema(
                    type: Self.self, description: "Arguments.", representNilExplicitlyInGeneratedContent: true,
                    properties: [
                        AIKit.GenerationSchema.Property(name: "city", type: String?.self)
                    ]
                )
            }

            public var generatedContent: AIKit.GeneratedContent {
                let explicitNil = true
                var properties = [(name: String, value: any AIKit.ConvertibleToGeneratedContent)]()
                addProperty(name: "city", value: self.city)
                return AIKit.GeneratedContent(
                    properties: properties,
                    uniquingKeysWith: { _, second in
                        second
                    }
                )

                func addProperty(name: String, value: some AIKit.Generable) {
                    properties.append((name: name, value: value))
                }

                func addProperty(name: String, value: (some AIKit.Generable)?) {
                    if explicitNil || value != nil {
                        properties.append((name: name, value: value))
                    }
                }
            }

            public struct PartiallyGenerated: Swift.Identifiable, AIKit.ConvertibleFromGeneratedContent {
                public var id: AIKit.GenerationID
                public var city: String?.PartiallyGenerated?

                public init(_ content: AIKit.GeneratedContent) throws {
                    self.id = content.id ?? AIKit.GenerationID()
                    self.city = try content.value(forProperty: "city")
                }
            }
        }

        extension Arguments: AIKit.Generable {
            public init(_ content: AIKit.GeneratedContent) throws {
                self.city = try content.value(forProperty: "city")
            }
        }
        """,
        macros: testMacros
    )
}

@Test func regexGuideStructMacroExpansion() {
    assertMacroExpansion(
        """
        @Generable(description: "Arguments.")
        struct Arguments {
            @Guide(description: "Airport code", /^[A-Z]{3}$/)
            var code: String
        }
        """,
        expandedSource:
        """
        struct Arguments {
            var code: String

            public static var generationSchema: AIKit.GenerationSchema {
                AIKit.GenerationSchema(
                    type: Self.self, description: "Arguments.",
                    properties: [
                        AIKit.GenerationSchema.Property(name: "code", description: "Airport code", type: String.self, guides: [AIKit.GenerationGuide<String>.pattern("^[A-Z]{3}$")])
                    ]
                )
            }

            public var generatedContent: AIKit.GeneratedContent {
                let explicitNil = false
                var properties = [(name: String, value: any AIKit.ConvertibleToGeneratedContent)]()
                addProperty(name: "code", value: self.code)
                return AIKit.GeneratedContent(
                    properties: properties,
                    uniquingKeysWith: { _, second in
                        second
                    }
                )

                func addProperty(name: String, value: some AIKit.Generable) {
                    properties.append((name: name, value: value))
                }

                func addProperty(name: String, value: (some AIKit.Generable)?) {
                    if explicitNil || value != nil {
                        properties.append((name: name, value: value))
                    }
                }
            }

            public struct PartiallyGenerated: Swift.Identifiable, AIKit.ConvertibleFromGeneratedContent {
                public var id: AIKit.GenerationID
                public var code: String.PartiallyGenerated?

                public init(_ content: AIKit.GeneratedContent) throws {
                    self.id = content.id ?? AIKit.GenerationID()
                    self.code = try content.value(forProperty: "code")
                }
            }
        }

        extension Arguments: AIKit.Generable {
            public init(_ content: AIKit.GeneratedContent) throws {
                self.code = try content.value(forProperty: "code")
            }
        }
        """,
        macros: testMacros
    )
}

@Test func generatedStructSupportsCommonStoredPropertyForms() {
    assertMacroExpansion(
        """
        @propertyWrapper
        struct Box<Value> {
            var wrappedValue: Value
        }

        let codeGuide = AIKit.GenerationGuide<String>.pattern("^ok")

        @Generable(description: "Arguments.")
        struct Arguments {
            @Guide(description: "Name", codeGuide)
            let name: String

            var count: Int = 1

            @Box
            var tag: String = "ok"

            var note: String?

            static var ignoredStatic: String = "ignored"
            var ignoredComputed: String { "ignored" }
            lazy var ignoredLazy: String = "ignored"
        }
        """,
        expandedSource:
        """
        @propertyWrapper
        struct Box<Value> {
            var wrappedValue: Value
        }

        let codeGuide = AIKit.GenerationGuide<String>.pattern("^ok")

        struct Arguments {
            let name: String

            var count: Int = 1

            @Box
            var tag: String = "ok"

            var note: String?

            static var ignoredStatic: String = "ignored"
            var ignoredComputed: String { "ignored" }
            lazy var ignoredLazy: String = "ignored"

            public static var generationSchema: AIKit.GenerationSchema {
                AIKit.GenerationSchema(
                    type: Self.self, description: "Arguments.",
                    properties: [
                        AIKit.GenerationSchema.Property(name: "name", description: "Name", type: String.self, guides: [codeGuide]),
                        AIKit.GenerationSchema.Property(name: "count", type: Int.self),
                        AIKit.GenerationSchema.Property(name: "tag", type: String.self),
                        AIKit.GenerationSchema.Property(name: "note", type: String?.self)
                    ]
                )
            }

            public var generatedContent: AIKit.GeneratedContent {
                let explicitNil = false
                var properties = [(name: String, value: any AIKit.ConvertibleToGeneratedContent)]()
                addProperty(name: "name", value: self.name)
                addProperty(name: "count", value: self.count)
                addProperty(name: "tag", value: self.tag)
                addProperty(name: "note", value: self.note)
                return AIKit.GeneratedContent(
                    properties: properties,
                    uniquingKeysWith: { _, second in
                        second
                    }
                )

                func addProperty(name: String, value: some AIKit.Generable) {
                    properties.append((name: name, value: value))
                }

                func addProperty(name: String, value: (some AIKit.Generable)?) {
                    if explicitNil || value != nil {
                        properties.append((name: name, value: value))
                    }
                }
            }

            public struct PartiallyGenerated: Swift.Identifiable, AIKit.ConvertibleFromGeneratedContent {
                public var id: AIKit.GenerationID
                public var name: String.PartiallyGenerated?
                public var count: Int.PartiallyGenerated?
                public var tag: String.PartiallyGenerated?
                public var note: String?.PartiallyGenerated?

                public init(_ content: AIKit.GeneratedContent) throws {
                    self.id = content.id ?? AIKit.GenerationID()
                    self.name = try content.value(forProperty: "name")
                    self.count = try content.value(forProperty: "count")
                    self.tag = try content.value(forProperty: "tag")
                    self.note = try content.value(forProperty: "note")
                }
            }
        }

        extension Arguments: AIKit.Generable {
            public init(_ content: AIKit.GeneratedContent) throws {
                self.name = try content.value(forProperty: "name")
                self.count = try content.value(forProperty: "count")
                self.tag = try content.value(forProperty: "tag")
                self.note = try content.value(forProperty: "note")
            }
        }
        """,
        macros: testMacros
    )
}

@Test func generatedNestedStructMacroExpansion() {
    assertMacroExpansion(
        """
        struct Outer {
            @Generable
            struct Inner {
                var name: String
            }
        }
        """,
        expandedSource:
        """
        struct Outer {
            struct Inner {
                var name: String

                public static var generationSchema: AIKit.GenerationSchema {
                    AIKit.GenerationSchema(
                        type: Self.self,
                        properties: [
                            AIKit.GenerationSchema.Property(name: "name", type: String.self)
                        ]
                    )
                }

                public var generatedContent: AIKit.GeneratedContent {
                    let explicitNil = false
                    var properties = [(name: String, value: any AIKit.ConvertibleToGeneratedContent)]()
                    addProperty(name: "name", value: self.name)
                    return AIKit.GeneratedContent(
                        properties: properties,
                        uniquingKeysWith: { _, second in
                            second
                        }
                    )

                    func addProperty(name: String, value: some AIKit.Generable) {
                        properties.append((name: name, value: value))
                    }

                    func addProperty(name: String, value: (some AIKit.Generable)?) {
                        if explicitNil || value != nil {
                            properties.append((name: name, value: value))
                        }
                    }
                }

                public struct PartiallyGenerated: Swift.Identifiable, AIKit.ConvertibleFromGeneratedContent {
                    public var id: AIKit.GenerationID
                    public var name: String.PartiallyGenerated?

                    public init(_ content: AIKit.GeneratedContent) throws {
                        self.id = content.id ?? AIKit.GenerationID()
                        self.name = try content.value(forProperty: "name")
                    }
                }
            }
        }

        extension Outer.Inner: AIKit.Generable {
            public init(_ content: AIKit.GeneratedContent) throws {
                self.name = try content.value(forProperty: "name")
            }
        }
        """,
        macros: testMacros
    )
}

@Test func generatedEnumMacroExpansionUsesCaseNames() {
    assertMacroExpansion(
        """
        @Generable(description: "State.")
        enum State: String {
            case ready = "READY"
            case running
        }
        """,
        expandedSource:
        """
        enum State: String {
            case ready = "READY"
            case running

            public static var generationSchema: AIKit.GenerationSchema {
                AIKit.GenerationSchema(type: Self.self, description: "State.", anyOf: ["ready", "running"])
            }

            public var generatedContent: AIKit.GeneratedContent {
                switch self {
                case .ready:
                    "ready".generatedContent
                case .running:
                    "running".generatedContent
                }
            }
        }

        extension State: AIKit.Generable {
            public init(_ content: AIKit.GeneratedContent) throws {
                let rawValue = try content.value(String.self)
                switch rawValue {
                case "ready":
                    self = .ready
                case "running":
                    self = .running
                default:
                    throw AIKit.GeneratedContentError.invalidValue("Unexpected value \\(rawValue) for \\(Self.self).")
                }
            }
        }
        """,
        macros: testMacros
    )
}

@Test func explicitGenerableConformanceSuppressesExtensionConformance() {
    assertMacroExpansion(
        """
        @Generable
        struct Arguments: AIKit.Generable {
            var city: String
        }
        """,
        expandedSource:
        """
        struct Arguments: AIKit.Generable {
            var city: String

            public static var generationSchema: AIKit.GenerationSchema {
                AIKit.GenerationSchema(
                    type: Self.self,
                    properties: [
                        AIKit.GenerationSchema.Property(name: "city", type: String.self)
                    ]
                )
            }

            public var generatedContent: AIKit.GeneratedContent {
                let explicitNil = false
                var properties = [(name: String, value: any AIKit.ConvertibleToGeneratedContent)]()
                addProperty(name: "city", value: self.city)
                return AIKit.GeneratedContent(
                    properties: properties,
                    uniquingKeysWith: { _, second in
                        second
                    }
                )

                func addProperty(name: String, value: some AIKit.Generable) {
                    properties.append((name: name, value: value))
                }

                func addProperty(name: String, value: (some AIKit.Generable)?) {
                    if explicitNil || value != nil {
                        properties.append((name: name, value: value))
                    }
                }
            }

            public struct PartiallyGenerated: Swift.Identifiable, AIKit.ConvertibleFromGeneratedContent {
                public var id: AIKit.GenerationID
                public var city: String.PartiallyGenerated?

                public init(_ content: AIKit.GeneratedContent) throws {
                    self.id = content.id ?? AIKit.GenerationID()
                    self.city = try content.value(forProperty: "city")
                }
            }
        }

        extension Arguments {
            public init(_ content: AIKit.GeneratedContent) throws {
                self.city = try content.value(forProperty: "city")
            }
        }
        """,
        macros: testMacros
    )
}

@Test func generableReportsUnsupportedDeclarationDiagnostics() {
    assertMacroExpansion(
        """
        @Generable
        class Reference {}

        @Generable
        actor Worker {}

        @Generable
        protocol Shape {}

        @Generable
        extension String {}
        """,
        expandedSource:
        """
        class Reference {}

        actor Worker {}

        protocol Shape {}

        extension String {}
        """,
        diagnostics: [
            expectedDiagnostic(.generableRequiresStructOrEnum, line: 1, column: 1),
            expectedDiagnostic(.generableRequiresStructOrEnum, line: 4, column: 1),
            expectedDiagnostic(.generableRequiresStructOrEnum, line: 7, column: 1),
            expectedDiagnostic(.generableRequiresStructOrEnum, line: 10, column: 1)
        ],
        macros: testMacros
    )
}

@Test func generableReportsGenericTypeDiagnostics() {
    assertMacroExpansion(
        """
        @Generable
        struct Box<Value> {
            var value: String
        }

        @Generable
        enum Choice<Value> {
            case value
        }
        """,
        expandedSource:
        """
        struct Box<Value> {
            var value: String
        }

        enum Choice<Value> {
            case value
        }
        """,
        diagnostics: [
            expectedDiagnostic(.generableDoesNotSupportGenericTypes, line: 2, column: 8),
            expectedDiagnostic(.generableDoesNotSupportGenericTypes, line: 7, column: 6)
        ],
        macros: testMacros
    )
}

@Test func generableReportsEnumShapeDiagnostics() {
    assertMacroExpansion(
        """
        @Generable
        enum Empty {}

        @Generable
        enum Payload {
            case value(String)
        }

        @Generable
        enum Guided {
            @Guide(description: "No")
            case value
        }
        """,
        expandedSource:
        """
        enum Empty {}

        enum Payload {
            case value(String)
        }

        enum Guided {
            case value
        }
        """,
        diagnostics: [
            expectedDiagnostic(.enumRequiresCases, line: 2, column: 6),
            expectedDiagnostic(.enumAssociatedValuesAreUnsupported, line: 6, column: 10),
            expectedDiagnostic(.enumGuideIsUnsupported, line: 11, column: 5)
        ],
        macros: testMacros
    )
}

@Test func generableReportsInvalidPropertyDiagnostics() {
    assertMacroExpansion(
        """
        @Generable
        struct BadProperties {
            var a: String, b: String
            var inferred = "x"

            @Guide(description: "No")
            static var staticValue: String = ""

            @Guide(description: "No")
            var computed: String { "" }

            @Guide(description: "No")
            lazy var cached: String = ""
        }
        """,
        expandedSource:
        """
        struct BadProperties {
            var a: String, b: String
            var inferred = "x"

            static var staticValue: String = ""

            var computed: String { "" }

            lazy var cached: String = ""
        }
        """,
        diagnostics: [
            expectedDiagnostic(.propertyRequiresSingleBinding, line: 3, column: 5),
            expectedDiagnostic(.propertyRequiresTypeAnnotation, line: 4, column: 9),
            expectedDiagnostic(.guideRequiresStoredInstanceProperty, line: 6, column: 5),
            expectedDiagnostic(.guideRequiresStoredInstanceProperty, line: 9, column: 5),
            expectedDiagnostic(.guideRequiresStoredInstanceProperty, line: 12, column: 5)
        ],
        macros: testMacros
    )
}

@Test func generableReportsDuplicateGuideDiagnostics() {
    assertMacroExpansion(
        """
        @Generable
        struct BadGuide {
            @Guide(description: "One")
            @Guide(description: "Two")
            var name: String
        }
        """,
        expandedSource:
        """
        struct BadGuide {
            var name: String
        }
        """,
        diagnostics: [
            expectedDiagnostic(.duplicateGuide, line: 4, column: 5)
        ],
        macros: testMacros
    )
}

@Test func guideReportsNonPropertyDeclarationDiagnostics() {
    assertMacroExpansion(
        """
        struct Container {
            @Guide(description: "No")
            func run() {}
        }
        """,
        expandedSource:
        """
        struct Container {
            func run() {}
        }
        """,
        diagnostics: [
            expectedDiagnostic(.guideRequiresProperty, line: 2, column: 5)
        ],
        macros: testMacros
    )
}

@Test func codegenBuildsPropertySchemaCall() {
    let property = StoredPropertyModel(
        name: "code",
        identifier: .identifier("code"),
        type: TypeSyntax("String"),
        guide: GuideModel(
            description: ExprSyntax(#""Airport code""#),
            expressions: [
                ExprSyntax(#"AIKit.GenerationGuide<String>.pattern("^[A-Z]{3}$")"#)
            ]
        )
    )

    #expect(
        GenerableCodegen.propertySchemaCall(for: property).description ==
            #"AIKit.GenerationSchema.Property(name: "code",description: "Airport code",type: String.self,guides: [AIKit.GenerationGuide<String>.pattern("^[A-Z]{3}$")])"#
    )
}

@Test func codegenBuildsGeneratedContentAddLine() {
    let property = StoredPropertyModel(
        name: "city",
        identifier: .identifier("city"),
        type: TypeSyntax("String"),
        guide: nil
    )

    #expect(
        GenerableCodegen.generatedContentAddLine(for: property).description ==
            #"addProperty(name: "city", value: self.city)"#
    )
}

@Test func codegenBuildsPartialPropertyDeclaration() {
    let property = StoredPropertyModel(
        name: "city",
        identifier: .identifier("city"),
        type: TypeSyntax("String"),
        guide: nil
    )

    #expect(
        GenerableCodegen.partialPropertyDecl(for: property).description ==
            "public var city: String.PartiallyGenerated?"
    )
}

@Test func codegenBuildsEnumGeneratedContentSwitch() throws {
    let model = GenerableEnumModel(
        description: nil,
        choices: [
            EnumChoiceModel(name: "ready", identifier: .identifier("ready")),
            EnumChoiceModel(name: "running", identifier: .identifier("running"))
        ]
    )

    let description = GenerableCodegen.enumGeneratedContentSwitch(for: model).description

    #expect(description == """
        switch self {
        case .ready:
            "ready".generatedContent
        case .running:
            "running".generatedContent
        }
        """)
}

@Test func codegenBuildsInitializerExtensionsWithAndWithoutConformance() throws {
    let model = GenerableTypeModel.structure(
        GenerableStructModel(
            description: nil,
            explicitNil: ExprSyntax("false"),
            explicitNilArgument: nil,
            properties: [
                StoredPropertyModel(
                    name: "city",
                    identifier: .identifier("city"),
                    type: TypeSyntax("String"),
                    guide: nil
                )
            ]
        )
    )

    #expect(
        try GenerableCodegen.extensionDecl(
            for: model,
            extendedType: TypeSyntax("Arguments"),
            addsConformance: true
        ).description.contains("extension Arguments: AIKit.Generable")
    )
    #expect(
        try GenerableCodegen.extensionDecl(
            for: model,
            extendedType: TypeSyntax("Arguments"),
            addsConformance: false
        ).description.contains("extension Arguments {")
    )
}

private let testMacros: [String: Macro.Type] = [
    "Generable": GenerableMacro.self,
    "Guide": GuideMacro.self
]

private func expectedDiagnostic(
    _ diagnostic: AIKitMacroDiagnostic,
    line: Int,
    column: Int
) -> DiagnosticSpec {
    DiagnosticSpec(
        id: diagnostic.diagnosticID,
        message: diagnostic.message,
        line: line,
        column: column
    )
}
