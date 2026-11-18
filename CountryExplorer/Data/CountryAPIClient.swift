import Foundation

/// Thrown when the server replies with something we can't make sense of.
enum CountryDataError: LocalizedError, Equatable {
    case badStatus(Int)
    case decodingFailed(String)

    /// ## `enum` is Swift's best feature
    ///
    /// This is not a C-style list of constants — it is a sum type, and each
    /// case carries its own data. "Either a bad status with a code, or a
    /// decoding failure with a reason, and nothing else." The compiler then
    /// forces every `switch` to handle all cases.
    ///
    /// Kotlin's nearest equivalent is a `sealed interface` hierarchy, which
    /// needs a class per case. Swift makes it one declaration, so you reach for
    /// it constantly rather than occasionally.
    ///
    /// Conforming to `LocalizedError` is what makes `error.localizedDescription`
    /// show your text instead of Swift's unhelpful default.
    var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            return "The server returned status \(code)."
        case .decodingFailed:
            return "The server's response was in an unexpected format."
        }
    }
}

/// ## Program to a protocol
///
/// The repository depends on this *protocol*, never on the concrete client.
/// That indirection lets tests substitute a fake in a few lines, and swapping
/// data providers touches one file.
///
/// A `protocol` is Kotlin's `interface`, with one notable extra: structs and
/// enums can conform too, not just classes.
///
/// `Sendable` is the part with no Kotlin equivalent. It is a compile-time
/// promise that values of this type are safe to pass between concurrent tasks,
/// and Swift 6 *verifies* it. Kotlin relies on convention and code review for
/// the same property.
protocol CountryRemoteDataSource: Sendable {
    func fetchCountries() async throws -> [Country]
}

/// Talks to the World Bank: fires the requests, unwraps the odd envelope,
/// stitches two responses together, and returns clean `Country` values.
///
/// `final` means "not subclassable" — good practice on any class you don't
/// intend to be extended, and it lets the compiler skip dynamic dispatch.
final class WorldBankAPIClient: CountryRemoteDataSource {

    private let session: URLSession
    private let baseURL = URL(string: "https://api.worldbank.org/v2/")!

    /// Injecting `URLSession` rather than reaching for `.shared` is what makes
    /// this class testable without touching the network.
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// ## The structured-concurrency lesson
    ///
    /// The country list and the population numbers are independent, so they
    /// should go out *together*, not one after the other.
    ///
    ///     JS:      const [a, b] = await Promise.all([getA(), getB()])
    ///     Kotlin:  val a = async { getA() }; val b = async { getB() }; a.await()
    ///     Swift:   async let a = getA(); async let b = getB(); try await (a, b)
    ///
    /// `async let` starts the work immediately and binds a placeholder; the
    /// `await` below collects it. Like Kotlin's `coroutineScope`, this is
    /// *structured*: both child tasks must finish or be cancelled before this
    /// function can return, and if the caller is cancelled, both requests are
    /// cancelled too.
    ///
    /// Same guarantee as Kotlin, reached from the opposite direction: Kotlin
    /// makes you name a scope, Swift makes the function body the scope.
    func fetchCountries() async throws -> [Country] {
        async let countryRows = fetch(
            path: "country",
            query: ["format": "json", "per_page": "400"],
            as: CountryDTO.self
        )
        async let populationRows = fetch(
            path: "country/all/indicator/SP.POP.TOTL",
            query: ["format": "json", "mrv": "1", "per_page": "400"],
            as: PopulationDTO.self
        )

        // One `await` collects both. `try` covers the whole tuple: if either
        // threw, that error propagates and the other task is cancelled.
        let (countries, populations) = try await (countryRows, populationRows)

        // A lookup table makes the join below O(1) per country instead of a
        // nested scan. `reduce(into:)` mutates an accumulator in place, which
        // avoids allocating a new dictionary per element.
        let populationByCode: [String: Int] = populations.reduce(into: [:]) { table, row in
            // Several optional bindings in one `guard`. `guard` is an early
            // return with a mandatory else — it keeps the happy path
            // unindented, unlike nested `if let`.
            guard let code = row.countryiso3code, let value = row.value else { return }
            table[code] = value
        }

        return countries
            // The World Bank mixes ~79 aggregates ("World", "Euro area") into
            // the country list, marked with region "Aggregates".
            .filter { dto in
                guard let region = dto.region.value, !region.isEmpty else { return false }
                return region != Self.aggregateRegion
            }
            // `$0` is the implicit first argument — Kotlin's `it`.
            .map { $0.toDomain(population: populationByCode[$0.id]) }
            .sorted { $0.name < $1.name }
    }

    /// One generic request helper.
    ///
    /// `as: Row.Type` passes a *type* as a runtime value — the price of Swift
    /// not having Kotlin's `reified` generics. In Kotlin you write
    /// `decodeRows<CountryDTO>(json)`; here you pass `CountryDTO.self`.
    private func fetch<Row: Decodable>(
        path: String,
        query: [String: String],
        as: Row.Type
    ) async throws -> [Row] {
        var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }

        // The modern async URLSession API: no completion handler, no callback
        // pyramid. It suspends, returns, and is cancellation-aware.
        let (data, response) = try await session.data(from: components.url!)

        // `as?` is a conditional downcast returning an Optional — the same
        // operator as Kotlin's `as?`.
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CountryDataError.badStatus(http.statusCode)
        }

        do {
            return try JSONDecoder()
                .decode(WorldBankResponse<Row>.self, from: data)
                .rows
        } catch {
            // `error` is bound implicitly inside `catch` — no `catch (e)`.
            // Wrapping means callers handle one error type instead of three.
            throw CountryDataError.decodingFailed(String(describing: error))
        }
    }

    /// `static` members live on the type; `Self` (capital S) refers to the
    /// enclosing type. Kotlin's `companion object` fills the same role.
    private static let aggregateRegion = "Aggregates"
}
