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
        var sawAssociatedValueCase = false

        for member in declaration.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                continue
            }

            if MacroSyntaxSupport.guideAttribute(in: caseDecl.attributes) != nil {
                context.diagnose(.enumGuideIsUnsupported, at: caseDecl, when: emitDiagnostics)
                hasError = true
            }

            for element in caseDecl.elements {
                if element.parameterClause != nil {
                    sawAssociatedValueCase = true
                    context.diagnose(.enumAssociatedValuesAreUnsupported, at: element.name, when: emitDiagnostics)
                    hasError = true
                    continue
                }

                choices.append(
                    EnumChoiceModel(
                        name: element.name.text,
                        identifier: element.name.trimmed
                    )
                )
            }
        }

        if choices.isEmpty && !sawAssociatedValueCase {
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

    static func parseGuide(_ attribute: AttributeSyntax) -> GuideModel {
        let arguments = MacroSyntaxSupport.argumentExpressions(from: attribute)
        return GuideModel(
            description: arguments.first { $0.label == "description" }?.expression,
            expressions: MacroSyntaxSupport.guideExpressions(from: attribute)
        )
    }
}
