import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct GenerableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return try structMembers(for: structDecl, attribute: node)
        }

        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return try enumMembers(for: enumDecl, attribute: node)
        }

        return []
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return try [ExtensionDeclSyntax("\(raw: structExtension(for: structDecl, type: type.trimmedDescription))")]
        }

        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return try [ExtensionDeclSyntax("\(raw: enumExtension(for: enumDecl, type: type.trimmedDescription))")]
        }

        return []
    }
}

private extension GenerableMacro {
    struct Property {
        var name: String
        var type: String
        var guideDescription: String?
        var guideExpressions: [String]

        var partialType: String {
            "\(type).PartiallyGenerated?"
        }
    }

    static func structMembers(for declaration: StructDeclSyntax, attribute: AttributeSyntax) throws -> [DeclSyntax] {
        let properties = storedProperties(in: declaration)
        let description = generableDescription(from: attribute)

        let propertySchemas = properties.map { property in
            let descriptionArgument = property.guideDescription.map { ", description: \($0)" } ?? ""
            let guidesArgument = property.guideExpressions.isEmpty ? "" : ", guides: [\(property.guideExpressions.joined(separator: ", "))]"
            return #"AIKit.GenerationSchema.Property(name: "\#(property.name)"\#(descriptionArgument), type: \#(property.type).self\#(guidesArgument))"#
        }.joined(separator: ",\n            ")

        let generatedContentAdds = properties.map { property in
            if property.type.hasSuffix("?") {
                return """
                    if let value = self.\(property.name) {
                        properties.append((name: "\(property.name)", value: value))
                    }
                """
            }

            return #"properties.append((name: "\#(property.name)", value: self.\#(property.name)))"#
        }.joined(separator: "\n        ")

        let partialProperties = properties.map { property in
            "public var \(property.name): \(property.partialType)"
        }.joined(separator: "\n    ")

        let partialAssignments = properties.map { property in
            #"self.\#(property.name) = try content.value(\#(property.type).PartiallyGenerated?.self, forProperty: "\#(property.name)")"#
        }.joined(separator: "\n        ")

        let descriptionArgument = description.map { ", description: \($0)" } ?? ""

        return [
            DeclSyntax(
                stringLiteral: """
                public static var generationSchema: AIKit.GenerationSchema {
                    AIKit.GenerationSchema(
                        type: Self.self\(descriptionArgument),
                        properties: [
                            \(propertySchemas)
                        ]
                    )
                }
                """
            ),
            DeclSyntax(
                stringLiteral: """
                public var generatedContent: AIKit.GeneratedContent {
                    var properties = [(name: String, value: any AIKit.ConvertibleToGeneratedContent)]()
                    \(generatedContentAdds)
                    return AIKit.GeneratedContent(properties: properties)
                }
                """
            ),
            DeclSyntax(
                stringLiteral: """
                public struct PartiallyGenerated: Swift.Identifiable, AIKit.ConvertibleFromGeneratedContent {
                    public var id: AIKit.GenerationID
                    \(partialProperties)

                    public init(_ content: AIKit.GeneratedContent) throws {
                        self.id = content.id ?? AIKit.GenerationID()
                        \(partialAssignments)
                    }
                }
                """
            )
        ]
    }

    static func enumMembers(for declaration: EnumDeclSyntax, attribute: AttributeSyntax) throws -> [DeclSyntax] {
        let cases = enumCases(in: declaration)
        let choices = cases.map { #""\#($0)""# }.joined(separator: ", ")
        let descriptionArgument = generableDescription(from: attribute).map { ", description: \($0)" } ?? ""
        let generatedCases = cases.map { name in
            """
            case .\(name):
                        "\(name)".generatedContent
            """
        }.joined(separator: "\n        ")

        return [
            DeclSyntax(
                stringLiteral: """
                public static var generationSchema: AIKit.GenerationSchema {
                    AIKit.GenerationSchema(type: Self.self\(descriptionArgument), anyOf: [\(choices)])
                }
                """
            ),
            DeclSyntax(
                stringLiteral: """
                public var generatedContent: AIKit.GeneratedContent {
                    switch self {
                    \(generatedCases)
                    }
                }
                """
            )
        ]
    }

    static func structExtension(for declaration: StructDeclSyntax, type: String) -> String {
        let properties = storedProperties(in: declaration)
        let assignments = properties.map { property in
            #"self.\#(property.name) = try content.value(forProperty: "\#(property.name)")"#
        }.joined(separator: "\n        ")

        return """
        extension \(type): AIKit.Generable {
            public init(_ content: AIKit.GeneratedContent) throws {
                \(assignments)
            }
        }
        """
    }

    static func enumExtension(for declaration: EnumDeclSyntax, type: String) -> String {
        let cases = enumCases(in: declaration)
        let switchCases = cases.map { name in
            """
            case "\(name)":
                    self = .\(name)
            """
        }.joined(separator: "\n        ")

        return """
        extension \(type): AIKit.Generable {
            public init(_ content: AIKit.GeneratedContent) throws {
                let rawValue = try content.value(String.self)
                switch rawValue {
                \(switchCases)
                default:
                    throw AIKit.GeneratedContentError.invalidValue("Unexpected value \\(rawValue) for \\(Self.self).")
                }
            }
        }
        """
    }

    static func storedProperties(in declaration: StructDeclSyntax) -> [Property] {
        declaration.memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  variable.bindings.count == 1,
                  let binding = variable.bindings.first,
                  binding.accessorBlock == nil,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let type = binding.typeAnnotation?.type.trimmedDescription
            else {
                return nil
            }

            let guide = guideInfo(from: variable)
            return Property(
                name: pattern.identifier.text,
                type: type,
                guideDescription: guide.description,
                guideExpressions: guide.expressions
            )
        }
    }

    static func enumCases(in declaration: EnumDeclSyntax) -> [String] {
        declaration.memberBlock.members.flatMap { member -> [String] in
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                return []
            }

            return caseDecl.elements.compactMap { element in
                guard element.parameterClause == nil else {
                    return nil
                }
                return element.name.text
            }
        }
    }

    static func generableDescription(from attribute: AttributeSyntax) -> String? {
        argumentExpressions(from: attribute).first { $0.label == "description" }?.expression
    }

    static func guideInfo(from variable: VariableDeclSyntax) -> (description: String?, expressions: [String]) {
        for attribute in variable.attributes {
            guard case let .attribute(attributeSyntax) = attribute,
                  attributeSyntax.attributeName.trimmedDescription == "Guide"
            else {
                continue
            }

            let arguments = argumentExpressions(from: attributeSyntax)
            return (
                arguments.first { $0.label == "description" }?.expression,
                arguments.filter { $0.label == nil }.map(\.expression)
            )
        }

        return (nil, [])
    }

    static func argumentExpressions(from attribute: AttributeSyntax) -> [(label: String?, expression: String)] {
        guard case let .argumentList(arguments) = attribute.arguments else {
            return []
        }

        return arguments.map { argument in
            (argument.label?.text, argument.expression.trimmedDescription)
        }
    }
}
