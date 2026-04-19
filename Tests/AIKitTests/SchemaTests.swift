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

@Generable(description: "A location.")
private struct SchemaLocation {
    @Guide(description: "City name")
    var city: String
}

@Generable(description: "A forecast.")
private struct SchemaForecast {
    @Guide(description: "Forecast location")
    var location: SchemaLocation

    @Guide(description: "Forecast stops")
    var stops: [SchemaLocation]
}

@Generable(description: "A trip plan.")
private struct SchemaPlan {
    var forecast: SchemaForecast
}

@Generable(description: "A union placeholder.")
private enum SchemaUnion {
    case location
    case forecast
}

@Generable(description: "Explicit nil arguments.", representNilExplicitlyInGeneratedContent: true)
private struct ExplicitNilArguments {
    var note: String?
}

@Generable(description: "Element guide response.")
private struct ElementGuideResponse {
    @Guide(description: "Generated labels", GenerationGuide<[String]>.element(.pattern("^label")))
    var labels: [String]
}

@Generable(description: "Float response.")
private struct FloatResponse {
    @Guide(description: "Score", .range(0.5...1.5))
    var score: Float
}

@Generable(description: "Regex response.")
private struct RegexResponse {
    @Guide(description: "Airport code", /^[A-Z]{3}$/)
    var code: String
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

@Test func generatedEnumRoundTripsThroughGeneratedContent() throws {
    let content = WeatherUnits.fahrenheit.generatedContent

    #expect(try content.value(String.self) == "fahrenheit")
    #expect(try WeatherUnits(content) == .fahrenheit)
}

@Test func nestedGenerableGeneratedContentRoundTrip() throws {
    let forecast = SchemaForecast(
        location: SchemaLocation(city: "Tokyo"),
        stops: [
            SchemaLocation(city: "Kyoto"),
            SchemaLocation(city: "Osaka")
        ]
    )
    let content = forecast.generatedContent

    #expect(content.jsonValue == .object([
        "location": .object(["city": .string("Tokyo")]),
        "stops": .array([
            .object(["city": .string("Kyoto")]),
            .object(["city": .string("Osaka")])
        ])
    ]))

    let decoded = try SchemaForecast(content)
    #expect(decoded.location.city == "Tokyo")
    #expect(decoded.stops.map(\.city) == ["Kyoto", "Osaka"])
    #expect(SchemaForecast.generationSchema.dependencies.compactMap(\.name) == ["SchemaLocation"])
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

@Test func manualRootSchemaAcceptsResolvedReferences() throws {
    let dependency = DynamicGenerationSchema(name: "ManualDependency", properties: [
        .init(name: "value", schema: DynamicGenerationSchema(type: String.self))
    ])
    let root = DynamicGenerationSchema(name: "ManualRoot", properties: [
        .init(name: "dependency", schema: DynamicGenerationSchema(referenceTo: "ManualDependency"))
    ])

    let schema = try GenerationSchema(root: root, dependencies: [dependency])

    #expect(schema.root.name == "ManualRoot")
    #expect(schema.dependencies.map(\.name) == ["ManualDependency"])
}

@Test func schemaValidationReportsDuplicateDependencyTypes() {
    let dependency = DynamicGenerationSchema(name: "DuplicateDependency", properties: [])
    let root = DynamicGenerationSchema(name: "ManualRoot", properties: [])

    expectSchemaError({
        try GenerationSchema(root: root, dependencies: [dependency, dependency])
    }) { error in
        guard case let .duplicateType(_, type, _) = error else {
            return false
        }
        return type == "DuplicateDependency"
    }
}

@Test func schemaValidationReportsDuplicateProperties() {
    let root = DynamicGenerationSchema(name: "ManualRoot", properties: [
        .init(name: "value", schema: DynamicGenerationSchema(type: String.self)),
        .init(name: "value", schema: DynamicGenerationSchema(type: Int.self))
    ])

    expectSchemaError({
        try GenerationSchema(root: root, dependencies: [])
    }) { error in
        guard case let .duplicateProperty(schema, property, _) = error else {
            return false
        }
        return schema == "ManualRoot" && property == "value"
    }
}

@Test func schemaValidationReportsEmptyTypeChoices() {
    let root = DynamicGenerationSchema(name: "ManualChoice", anyOf: [DynamicGenerationSchema]())

    expectSchemaError({
        try GenerationSchema(root: root, dependencies: [])
    }) { error in
        guard case let .emptyTypeChoices(schema, _) = error else {
            return false
        }
        return schema == "ManualChoice"
    }
}

