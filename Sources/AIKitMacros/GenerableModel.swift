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

    var usesDiscriminatedUnion: Bool {
        choices.contains { !$0.payloads.isEmpty }
    }
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
    var payloads: [EnumPayloadModel]

    init(name: String, identifier: TokenSyntax, payloads: [EnumPayloadModel] = []) {
        self.name = name
        self.identifier = identifier
        self.payloads = payloads
    }

    var discriminatedType: TypeSyntax {
        TypeSyntax(stringLiteral: "Discriminated\(name.upperCamelCasedIdentifier)")
    }
}

struct EnumPayloadModel {
    var name: String
    var identifier: TokenSyntax
    var type: TypeSyntax
    var isLabeled: Bool

    var partialGeneratedType: TypeSyntax {
        TypeSyntax("\(type).PartiallyGenerated?")
    }
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

private extension String {
    var upperCamelCasedIdentifier: String {
        guard let first else {
            return self
        }

        return String(first).uppercased() + String(dropFirst())
    }
}
