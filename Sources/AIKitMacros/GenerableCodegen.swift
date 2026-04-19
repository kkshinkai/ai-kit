import SwiftSyntax
import SwiftSyntaxBuilder

enum GenerableCodegen {
    static func members(for model: GenerableTypeModel) throws -> [DeclSyntax] {
        switch model {
        case let .structure(model):
            try structMembers(for: model)
        case let .enumeration(model):
            try enumMembers(for: model)
        }
    }

    static func extensionDecl(
        for model: GenerableTypeModel,
        extendedType: some TypeSyntaxProtocol,
        addsConformance: Bool
    ) throws -> ExtensionDeclSyntax {
        switch model {
        case let .structure(model):
            try structExtension(for: model, extendedType: extendedType, addsConformance: addsConformance)
        case let .enumeration(model):
            try enumExtension(for: model, extendedType: extendedType, addsConformance: addsConformance)
        }
    }
}

extension GenerableCodegen {
    static func propertySchemaCall(for property: StoredPropertyModel) -> ExprSyntax {
        let arguments = LabeledExprListSyntax {
            LabeledExprSyntax(label: "name", expression: ExprSyntax("\(literal: property.name)"))
            if let description = property.guide?.description {
                LabeledExprSyntax(label: "description", expression: description)
            }
            LabeledExprSyntax(label: "type", expression: ExprSyntax("\(property.type).self"))
            if let guides = property.guide?.expressions, !guides.isEmpty {
                LabeledExprSyntax(
                    label: "guides",
                    expression: ExprSyntax(ArrayExprSyntax(expressions: guides))
                )
            }
        }

        return ExprSyntax(
            FunctionCallExprSyntax(
                calledExpression: ExprSyntax("AIKit.GenerationSchema.Property"),
                leftParen: .leftParenToken(),
                arguments: arguments,
                rightParen: .rightParenToken()
            )
        )
    }

    static func generatedContentAddLine(for property: StoredPropertyModel) -> CodeBlockItemSyntax {
        "addProperty(name: \(literal: property.name), value: self.\(property.identifier))"
    }

    static func partialPropertyDecl(for property: StoredPropertyModel) -> DeclSyntax {
        "public var \(property.identifier): \(property.partialGeneratedType)"
    }

    static func partialAssignmentLine(for property: StoredPropertyModel) -> CodeBlockItemSyntax {
        "self.\(property.identifier) = try content.value(forProperty: \(literal: property.name))"
    }

    static func initializerAssignmentLine(for property: StoredPropertyModel) -> CodeBlockItemSyntax {
        "self.\(property.identifier) = try content.value(forProperty: \(literal: property.name))"
    }

    static func enumGeneratedContentSwitch(for model: GenerableEnumModel) -> SwitchExprSyntax {
        SwitchExprSyntax(
            switchKeyword: .keyword(.switch, trailingTrivia: .space),
            subject: ExprSyntax("self").with(\.trailingTrivia, .space),
            leftBrace: .leftBraceToken(trailingTrivia: .newline),
            cases: SwitchCaseListSyntax {
                for choice in model.choices {
                    SwitchCaseSyntax(
                        label: .case(caseLabel(pattern: PatternSyntax(".\(choice.identifier)"))),
                        statements: CodeBlockItemListSyntax {
                            CodeBlockItemSyntax(
                                leadingTrivia: .spaces(4),
                                item: .expr(ExprSyntax("\(literal: choice.name).generatedContent")),
                                trailingTrivia: .newline
                            )
                        }
                    )
                }
            }
        )
    }
}

private extension GenerableCodegen {
    static func structMembers(for model: GenerableStructModel) throws -> [DeclSyntax] {
        [
            generationSchemaDecl(for: model),
            generatedContentDecl(for: model),
            try partiallyGeneratedDecl(for: model)
        ]
    }

    static func enumMembers(for model: GenerableEnumModel) throws -> [DeclSyntax] {
        [
            generationSchemaDecl(for: model),
            try generatedContentDecl(for: model)
        ]
    }

    static func generationSchemaDecl(for model: GenerableStructModel) -> DeclSyntax {
        let initializer = generationSchemaInitializer(for: model)
        return """
        public static var generationSchema: AIKit.GenerationSchema {
            \(initializer)
        }
        """
    }

    static func generationSchemaDecl(for model: GenerableEnumModel) -> DeclSyntax {
        let initializer = generationSchemaInitializer(for: model)
        return """
        public static var generationSchema: AIKit.GenerationSchema {
            \(initializer)
        }
        """
    }

