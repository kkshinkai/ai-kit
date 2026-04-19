@attached(extension, conformances: Generable, names: named(init(_:)), named(generatedContent))
@attached(member, names: arbitrary)
public macro Generable(description: String? = nil) = #externalMacro(module: "AIKitMacros", type: "GenerableMacro")

@attached(peer)
public macro Guide<T>(description: String? = nil, _ guides: GenerationGuide<T>...) = #externalMacro(module: "AIKitMacros", type: "GuideMacro") where T: Generable

@attached(peer)
public macro Guide(description: String) = #externalMacro(module: "AIKitMacros", type: "GuideMacro")
