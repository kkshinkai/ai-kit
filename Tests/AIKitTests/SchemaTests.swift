import Foundation
import Testing

@testable import AIKit

@Generable(description: "Arguments for a weather lookup.")
private struct WeatherArguments {
    @Guide(description: "The city to get weather for")
    var city: String

    @Guide(description: "Number of forecast days", .range(1...10))
    var days: Int

    @Guide(description: "Optional weather units")
    var units: String?
}

@Generable(description: "Weather units.")
private enum WeatherUnits {
    case celsius
    case fahrenheit
}

@Generable(description: "A list response.")
private struct ListResponse {
    @Guide(description: "Generated labels", GenerationGuide<[String]>.count(2...4))
    var labels: [String]
}

@Test func generatedContentRoundTripsThroughGeneratedStruct() throws {
    let arguments = WeatherArguments(city: "Tokyo", days: 3, units: nil)
    let content = arguments.generatedContent

    #expect(content.jsonValue == JSONValue.object([
        "city": JSONValue.string("Tokyo"),
        "days": JSONValue.number(3)
    ]))

    let decoded = try WeatherArguments(content)
    #expect(decoded.city == "Tokyo")
    #expect(decoded.days == 3)
    #expect(decoded.units == nil)
}

@Test func generatedEnumUsesStringChoices() throws {
    #expect(WeatherUnits.celsius.generatedContent == GeneratedContent(kind: .string("celsius")))
    #expect(try WeatherUnits(GeneratedContent(kind: .string("fahrenheit"))) == .fahrenheit)
}

@Test func jsonContentParsesAndExtractsProperties() throws {
    let content = try GeneratedContent(json: #"{"city":"Kyoto","days":5,"units":"celsius"}"#)

    #expect(try content.value(String.self, forProperty: "city") == "Kyoto")
    #expect(try content.value(Int.self, forProperty: "days") == 5)
    #expect(try content.value(String?.self, forProperty: "units") == "celsius")
}

@Test func schemaExportsJSONSchemaLikeObject() {
    let schema = WeatherArguments.generationSchema.jsonSchema

    guard case let .object(object) = schema else {
        Issue.record("Expected object schema.")
        return
    }

    #expect(object["type"] == JSONValue.string("object"))
    #expect(object["title"] == JSONValue.string("WeatherArguments"))
    #expect(object["description"] == JSONValue.string("Arguments for a weather lookup."))
    #expect(object["additionalProperties"] == JSONValue.bool(false))
    #expect(object["required"] == JSONValue.array([JSONValue.string("city"), JSONValue.string("days")]))
}

@Test func enumSchemaExportsChoices() {
    let schema = WeatherUnits.generationSchema.jsonSchema

    guard case let .object(object) = schema else {
        Issue.record("Expected object schema.")
        return
    }

    #expect(object["type"] == JSONValue.string("string"))
    #expect(object["enum"] == JSONValue.array([JSONValue.string("celsius"), JSONValue.string("fahrenheit")]))
}

@Test func arrayGuidesExportCountBounds() {
    let schema = ListResponse.generationSchema.jsonSchema

    guard case let .object(object) = schema,
          case let .object(properties)? = object["properties"],
          case let .object(labels)? = properties["labels"]
    else {
        Issue.record("Expected labels property schema.")
        return
    }

    #expect(labels["type"] == JSONValue.string("array"))
    #expect(labels["minItems"] == JSONValue.number(2))
    #expect(labels["maxItems"] == JSONValue.number(4))
}

@Test func primitiveArraysRoundTrip() throws {
    let content = ["a", "b"].generatedContent

    #expect(try [String](content) == ["a", "b"])
}
