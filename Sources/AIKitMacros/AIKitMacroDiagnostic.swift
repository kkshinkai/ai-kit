import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

enum AIKitMacroDiagnostic: String, DiagnosticMessage {
    case generableRequiresStructOrEnum
    case generableDoesNotSupportGenericTypes
    case propertyRequiresSingleBinding
    case propertyRequiresIdentifierPattern
    case propertyRequiresTypeAnnotation
    case guideRequiresStoredInstanceProperty
    case guideRequiresProperty
    case duplicateGuide
    case enumRequiresCases
    case enumGuideIsUnsupported

    var message: String {
        switch self {
        case .generableRequiresStructOrEnum:
            "@Generable can only be applied to a struct or enum."
        case .generableDoesNotSupportGenericTypes:
            "@Generable does not support generic types yet."
        case .propertyRequiresSingleBinding:
            "@Generable properties must use a single binding."
        case .propertyRequiresIdentifierPattern:
            "@Generable properties must use a simple identifier pattern."
        case .propertyRequiresTypeAnnotation:
            "@Generable properties must have an explicit type annotation."
        case .guideRequiresStoredInstanceProperty:
            "@Guide can only be applied to stored instance properties included in @Generable."
        case .guideRequiresProperty:
            "@Guide can only be applied to a property."
        case .duplicateGuide:
            "A property can only have one @Guide attribute."
        case .enumRequiresCases:
            "@Generable enums must declare at least one case."
        case .enumGuideIsUnsupported:
            "@Guide cannot be applied to enum cases."
        }
    }

    var severity: DiagnosticSeverity {
        .error
    }

    var diagnosticID: MessageID {
        MessageID(domain: "AIKitMacros", id: rawValue)
    }

    func diagnose(at node: some SyntaxProtocol) -> Diagnostic {
        Diagnostic(node: Syntax(node), message: self)
    }
}

extension MacroExpansionContext {
    func diagnose(
        _ diagnostic: AIKitMacroDiagnostic,
        at node: some SyntaxProtocol,
        when shouldEmit: Bool = true
    ) {
        guard shouldEmit else {
            return
        }

        diagnose(diagnostic.diagnose(at: node))
    }
}
