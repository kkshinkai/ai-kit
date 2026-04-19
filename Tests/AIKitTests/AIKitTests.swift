import Testing

@testable import AIKit

@Test func greetingUsesProvidedName() {
    #expect(AIKit.greeting(name: "SwiftPM") == "Hello, SwiftPM!")
}

@Test func greetingHasDefaultName() {
    #expect(AIKit.greeting() == "Hello, AIKit!")
}
