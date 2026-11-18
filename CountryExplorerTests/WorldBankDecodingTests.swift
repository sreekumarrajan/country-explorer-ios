import Testing
import Foundation
@testable import CountryExplorer

/// Decoding tests against a real (trimmed) API payload.
///
/// These are the highest-value tests in a client app: the API is the one part
/// you do not control, and a shape change is the most common production
/// breakage. Pinning the envelope format here means a regression fails in CI
/// rather than on a user's phone.
struct WorldBankDecodingTests {

    /// A literal slice of a real World Bank response, including the
    /// two-element `[metadata, rows]` envelope.
    private let json = """
    [
      { "page": 1, "pages": 1, "per_page": 400, "total": 2 },
      [
        {
          "id": "JPN",
          "iso2Code": "JP",
          "name": "Japan",
          "region": { "id": "EAS", "value": "East Asia & Pacific" },
          "incomeLevel": { "id": "HIC", "value": "High income" },
          "capitalCity": "Tokyo",
          "longitude": "139.77",
          "latitude": "35.67"
        },
        {
          "id": "WLD",
          "iso2Code": "1W",
          "name": "World",
          "region": { "id": "NA", "value": "Aggregates" },
          "incomeLevel": { "id": "NA", "value": "Aggregates" },
          "capitalCity": "",
          "longitude": "",
          "latitude": ""
        }
      ]
    ]
    """.data(using: .utf8)!

    @Test("Unwraps the [metadata, rows] envelope")
    func decodesEnvelope() throws {
        let response = try JSONDecoder()
            .decode(WorldBankResponse<CountryDTO>.self, from: json)

        #expect(response.rows.count == 2)
        #expect(response.rows.first?.name == "Japan")
    }

    @Test("Maps a DTO to the domain model, parsing string coordinates")
    func mapsToDomain() throws {
        let response = try JSONDecoder()
            .decode(WorldBankResponse<CountryDTO>.self, from: json)
        let japan = try #require(response.rows.first)

        let country = japan.toDomain(population: 123_366_734)

        #expect(country.code == "JPN")
        #expect(country.capital == "Tokyo")
        // The API sends these as strings; the mapper must turn them into
        // Doubles. This assertion is what catches a lazy `Double` DTO.
        #expect(country.latitude == 35.67)
        #expect(country.longitude == 139.77)
        #expect(country.flagEmoji == "🇯🇵")
    }

    @Test("Normalises empty strings to nil")
    func normalisesEmptyStrings() throws {
        let response = try JSONDecoder()
            .decode(WorldBankResponse<CountryDTO>.self, from: json)
        let world = try #require(response.rows.last)

        let country = world.toDomain(population: nil)

        // "" must become nil, so the UI has exactly one "absent" case.
        #expect(country.capital == nil)
        #expect(country.latitude == nil)
        #expect(country.longitude == nil)
    }
}
