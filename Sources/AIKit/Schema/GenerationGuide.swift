import Foundation

public struct GenerationGuide<Value>: Codable, Equatable, Sendable {
    indirect enum Rule: Codable, Equatable, Sendable {
        case stringConstant(String)
        case stringAnyOf([String])
        case stringPattern(String)
        case stringRegex(String)
        case integerMinimum(Int)
        case integerMaximum(Int)
        case numberMinimum(Decimal)
        case numberMaximum(Decimal)
        case minimumCount(Int)
        case maximumCount(Int)
        case element(DynamicGenerationSchema)
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

    public static func pattern<Output>(_ regex: Regex<Output>) -> Self {
        Self(rule: .stringRegex(String(describing: regex)))
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

extension GenerationGuide where Value == Float {
    public static func minimum(_ value: Float) -> Self {
        Self(rule: .numberMinimum(Decimal(Double(value))))
    }

    public static func maximum(_ value: Float) -> Self {
        Self(rule: .numberMaximum(Decimal(Double(value))))
    }

    public static func range(_ range: ClosedRange<Float>) -> Self {
        Self(rules: [
            .numberMinimum(Decimal(Double(range.lowerBound))),
            .numberMaximum(Decimal(Double(range.upperBound)))
        ])
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

extension GenerationGuide {
    public static func minimumCount<Element>(_ count: Int) -> GenerationGuide<[Element]> where Value == [Element] {
        GenerationGuide<[Element]>(rule: .minimumCount(count))
    }

    public static func maximumCount<Element>(_ count: Int) -> GenerationGuide<[Element]> where Value == [Element] {
        GenerationGuide<[Element]>(rule: .maximumCount(count))
    }

    public static func count<Element>(_ count: Int) -> GenerationGuide<[Element]> where Value == [Element] {
        GenerationGuide<[Element]>(rules: [.minimumCount(count), .maximumCount(count)])
    }

    public static func count<Element>(_ range: ClosedRange<Int>) -> GenerationGuide<[Element]> where Value == [Element] {
        GenerationGuide<[Element]>(rules: [.minimumCount(range.lowerBound), .maximumCount(range.upperBound)])
    }

    public static func element<Element>(
        _ guide: GenerationGuide<Element>
    ) -> GenerationGuide<[Element]> where Value == [Element], Element: Generable {
        GenerationGuide<[Element]>(rule: .element(DynamicGenerationSchema(type: Element.self, guides: [guide])))
    }
}
