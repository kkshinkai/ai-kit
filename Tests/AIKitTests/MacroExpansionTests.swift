import AIKitMacros
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
                var properties = [(name: String, value: any AIKit.ConvertibleToGeneratedContent)]()
                properties.append((name: "city", value: self.city))
                return AIKit.GeneratedContent(properties: properties)
            }

            public struct PartiallyGenerated: Swift.Identifiable, AIKit.ConvertibleFromGeneratedContent {
                public var id: AIKit.GenerationID
                public var city: String.PartiallyGenerated?

                public init(_ content: AIKit.GeneratedContent) throws {
                    self.id = content.id ?? AIKit.GenerationID()
                    self.city = try content.value(String.PartiallyGenerated?.self, forProperty: "city")
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

private let testMacros: [String: Macro.Type] = [
    "Generable": GenerableMacro.self,
    "Guide": GuideMacro.self
]
