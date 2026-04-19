import AIKit
import Foundation

@Generable(description: "Preferred travel plan style.")
enum TripStyle {
    case food
    case architecture
    case family
}

@Generable(description: "A city stop in a structured itinerary.")
struct CityStop {
    @Guide(description: "City name")
    var city: String

    @Guide(description: "IATA airport code", /^[A-Z]{3}$/)
    var airportCode: String

    @Guide(description: "Number of nights", .range(1...14))
    var nights: Int
}

@Generable(
    description: "A request for an LLM to generate a structured travel plan.",
    representNilExplicitlyInGeneratedContent: true
)
struct TripRequest {
    @Guide(description: "Traveler name read from the environment")
    let traveler: String

    @Guide(description: "Preferred travel plan style")
    var style: TripStyle

    @Guide(description: "Stops to include in the plan", GenerationGuide<[CityStop]>.count(2...4))
    var stops: [CityStop]

    @Guide(
        description: "Short lowercase labels for the generated itinerary",
        GenerationGuide<[String]>.element(.pattern("^[a-z][a-z-]{2,20}$"))
    )
    var labels: [String]

    @Guide(description: "Optional user note; nil is represented explicitly")
    var note: String?
}

let environment = ProcessInfo.processInfo.environment
let request = TripRequest(
    traveler: environment["AIKIT_NAME"] ?? "Playground",
    style: .architecture,
    stops: [
        CityStop(
            city: environment["AIKIT_ORIGIN_CITY"] ?? "Tokyo",
            airportCode: environment["AIKIT_ORIGIN_AIRPORT"] ?? "HND",
            nights: 2
        ),
        CityStop(
            city: environment["AIKIT_DESTINATION_CITY"] ?? "San Francisco",
            airportCode: environment["AIKIT_DESTINATION_AIRPORT"] ?? "SFO",
            nights: 4
        )
    ],
    labels: ["tokyo-start", "sf-finish"],
    note: environment["AIKIT_NOTE"]
)

print("=== Generated Content ===")
print(prettyJSON(request.generatedContent.jsonValue))

print("\n=== Schema Projection ===")
print(prettyJSON(TripRequest.generationSchema.jsonSchema))

do {
    let decoded = try TripRequest(request.generatedContent)
    print("\n=== Round Trip ===")
    print("Decoded traveler: \(decoded.traveler)")
    print("Decoded stops: \(decoded.stops.map(\.city).joined(separator: " -> "))")
} catch {
    print("\nRound-trip decode failed: \(error)")
}

func prettyJSON(_ value: JSONValue) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    guard let data = try? encoder.encode(value),
          let string = String(data: data, encoding: .utf8)
    else {
        return String(describing: value)
    }

    return string
}
