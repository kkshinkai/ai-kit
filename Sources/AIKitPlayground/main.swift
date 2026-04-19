import AIKit
import Foundation

@Generable(description: "Playground input.")
struct PlaygroundInput {
    @Guide(description: "Name to greet")
    var name: String
}

let name = ProcessInfo.processInfo.environment["AIKIT_NAME"] ?? "Playground"
let input = PlaygroundInput(name: name)

print(input.generatedContent.jsonString)
