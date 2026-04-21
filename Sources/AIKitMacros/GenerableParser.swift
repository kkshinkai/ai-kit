import SwiftSyntax
import SwiftSyntaxMacros

enum GenerableParser {
    static func parse(
        declaration: some DeclGroupSyntax,
        attribute: AttributeSyntax,
        context: some MacroExpansionContext,
        emitDiagnostics: Bool
    ) -> GenerableTypeModel? {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            guard structDecl.genericParameterClause == nil else {
                context.diagnose(.generableDoesNotSupportGenericTypes, at: structDecl.name, when: emitDiagnostics)
                return nil
            }

            return parseStruct(
                structDecl,
                attribute: attribute,
                context: context,
                emitDiagnostics: emitDiagnostics
            ).map(GenerableTypeModel.structure)
        }

        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            guard enumDecl.genericParameterClause == nil else {
                context.diagnose(.generableDoesNotSupportGenericTypes, at: enumDecl.name, when: emitDiagnostics)
                return nil
            }

            return parseEnum(
                enumDecl,
                attribute: attribute,
                context: context,
                emitDiagnostics: emitDiagnostics
            ).map(GenerableTypeModel.enumeration)
        }

        context.diagnose(.generableRequiresStructOrEnum, at: attribute, when: emitDiagnostics)
        return nil
    }
}

private extension GenerableParser {
    static func parseStruct(
        _ declaration: StructDeclSyntax,
        attribute: AttributeSyntax,
        context: some MacroExpansionContext,
        emitDiagnostics: Bool
    ) -> GenerableStructModel? {
        let arguments = MacroSyntaxSupport.argumentExpressions(from: attribute)
        let explicitNilArgument = arguments.first { $0.label == "representNilExplicitlyInGeneratedContent" }?.expression
        var properties = [StoredPropertyModel]()
        var hasError = false

        for member in declaration.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }

            switch parseStoredProperty(variable, context: context, emitDiagnostics: emitDiagnostics) {
            case let .property(property):
                properties.append(property)
            case .ignored:
                continue
            case .invalid:
                hasError = true
            }
        }

        guard !hasError else {
            return nil
        }

        return GenerableStructModel(
            description: arguments.first { $0.label == "description" }?.expression,
            explicitNil: explicitNilArgument ?? ExprSyntax("false"),
            explicitNilArgument: explicitNilArgument,
            properties: properties
        )
    }

    static func parseStoredProperty(
        _ variable: VariableDeclSyntax,
        context: some MacroExpansionContext,
        emitDiagnostics: Bool
    ) -> StoredPropertyParseResult {
        let guideAttributes = MacroSyntaxSupport.guideAttributes(in: variable.attributes)
        let hasGuide = !guideAttributes.isEmpty
        var hasError = false

        if guideAttributes.count > 1 {
            context.diagnose(.duplicateGuide, at: guideAttributes[1], when: emitDiagnostics)
            hasError = true
        }

        if variable.isStaticLike || variable.isLazy {
            if hasGuide {
                context.diagnose(.guideRequiresStoredInstanceProperty, at: guideAttributes[0], when: emitDiagnostics)
                hasError = true
            }
            return hasError ? .invalid : .ignored
        }

        if variable.bindings.contains(where: \.isComputedProperty) {
            if hasGuide {
                context.diagnose(.guideRequiresStoredInstanceProperty, at: guideAttributes[0], when: emitDiagnostics)
                hasError = true
            }
            return hasError ? .invalid : .ignored
        }

        guard !hasError else {
            return .invalid
        }

        guard variable.bindings.count == 1 else {
            context.diagnose(.propertyRequiresSingleBinding, at: variable, when: emitDiagnostics)
            return .invalid
        }

        guard let binding = variable.bindings.first else {
            context.diagnose(.propertyRequiresSingleBinding, at: variable, when: emitDiagnostics)
            return .invalid
        }

        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            context.diagnose(.propertyRequiresIdentifierPattern, at: binding.pattern, when: emitDiagnostics)
            return .invalid
        }

        guard let type = binding.typeAnnotation?.type.trimmed else {
            context.diagnose(.propertyRequiresTypeAnnotation, at: pattern, when: emitDiagnostics)
            return .invalid
        }

        return .property(
            StoredPropertyModel(
                name: pattern.identifier.text,
                identifier: pattern.identifier.trimmed,
                type: type,
                guide: guideAttributes.first.map(parseGuide)
            )
        )
    }

    static func parseEnum(
        _ declaration: EnumDeclSyntax,
        attribute: AttributeSyntax,
        context: some MacroExpansionContext,
        emitDiagnostics: Bool
    ) -> GenerableEnumModel? {
        let arguments = MacroSyntaxSupport.argumentExpressions(from: attribute)
        var choices = [EnumChoiceModel]()
        var hasError = false

        for member in declaration.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                continue
            }

            if MacroSyntaxSupport.guideAttribute(in: caseDecl.attributes) != nil {
                context.diagnose(.enumGuideIsUnsupported, at: caseDecl, when: emitDiagnostics)
                hasError = true
            }

            for element in caseDecl.elements {
                choices.append(
                    EnumChoiceModel(
                        name: element.name.text,
                        identifier: element.name.trimmed,
                        payloads: parseEnumPayloads(element.parameterClause)
                    )
                )
            }
        }

        if choices.isEmpty {
            context.diagnose(.enumRequiresCases, at: declaration.name, when: emitDiagnostics)
            hasError = true
        }

        guard !hasError else {
            return nil
        }

        return GenerableEnumModel(
            description: arguments.first { $0.label == "description" }?.expression,
            choices: choices
        )
    }

    static func parseEnumPayloads(_ clause: EnumCaseParameterClauseSyntax?) -> [EnumPayloadModel] {
        guard let clause else {
            return []
        }

        return clause.parameters.enumerated().map { index, parameter in
            let name = payloadName(for: parameter, at: index)
            return EnumPayloadModel(
                name: name,
                identifier: payloadIdentifier(for: parameter, fallbackName: name),
                type: parameter.type.trimmed,
                isLabeled: isLabeled(parameter)
            )
        }
    }

    static func payloadName(for parameter: EnumCaseParameterSyntax, at index: Int) -> String {
        if isLabeled(parameter), let firstName = parameter.firstName, firstName.text != "_" {
            return firstName.text
        }

        if let secondName = parameter.secondName, secondName.text != "_" {
            return secondName.text
        }

        return index == 0 ? "value" : "value\(index)"
    }

    static func payloadIdentifier(for parameter: EnumCaseParameterSyntax, fallbackName: String) -> TokenSyntax {
        if isLabeled(parameter), let firstName = parameter.firstName, firstName.text != "_" {
            return firstName.trimmed
        }

        if let secondName = parameter.secondName, secondName.text != "_" {
            return secondName.trimmed
        }

        return .identifier(fallbackName)
    }

    static func isLabeled(_ parameter: EnumCaseParameterSyntax) -> Bool {
        parameter.colon != nil && parameter.firstName?.text != "_"
    }

    static func parseGuide(_ attribute: AttributeSyntax) -> GuideModel {
        let arguments = MacroSyntaxSupport.argumentExpressions(from: attribute)
        return GuideModel(
            description: arguments.first { $0.label == "description" }?.expression,
            expressions: MacroSyntaxSupport.guideExpressions(from: attribute)
        )
    }
}