    static func generationSchemaInitializer(for model: GenerableStructModel) -> ExprSyntax {
        ExprSyntax(
            FunctionCallExprSyntax(
                calledExpression: ExprSyntax("AIKit.GenerationSchema"),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(label: "type", expression: ExprSyntax("Self.self"))
                    if let description = model.description {
                        LabeledExprSyntax(label: "description", expression: description)
                    }
                    if let explicitNilArgument = model.explicitNilArgument {
                        LabeledExprSyntax(
                            label: "representNilExplicitlyInGeneratedContent",
                            expression: explicitNilArgument
                        )
                    }
                    LabeledExprSyntax(
                        label: "properties",
                        expression: ExprSyntax(propertySchemaArray(for: model.properties))
                    )
                },
                rightParen: .rightParenToken()
            )
        )
    }

    static func generationSchemaInitializer(for model: GenerableEnumModel) -> ExprSyntax {
        ExprSyntax(
            FunctionCallExprSyntax(
                calledExpression: ExprSyntax("AIKit.GenerationSchema"),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(label: "type", expression: ExprSyntax("Self.self"))
                    if let description = model.description {
                        LabeledExprSyntax(label: "description", expression: description)
                    }
                    LabeledExprSyntax(
                        label: "anyOf",
                        expression: ExprSyntax(choiceArray(for: model.choices))
                    )
                },
                rightParen: .rightParenToken()
            )
        )
    }

    static func propertySchemaArray(for properties: [StoredPropertyModel]) -> ArrayExprSyntax {
        ArrayExprSyntax {
            for property in properties {
                ArrayElementSyntax(expression: propertySchemaCall(for: property))
            }
        }
    }

    static func choiceArray(for choices: [EnumChoiceModel]) -> ArrayExprSyntax {
        ArrayExprSyntax {
            for choice in choices {
                ArrayElementSyntax(expression: ExprSyntax("\(literal: choice.name)"))
            }
        }
    }

    static func generatedContentDecl(for model: GenerableStructModel) -> DeclSyntax {
        let additions = CodeBlockItemListSyntax {
            for property in model.properties {
                generatedContentAddLine(for: property)
            }
        }

        return """
        public var generatedContent: AIKit.GeneratedContent {
            let explicitNil = \(model.explicitNil)
            var properties = [(name: String, value: any AIKit.ConvertibleToGeneratedContent)]()
            \(additions)
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
        """
    }

    static func generatedContentDecl(for model: GenerableEnumModel) throws -> DeclSyntax {
        let switchExpr = enumGeneratedContentSwitch(for: model)
        return """
        public var generatedContent: AIKit.GeneratedContent {
            \(switchExpr)
        }
        """
    }

    static func partiallyGeneratedDecl(for model: GenerableStructModel) throws -> DeclSyntax {
        DeclSyntax(
            try StructDeclSyntax("public struct PartiallyGenerated: Swift.Identifiable, AIKit.ConvertibleFromGeneratedContent") {
                DeclSyntax("public var id: AIKit.GenerationID")
                for property in model.properties {
                    partialPropertyDecl(for: property)
                }
                try partialInitializerDecl(for: model)
            }
        )
    }

    static func partialInitializerDecl(for model: GenerableStructModel) throws -> InitializerDeclSyntax {
        try InitializerDeclSyntax("public init(_ content: AIKit.GeneratedContent) throws") {
            CodeBlockItemSyntax("self.id = content.id ?? AIKit.GenerationID()")
            for property in model.properties {
                partialAssignmentLine(for: property)
            }
        }
    }

    static func structInitializerDecl(for model: GenerableStructModel) throws -> InitializerDeclSyntax {
        try InitializerDeclSyntax("public init(_ content: AIKit.GeneratedContent) throws") {
            for property in model.properties {
                initializerAssignmentLine(for: property)
            }
        }
    }

    static func enumInitializerDecl(for model: GenerableEnumModel) throws -> InitializerDeclSyntax {
        try InitializerDeclSyntax("public init(_ content: AIKit.GeneratedContent) throws") {
            CodeBlockItemSyntax("let rawValue = try content.value(String.self)")
            enumInitializerSwitch(for: model)
        }
    }

    static func enumInitializerSwitch(for model: GenerableEnumModel) -> SwitchExprSyntax {
        SwitchExprSyntax(
            switchKeyword: .keyword(.switch, trailingTrivia: .space),
            subject: ExprSyntax("rawValue").with(\.trailingTrivia, .space),
            leftBrace: .leftBraceToken(trailingTrivia: .newline),
            cases: SwitchCaseListSyntax {
                for choice in model.choices {
                    SwitchCaseSyntax(
                        label: .case(caseLabel(pattern: PatternSyntax("\(literal: choice.name)"))),
                        statements: CodeBlockItemListSyntax {
                            CodeBlockItemSyntax(
                                leadingTrivia: .spaces(4),
                                item: .expr(ExprSyntax("self = .\(choice.identifier)")),
                                trailingTrivia: .newline
                            )
                        }
                    )
                }
                SwitchCaseSyntax(
                    label: .default(
                        SwitchDefaultLabelSyntax(
                            colon: .colonToken(trailingTrivia: .newline)
                        )
                    ),
                    statements: CodeBlockItemListSyntax {
                        CodeBlockItemSyntax(
                            leadingTrivia: .spaces(4),
                            item: .stmt(
                                StmtSyntax(
                                    #"throw AIKit.GeneratedContentError.invalidValue("Unexpected value \(rawValue) for \(Self.self).")"#
                                )
                            ),
                            trailingTrivia: .newline
                        )
                    }
                )
            }
        )
    }

    static func caseLabel(pattern: PatternSyntax) -> SwitchCaseLabelSyntax {
        SwitchCaseLabelSyntax(
            caseKeyword: .keyword(.case, trailingTrivia: .space),
            caseItems: SwitchCaseItemListSyntax {
                SwitchCaseItemSyntax(pattern: pattern)
            },
            colon: .colonToken(trailingTrivia: .newline)
        )
    }

    static func structExtension(
        for model: GenerableStructModel,
        extendedType: some TypeSyntaxProtocol,
        addsConformance: Bool
    ) throws -> ExtensionDeclSyntax {
        if addsConformance {
            return try ExtensionDeclSyntax("extension \(extendedType): AIKit.Generable") {
                try structInitializerDecl(for: model)
            }
        }

        return try ExtensionDeclSyntax("extension \(extendedType)") {
            try structInitializerDecl(for: model)
        }
    }

    static func enumExtension(
        for model: GenerableEnumModel,
        extendedType: some TypeSyntaxProtocol,
        addsConformance: Bool
    ) throws -> ExtensionDeclSyntax {
        if addsConformance {
            return try ExtensionDeclSyntax("extension \(extendedType): AIKit.Generable") {
                try enumInitializerDecl(for: model)
            }
        }

        return try ExtensionDeclSyntax("extension \(extendedType)") {
            try enumInitializerDecl(for: model)
        }
    }
}
