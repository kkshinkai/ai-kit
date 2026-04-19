import AIKit
import Foundation

let name = ProcessInfo.processInfo.environment["AIKIT_NAME"] ?? "Playground"

print(AIKit.greeting(name: name))
