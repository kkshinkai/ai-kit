import Foundation

public struct GenerationID: Codable, Equatable, Hashable, Sendable {
    public var rawValue: String

    public init() {
        rawValue = UUID().uuidString
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
