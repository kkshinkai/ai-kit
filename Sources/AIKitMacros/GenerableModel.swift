import SwiftSyntax

enum GenerableTypeModel {
    case structure(GenerableStructModel)
    case enumeration(GenerableEnumModel)
}

struct GenerableStructModel {
    var description: ExprSyntax?
    var explicitNil: ExprSyntax
    var explicitNilArgument: ExprSyntax?
    var properties: [StoredPropertyModel]
}

struct GenerableEnumModel {
    var description: ExprSyntax?
    var choices: [EnumChoiceModel]
}

struct StoredPropertyModel {
    var name: String
    var identifier: TokenSyntax
    var type: TypeSyntax
    var guide: GuideModel?

    var partialGeneratedType: TypeSyntax {
        TypeSyntax("\(type).PartiallyGenerated?")
    }
}

struct GuideModel {
    var description: ExprSyntax?
    var expressions: [ExprSyntax]
}

struct EnumChoiceModel {
    var name: String
    var identifier: TokenSyntax
}

enum StoredPropertyParseResult {
    case property(StoredPropertyModel)
    case ignored
    case invalid
}

struct MacroArgument {
    var label: String?
    var expression: ExprSyntax
}
