import Testing

@testable import AIKit

@Test func packageExposesGeneratedContent() {
    #expect("AIKit".generatedContent == GeneratedContent(kind: .string("AIKit")))
}
