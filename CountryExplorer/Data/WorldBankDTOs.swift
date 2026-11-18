import Foundation

/// DTOs = Data Transfer Objects: the *wire* shape, mirroring the JSON exactly.
///
/// Decoding straight into `Country` would leak every API quirk into the whole
/// app. Keeping DTOs separate and mapping once means an API change touches one
/// file. Same reasoning as the Android repo — the pattern is platform-agnostic.
///
/// ## `Codable` vs kotlinx.serialization
///
/// `Decodable` conformance is *synthesised by the compiler* from your property
/// names — no per-field annotation, no visible codegen step. Kotlin needs
/// `@Serializable` plus a compiler plugin for the same result. Swift's version
/// is more automatic; Kotlin's is more explicit about what is happening.
struct CountryDTO: Decodable {
    let id: String              // "JPN"
    let iso2Code: String        // "JP"
    let name: String            // "Japan"
    let region: CodedValueDTO
    let incomeLevel: CodedValueDTO
    let capitalCity: String?
    // NOTE: the World Bank sends coordinates as *strings*, sometimes empty ("").
    // Decode them exactly as sent and convert later. Declaring these as `Double`
    // would make every single response fail to decode.
    let longitude: String?
    let latitude: String?
}

struct CodedValueDTO: Decodable {
    let id: String?
    let value: String?
}

/// One row of the population indicator response.
struct PopulationDTO: Decodable {
    let countryiso3code: String?
    let date: String?
    let value: Int?             // genuinely null for countries without data
}

// MARK: - Mapping wire shape to app shape

/// An `extension` adds methods to an existing type — Swift's counterpart to
/// Kotlin's extension functions. Swift's go further: they can add computed
/// properties, initialisers and protocol conformances, where Kotlin's are
/// static helpers with nicer call syntax.
extension CountryDTO {
    func toDomain(population: Int?) -> Country {
        Country(
            code: id,
            alpha2: iso2Code,
            name: name,
            // Normalise "absent" to a single representation (nil) right here,
            // so no UI code ever has to check for an empty string too.
            capital: capitalCity?.nonBlank,
            region: region.value ?? "",
            incomeLevel: incomeLevel.value ?? "",
            // `flatMap` on an Optional: stay nil if nil, otherwise try to parse
            // (which may itself produce nil).
            latitude: latitude.flatMap(Double.init),
            longitude: longitude.flatMap(Double.init),
            population: population
        )
    }
}

extension String {
    /// nil if the string is empty or only whitespace, otherwise itself.
    /// Kotlin has `ifBlank { null }` built in; in Swift you add it yourself —
    /// and because extensions are this cheap, everyone does.
    var nonBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}

/// ## The awkward-JSON lesson
///
/// The World Bank wraps every response in a two-element array of *different*
/// types:
///
///     [ { "page": 1, "pages": 1, ... },      <- metadata object
///       [ { ...row }, { ...row } ] ]         <- the actual rows
///
/// No single `Decodable` struct describes that, so we decode by hand. This is
/// the escape hatch worth knowing: `Codable` handles 95% of APIs for free, and
/// for the rest you implement `init(from:)` yourself.
///
/// `Row: Decodable` is a generic constraint — Kotlin's `<T : Decodable>`.
struct WorldBankResponse<Row: Decodable>: Decodable {
    let rows: [Row]

    init(from decoder: any Decoder) throws {
        // An *unkeyed* container is a JSON array (a keyed one is an object).
        var container = try decoder.unkeyedContainer()
        // Skip the metadata element. We must decode *something* to advance the
        // cursor, so we decode into a throwaway type.
        _ = try? container.decode(IgnoredMetadata.self)
        rows = try container.decode([Row].self)
    }

    /// An empty struct decodes successfully from any JSON object, purely to
    /// move the cursor past it.
    private struct IgnoredMetadata: Decodable {}
}
