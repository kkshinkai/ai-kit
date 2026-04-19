import SwiftSyntax
import SwiftSyntaxMacros

public struct GenerableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let model = GenerableParser.parse(
            declaration: declaration,
            attribute: node,
            context: context,
            emitDiagnostics: true
        ) else {
            return []
        }

        return try GenerableCodegen.members(for: model)
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let model = GenerableParser.parse(
            declaration: declaration,
            attribute: node,
            context: context,
            emitDiagnostics: false
        ) else {
            return []
        }

        return [
            try GenerableCodegen.extensionDecl(
                for: model,
                extendedType: type,
                addsConformance: !protocols.isEmpty
            )
        ]
    }
}
