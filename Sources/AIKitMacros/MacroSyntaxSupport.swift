import SwiftSyntax

enum MacroSyntaxSupport {
    static func guideAttributes(in attributes: AttributeListSyntax) -> [AttributeSyntax] {
        attributes.compactMap { attribute in
            guard case let .attribute(attributeSyntax) = attribute,
                  isGuideAttribute(attributeSyntax)
            else {
                return nil
            }

            return attributeSyntax
        }
    }

    static func guideAttribute(in attributes: AttributeListSyntax) -> AttributeSyntax? {
        guideAttributes(in: attributes).first
    }

    static func argumentExpressions(from attribute: AttributeSyntax) -> [MacroArgument] {
        guard case let .argumentList(arguments) = attribute.arguments else {
            return []
        }

        return arguments.map { argument in
            MacroArgument(
                label: argument.label?.text,
                expression: argument.expression.trimmed
            )
        }
    }

    static func guideExpressions(from attribute: AttributeSyntax) -> [ExprSyntax] {
        guard case let .argumentList(arguments) = attribute.arguments else {
            return []
        }

        return arguments.compactMap { argument in
            guard argument.label == nil else {
                return nil
            }

            if let regexLiteral = argument.expression.as(RegexLiteralExprSyntax.self) {
                return ExprSyntax("AIKit.GenerationGuide<String>.pattern(\(literal: regexLiteral.regex.text))")
            }

            return argument.expression.trimmed
        }
    }

    private static func isGuideAttribute(_ attribute: AttributeSyntax) -> Bool {
        let name = attribute.attributeName.trimmedDescription
        return name == "Guide" ||
            name.hasSuffix(".Guide") ||
            name.hasPrefix("Guide<") ||
            name.contains(".Guide<")
    }
}

extension VariableDeclSyntax {
    var isStaticLike: Bool {
        modifiers.contains { modifier in
            switch modifier.name.tokenKind {
            case .keyword(.static), .keyword(.class):
                true
            default:
                false
            }
        }
    }

    var isLazy: Bool {
        modifiers.contains { modifier in
            if case .keyword(.lazy) = modifier.name.tokenKind {
                true
            } else {
                false
            }
        }
    }
}

extension PatternBindingSyntax {
    var isComputedProperty: Bool {
        guard let accessorBlock else {
            return false
        }

        switch accessorBlock.accessors {
        case .getter:
            return true
        case let .accessors(accessors):
            return accessors.contains { accessor in
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.willSet), .keyword(.didSet):
                    return false
                default:
                    return true
                }
            }
        }
    }
}
