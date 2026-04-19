public enum GeneratedContentError: Error, Equatable, Sendable {
    case missingProperty(String)
    case typeMismatch(expected: String, actual: String)
    case invalidValue(String)
    case invalidJSON(String)
}