@Test func schemaValidationReportsUndefinedReferences() {
    let root = DynamicGenerationSchema(name: "ManualRoot", properties: [
        .init(name: "missing", schema: DynamicGenerationSchema(referenceTo: "MissingDependency"))
    ])

    expectSchemaError({
        try GenerationSchema(root: root, dependencies: [])
    }) { error in
        guard case let .undefinedReferences(_, references, _) = error else {
            return false
        }
        return references == ["MissingDependency"]
    }
}

@Test func nestedGenerablePropertiesUseReferencesAndDependencies() {
    let schema = SchemaForecast.generationSchema

    #expect(schema.dependencies.compactMap(\.name) == ["SchemaLocation"])

    guard case let .object(object) = schema.jsonSchema,
          case let .object(properties)? = object["properties"],
          case let .object(location)? = properties["location"],
          case let .object(stops)? = properties["stops"],
          case let .object(items)? = stops["items"],
          case let .object(definitions)? = object["$defs"]
    else {
        Issue.record("Expected nested schema with definitions.")
        return
    }

    #expect(location["$ref"] == JSONValue.string("#/$defs/SchemaLocation"))
    #expect(items["$ref"] == JSONValue.string("#/$defs/SchemaLocation"))
    #expect(definitions["SchemaLocation"] != nil)
}

@Test func multiLevelNestedSchemasDoNotDuplicateDependencies() {
    let schema = SchemaPlan.generationSchema

    #expect(schema.dependencies.compactMap(\.name) == ["SchemaForecast", "SchemaLocation"])
}

@Test func anyOfTypesCollectsChoiceDependencies() {
    let schema = GenerationSchema(type: SchemaUnion.self, anyOf: [SchemaLocation.self, SchemaForecast.self])

    #expect(schema.dependencies.compactMap(\.name) == ["SchemaLocation", "SchemaForecast"])

    guard case let .object(object) = schema.jsonSchema,
          case let .array(choices)? = object["anyOf"]
    else {
        Issue.record("Expected anyOf schema.")
        return
    }

    #expect(choices == [
        .object(["$ref": .string("#/$defs/SchemaLocation")]),
        .object(["$ref": .string("#/$defs/SchemaForecast")])
    ])
}

@Test func explicitNilGeneratedContentWritesNullProperties() {
    let content = ExplicitNilArguments(note: nil).generatedContent

    #expect(content.jsonValue == .object(["note": .null]))

    guard case let .object(object) = ExplicitNilArguments.generationSchema.jsonSchema else {
        Issue.record("Expected object schema.")
        return
    }

    #expect(object["required"] == .array([]))
}

@Test func elementGuidesApplyToArrayItems() {
    let schema = ElementGuideResponse.generationSchema.jsonSchema

    guard case let .object(object) = schema,
          case let .object(properties)? = object["properties"],
          case let .object(labels)? = properties["labels"],
          case let .object(items)? = labels["items"]
    else {
        Issue.record("Expected labels item schema.")
        return
    }

    #expect(items["type"] == .string("string"))
    #expect(items["pattern"] == .string("^label"))
}

@Test func floatGuidesExportNumberBounds() {
    let schema = FloatResponse.generationSchema.jsonSchema

    guard case let .object(object) = schema,
          case let .object(properties)? = object["properties"],
          case let .object(score)? = properties["score"]
    else {
        Issue.record("Expected score schema.")
        return
    }

    #expect(score["type"] == .string("number"))
    #expect(score["minimum"] == .number(Decimal(0.5)))
    #expect(score["maximum"] == .number(Decimal(1.5)))
}

@Test func regexLiteralGuideExportsStringPattern() {
    let schema = RegexResponse.generationSchema.jsonSchema

    guard case let .object(object) = schema,
          case let .object(properties)? = object["properties"],
          case let .object(code)? = properties["code"]
    else {
        Issue.record("Expected code schema.")
        return
    }

    #expect(code["type"] == .string("string"))
    #expect(code["description"] == .string("Airport code"))
    #expect(code["pattern"] == .string("^[A-Z]{3}$"))
}

private func expectSchemaError(
    _ operation: () throws -> GenerationSchema,
    matches: (GenerationSchema.SchemaError) -> Bool
) {
    do {
        _ = try operation()
        Issue.record("Expected GenerationSchema.SchemaError.")
    } catch let error as GenerationSchema.SchemaError {
        #expect(matches(error))
    } catch {
        Issue.record("Expected GenerationSchema.SchemaError, got \(error).")
    }
}
