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
        if model.usesDiscriminatedUnion {
            return associatedEnumGeneratedContentSwitch(for: model)
        }

        return SwitchExprSyntax(
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
        return [
            generationSchemaDecl(for: model),
            generatedContentDecl(for: model),
            try partiallyGeneratedDecl(for: model)
        ]
    }

    static func enumMembers(for model: GenerableEnumModel) throws -> [DeclSyntax] {
        if model.usesDiscriminatedUnion {
            var declarations: [DeclSyntax] = [
                try enumPartiallyGeneratedDecl(for: model),
                generationSchemaDecl(for: model)
            ]

            for choice in model.choices {
                declarations.append(try discriminatedStructDecl(for: choice))
            }

            declarations.append(try generatedContentDecl(for: model))
            return declarations
        }

        return [
            generationSchemaDecl(for: model),
            try generatedContentDecl(for: model)
        ]
    }

    static func generationSchemaDecl(for model: GenerableStructModel) -> DeclSyntax {
        let initializer = generationSchemaInitializer(for: model)
        return """
        nonisolated public static var generationSchema: AIKit.GenerationSchema {
            \(initializer)
        }
        """
    }

    static func generationSchemaDecl(for model: GenerableEnumModel) -> DeclSyntax {
        let initializer = generationSchemaInitializer(for: model)
        return """
        nonisolated public static var generationSchema: AIKit.GenerationSchema {
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
                    if model.usesDiscriminatedUnion {
                        LabeledExprSyntax(
                            label: "anyOf",
                            expression: ExprSyntax(discriminatedTypeArray(for: model.choices))
                        )
                    } else {
                        LabeledExprSyntax(
                            label: "anyOf",
                            expression: ExprSyntax(choiceArray(for: model.choices))
                        )
                    }
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

    static func discriminatedTypeArray(for choices: [EnumChoiceModel]) -> ArrayExprSyntax {
        ArrayExprSyntax {
            for choice in choices {
                ArrayElementSyntax(expression: ExprSyntax("\(choice.discriminatedType).self"))
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
        nonisolated public var generatedContent: AIKit.GeneratedContent {
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
        nonisolated public var generatedContent: AIKit.GeneratedContent {
            \(switchExpr)
        }
        """
    }

    static func partiallyGeneratedDecl(for model: GenerableStructModel) throws -> DeclSyntax {
        DeclSyntax(
            try StructDeclSyntax("nonisolated public struct PartiallyGenerated: Swift.Identifiable, AIKit.ConvertibleFromGeneratedContent") {
                DeclSyntax("public var id: AIKit.GenerationID")
                for property in model.properties {
                    partialPropertyDecl(for: property)
                }
                try partialInitializerDecl(for: model)
            }
        )
    }

    static func partialInitializerDecl(for model: GenerableStructModel) throws -> InitializerDeclSyntax {
        try InitializerDeclSyntax("nonisolated public init(_ content: AIKit.GeneratedContent) throws") {
            CodeBlockItemSyntax("self.id = content.id ?? AIKit.GenerationID()")
            for property in model.properties {
                partialAssignmentLine(for: property)
            }
        }
    }

    static func structInitializerDecl(for model: GenerableStructModel) throws -> InitializerDeclSyntax {
        try InitializerDeclSyntax("nonisolated public init(_ content: AIKit.GeneratedContent) throws") {
            for property in model.properties {
                initializerAssignmentLine(for: property)
            }
        }
    }

    static func enumInitializerDecl(for model: GenerableEnumModel) throws -> InitializerDeclSyntax {
        if model.usesDiscriminatedUnion {
            return try InitializerDeclSyntax("nonisolated public init(_ content: AIKit.GeneratedContent) throws") {
                CodeBlockItemSyntax(#"let type: String = try content.value(forProperty: "type")"#)
                associatedEnumInitializerSwitch(for: model)
            }
        }

        return try InitializerDeclSyntax("nonisolated public init(_ content: AIKit.GeneratedContent) throws") {
            CodeBlockItemSyntax("let rawValue = try content.value(String.self)")
            simpleEnumInitializerSwitch(for: model)
        }
    }

    static func simpleEnumInitializerSwitch(for model: GenerableEnumModel) -> SwitchExprSyntax {
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

    static func enumPartiallyGeneratedDecl(for model: GenerableEnumModel) throws -> DeclSyntax {
        DeclSyntax(
            try EnumDeclSyntax("nonisolated public enum PartiallyGenerated: AIKit.ConvertibleFromGeneratedContent") {
                for choice in model.choices {
                    DeclSyntax(stringLiteral: enumCaseDeclSource(for: choice, usesPartialTypes: true))
                }
                try InitializerDeclSyntax("nonisolated public init(_ content: AIKit.GeneratedContent) throws") {
                    CodeBlockItemSyntax(#"let type: String = try content.value(forProperty: "type")"#)
                    associatedEnumInitializerSwitch(for: model)
                }
            }
        )
    }

    static func discriminatedStructDecl(for choice: EnumChoiceModel) throws -> DeclSyntax {
        DeclSyntax(
            try StructDeclSyntax("private nonisolated struct \(choice.discriminatedType): AIKit.Generable") {
                DeclSyntax("let type: String")
                for payload in choice.payloads {
                    DeclSyntax("let \(payload.identifier): \(payload.type)")
                }
                try discriminatedInitializerDecl(for: choice)
                discriminatedGenerationSchemaDecl(for: choice)
                discriminatedGeneratedContentDecl(for: choice)
            }
        )
    }

    static func discriminatedInitializerDecl(for choice: EnumChoiceModel) throws -> InitializerDeclSyntax {
        try InitializerDeclSyntax("nonisolated init(_ content: AIKit.GeneratedContent) throws") {
            CodeBlockItemSyntax(#"self.type = try content.value(forProperty: "type")"#)
            for payload in choice.payloads {
                CodeBlockItemSyntax("self.\(payload.identifier) = try content.value(forProperty: \(literal: payload.name))")
            }
        }
    }

    static func discriminatedGenerationSchemaDecl(for choice: EnumChoiceModel) -> DeclSyntax {
        let properties = discriminatedPropertySchemaArray(for: choice)
        return """
        nonisolated static var generationSchema: AIKit.GenerationSchema {
            AIKit.GenerationSchema(
                type: Self.self,
                properties: \(properties)
            )
        }
        """
    }

    static func discriminatedGeneratedContentDecl(for choice: EnumChoiceModel) -> DeclSyntax {
        let properties = discriminatedStoredProperties(for: choice)
        let additions = CodeBlockItemListSyntax {
            for property in properties {
                generatedContentAddLine(for: property)
            }
        }

        return """
        nonisolated var generatedContent: AIKit.GeneratedContent {
            let explicitNil = false
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

    static func discriminatedPropertySchemaArray(for choice: EnumChoiceModel) -> ArrayExprSyntax {
        ArrayExprSyntax {
            for property in discriminatedStoredProperties(for: choice) {
                ArrayElementSyntax(expression: propertySchemaCall(for: property))
            }
        }
    }

    static func discriminatedStoredProperties(for choice: EnumChoiceModel) -> [StoredPropertyModel] {
        var properties = [
            StoredPropertyModel(
                name: "type",
                identifier: .identifier("type"),
                type: TypeSyntax("String"),
                guide: GuideModel(
                    description: nil,
                    expressions: [
                        ExprSyntax("AIKit.GenerationGuide<String>.constant(\(literal: choice.name))")
                    ]
                )
            )
        ]

        for payload in choice.payloads {
            properties.append(
                StoredPropertyModel(
                    name: payload.name,
                    identifier: payload.identifier,
                    type: payload.type,
                    guide: nil
                )
            )
        }

        return properties
    }

    static func associatedEnumGeneratedContentSwitch(for model: GenerableEnumModel) -> SwitchExprSyntax {
        SwitchExprSyntax(
            switchKeyword: .keyword(.switch, trailingTrivia: .space),
            subject: ExprSyntax("self").with(\.trailingTrivia, .space),
            leftBrace: .leftBraceToken(trailingTrivia: .newline),
            cases: SwitchCaseListSyntax {
                for choice in model.choices {
                    SwitchCaseSyntax(
                        label: .case(caseLabel(pattern: enumPattern(for: choice))),
                        statements: CodeBlockItemListSyntax {
                            CodeBlockItemSyntax(
                                leadingTrivia: .spaces(4),
                                item: .expr(generatedContentExpression(for: choice)),
                                trailingTrivia: .newline
                            )
                        }
                    )
                }
            }
        )
    }

    static func associatedEnumInitializerSwitch(for model: GenerableEnumModel) -> SwitchExprSyntax {
        SwitchExprSyntax(
            switchKeyword: .keyword(.switch, trailingTrivia: .space),
            subject: ExprSyntax("type").with(\.trailingTrivia, .space),
            leftBrace: .leftBraceToken(trailingTrivia: .newline),
            cases: SwitchCaseListSyntax {
                for choice in model.choices {
                    SwitchCaseSyntax(
                        label: .case(caseLabel(pattern: PatternSyntax("\(literal: choice.name)"))),
                        statements: CodeBlockItemListSyntax {
                            CodeBlockItemSyntax(
                                leadingTrivia: .spaces(4),
                                item: .expr(ExprSyntax("self = \(enumConstructionExpression(for: choice))")),
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
                                    #"throw AIKit.GeneratedContentError.invalidValue("Unexpected type \(type) for \(Self.self).")"#
                                )
                            ),
                            trailingTrivia: .newline
                        )
                    }
                )
            }
        )
    }

    static func enumCaseDeclSource(for choice: EnumChoiceModel, usesPartialTypes: Bool) -> String {
        guard !choice.payloads.isEmpty else {
            return "case \(choice.identifier.text)"
        }

        var pieces = [String]()
        for payload in choice.payloads {
            let type = usesPartialTypes ? payload.partialGeneratedType.description : payload.type.description
            if payload.isLabeled {
                pieces.append("\(payload.name): \(type)")
            } else {
                pieces.append(type)
            }
        }

        return "case \(choice.identifier.text)(\(commaSeparated(pieces)))"
    }

    static func enumPattern(for choice: EnumChoiceModel) -> PatternSyntax {
        guard !choice.payloads.isEmpty else {
            return PatternSyntax(".\(choice.identifier)")
        }

        var pieces = [String]()
        for payload in choice.payloads {
            pieces.append("let \(payload.identifier.text)")
        }

        return PatternSyntax(stringLiteral: ".\(choice.identifier.text)(\(commaSeparated(pieces)))")
    }

    static func enumConstructionExpression(for choice: EnumChoiceModel) -> ExprSyntax {
        guard !choice.payloads.isEmpty else {
            return ExprSyntax(".\(choice.identifier)")
        }

        var pieces = [String]()
        for payload in choice.payloads {
            var piece = ""
            if payload.isLabeled {
                piece += "\(payload.name): "
            }
            piece += "try content.value(forProperty: \(quotedString(payload.name)))"
            pieces.append(piece)
        }

        return ExprSyntax(stringLiteral: ".\(choice.identifier.text)(\(commaSeparated(pieces)))")
    }

    static func generatedContentExpression(for choice: EnumChoiceModel) -> ExprSyntax {
        var properties = [
            "\(quotedString("type")): \(quotedString(choice.name))"
        ]

        for payload in choice.payloads {
            properties.append("\(quotedString(payload.name)): \(payload.identifier.text)")
        }

        return ExprSyntax(stringLiteral: "AIKit.GeneratedContent(properties: [\(commaSeparated(properties))])")
    }

    static func commaSeparated(_ pieces: [String]) -> String {
        var result = ""
        for piece in pieces {
            if !result.isEmpty {
                result += ", "
            }
            result += piece
        }
        return result
    }

    static func quotedString(_ value: String) -> String {
        String(reflecting: value)
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
