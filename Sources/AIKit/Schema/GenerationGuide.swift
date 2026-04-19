import Foundation

public struct GenerationGuide<Value>: Codable, Equatable, Sendable {
    enum Rule: Codable, Equatable, Sendable {
        case stringConstant(String)
        case stringAnyOf([String])
        case stringPattern(String)
        case integerMinimum(Int)
        case integerMaximum(Int)
        case numberMinimum(Decimal)
        case numberMaximum(Decimal)
        case minimumCount(Int)
        case maximumCount(Int)
    }

    let rules: [Rule]

    init(rule: Rule) {
        rules = [rule]
    }

    init(rules: [Rule]) {
        self.rules = rules
    }
}

extension GenerationGuide where Value == String {
    public static func constant(_ value: String) -> Self {
        Self(rule: .stringConstant(value))
    }

    public static func anyOf(_ values: [String]) -> Self {
        Self(rule: .stringAnyOf(values))
    }

    public static func pattern(_ pattern: String) -> Self {
        Self(rule: .stringPattern(pattern))
    }
}

extension GenerationGuide where Value == Int {
    public static func minimum(_ value: Int) -> Self {
        Self(rule: .integerMinimum(value))
    }

    public static func maximum(_ value: Int) -> Self {
        Self(rule: .integerMaximum(value))
    }

    public static func range(_ range: ClosedRange<Int>) -> Self {
        Self(rules: [.integerMinimum(range.lowerBound), .integerMaximum(range.upperBound)])
    }
}

extension GenerationGuide where Value == Double {
    public static func minimum(_ value: Double) -> Self {
        Self(rule: .numberMinimum(Decimal(value)))
    }

    public static func maximum(_ value: Double) -> Self {
        Self(rule: .numberMaximum(Decimal(value)))
    }

    public static func range(_ range: ClosedRange<Double>) -> Self {
        Self(rules: [.numberMinimum(Decimal(range.lowerBound)), .numberMaximum(Decimal(range.upperBound))])
    }
}

extension GenerationGuide where Value == Decimal {
    public static func minimum(_ value: Decimal) -> Self {
        Self(rule: .numberMinimum(value))
    }

    public static func maximum(_ value: Decimal) -> Self {
        Self(rule: .numberMaximum(value))
    }

    public static func range(_ range: ClosedRange<Decimal>) -> Self {
        Self(rules: [.numberMinimum(range.lowerBound), .numberMaximum(range.upperBound)])
    }
}

extension GenerationGuide where Value: Collection {
    public static func minimumCount(_ count: Int) -> Self {
        Self(rule: .minimumCount(count))
    }

    public static func maximumCount(_ count: Int) -> Self {
        Self(rule: .maximumCount(count))
    }

    public static func count(_ count: Int) -> Self {
        Self(rules: [.minimumCount(count), .maximumCount(count)])
    }

    public static func count(_ range: ClosedRange<Int>) -> Self {
        Self(rules: [.minimumCount(range.lowerBound), .maximumCount(range.upperBound)])
    }
}
