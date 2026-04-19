@attached(extension, conformances: Generable, names: named(init(_:)))
@attached(member, names: named(generationSchema), named(generatedContent), named(PartiallyGenerated))
public macro Generable(description: String? = nil) = #externalMacro(module: "AIKitMacros", type: "GenerableMacro")

@attached(extension, conformances: Generable, names: named(init(_:)))
@attached(member, names: named(generationSchema), named(generatedContent), named(PartiallyGenerated))
public macro Generable(
    description: String? = nil,
    representNilExplicitlyInGeneratedContent: Bool
) = #externalMacro(module: "AIKitMacros", type: "GenerableMacro")

@attached(peer)
public macro Guide<T>(description: String? = nil, _ guides: GenerationGuide<T>...) = #externalMacro(module: "AIKitMacros", type: "GuideMacro") where T: Generable

@attached(peer)
public macro Guide<RegexOutput>(
    description: String? = nil,
    _ guides: Regex<RegexOutput>
) = #externalMacro(module: "AIKitMacros", type: "GuideMacro")

@attached(peer)
public macro Guide(description: String) = #externalMacro(module: "AIKitMacros", type: "GuideMacro")
