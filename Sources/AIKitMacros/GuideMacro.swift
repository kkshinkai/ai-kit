import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct GuideMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(VariableDeclSyntax.self) else {
            context.diagnose(AIKitMacroDiagnostic.guideRequiresProperty.diagnose(at: node))
            return []
        }

        return []
    }
}
