import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct AIKitMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GenerableMacro.self,
        GuideMacro.self
    ]
}
