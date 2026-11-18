import Testing
import Foundation
@testable import CountryExplorer

/// ## Test doubles without a mocking framework
///
/// Same philosophy as the Android repo: small hand-written fakes rather than a
/// mocking library. They read like real code, and the compiler keeps them
/// honest when a protocol changes.
///
/// Both fakes exist only because the production code depends on *protocols*
/// (`CountryRemoteDataSource`, `FavoritesStoring`) — the payoff of those seams.

/// A network layer we fully control.
///
/// `@unchecked Sendable` is a promise to the compiler that we have handled
/// thread safety ourselves. It is needed because `CountryRemoteDataSource` is
/// `Sendable` while this fake holds mutable state. In a test, access is
/// effectively serialised, so the promise holds — but note that Swift made us
/// state it deliberately rather than letting it slide.
final class FakeRemoteDataSource: CountryRemoteDataSource, @unchecked Sendable {
    private var countries: [Country]
    private var error: (any Error)?
    private(set) var fetchCount = 0

    init(countries: [Country] = []) {
        self.countries = countries
    }

    func succeed(with countries: [Country]) {
        self.countries = countries
        self.error = nil
    }

    func fail(with error: any Error) {
        self.error = error
    }

    func fetchCountries() async throws -> [Country] {
        fetchCount += 1
        if let error { throw error }
        return countries
    }
}

/// An in-memory stand-in for SwiftData.
@MainActor
final class FakeFavoritesStore: FavoritesStoring {
    private var codes: Set<String> = []

    func favoriteCodes() -> Set<String> { codes }

    func setFavorite(_ code: String, isFavorite: Bool) {
        if isFavorite { codes.insert(code) } else { codes.remove(code) }
    }
}

private func makeCountry(
    code: String = "JPN",
    alpha2: String = "JP",
    name: String = "Japan",
    capital: String? = "Tokyo",
    population: Int? = 123_366_734
) -> Country {
    Country(
        code: code, alpha2: alpha2, name: name, capital: capital,
        region: "East Asia & Pacific", incomeLevel: "High income",
        latitude: 35.67, longitude: 139.77, population: population
    )
}

/// `@MainActor` on the suite because the view model and repository are
/// main-actor isolated.
///
/// Note how much less setup this needs than the Android equivalent: no
/// `Dispatchers.setMain`, no test dispatcher, no `runTest`, no Turbine. Swift's
/// async testing runs the real concurrency machinery and `@MainActor` pins it.
@MainActor
struct CountryListViewModelTests {

    private func makeViewModel(remote: FakeRemoteDataSource) -> CountryListViewModel {
        let repository = CountryRepository(
            remoteDataSource: remote,
            favoritesStore: FakeFavoritesStore()
        )
        return CountryListViewModel(repository: repository)
    }

    @Test("Loads countries on first appearance")
    func loadsCountries() async {
        let remote = FakeRemoteDataSource(countries: [makeCountry(name: "Japan")])
        let viewModel = makeViewModel(remote: remote)

        // No stream to collect: `await load()` returns when the work is done
        // and the state is simply there to read. This is the clearest
        // ergonomic win Swift concurrency has over Flow + Turbine.
        await viewModel.load()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.visibleCountries.map(\.name) == ["Japan"])
        #expect(remote.fetchCount == 1)
    }

    @Test("Surfaces an error message when the network fails")
    func surfacesError() async {
        let remote = FakeRemoteDataSource()
        remote.fail(with: CountryDataError.badStatus(503))
        let viewModel = makeViewModel(remote: remote)

        await viewModel.load()

        // Pattern matching on an enum with an associated value. `guard case`
        // is the idiom for "extract this case or bail".
        guard case .failed(let message) = viewModel.loadState else {
            Issue.record("Expected .failed, got \(viewModel.loadState)")
            return
        }
        #expect(message.contains("503"))
    }

    @Test("Search filters by name and capital, case-insensitively")
    func searchFilters() async {
        let remote = FakeRemoteDataSource(countries: [
            makeCountry(code: "JPN", alpha2: "JP", name: "Japan", capital: "Tokyo"),
            makeCountry(code: "IND", alpha2: "IN", name: "India", capital: "New Delhi"),
            makeCountry(code: "KEN", alpha2: "KE", name: "Kenya", capital: "Nairobi"),
        ])
        let viewModel = makeViewModel(remote: remote)
        await viewModel.load()

        viewModel.query = "jap"
        #expect(viewModel.visibleCountries.map(\.name) == ["Japan"])

        // Matching a CAPITAL, not just a name — the behaviour a refactor would
        // quietly break, so it is worth pinning down.
        viewModel.query = "nairobi"
        #expect(viewModel.visibleCountries.map(\.name) == ["Kenya"])

        viewModel.query = ""
        #expect(viewModel.visibleCountries.count == 3)
    }

    @Test("Toggling a favourite updates the list and the favourites filter")
    func togglesFavorite() async throws {
        let remote = FakeRemoteDataSource(countries: [
            makeCountry(code: "JPN", alpha2: "JP", name: "Japan"),
            makeCountry(code: "IND", alpha2: "IN", name: "India"),
        ])
        let viewModel = makeViewModel(remote: remote)
        await viewModel.load()

        #expect(viewModel.visibleCountries.allSatisfy { !$0.isFavorite })

        let japan = try #require(viewModel.visibleCountries.first { $0.code == "JPN" })
        viewModel.toggleFavorite(japan)

        // The end-to-end assertion that matters: the write goes to the (fake)
        // store, the repository re-merges, and the derived list reflects it.
        #expect(viewModel.visibleCountries.filter(\.isFavorite).map(\.code) == ["JPN"])

        viewModel.favoritesOnly = true
        #expect(viewModel.visibleCountries.map(\.name) == ["Japan"])
    }

    @Test("Retry refetches after a failure")
    func retryRefetches() async {
        let remote = FakeRemoteDataSource()
        remote.fail(with: CountryDataError.badStatus(500))
        let viewModel = makeViewModel(remote: remote)

        await viewModel.load()
        #expect(viewModel.loadState != .loaded)

        remote.succeed(with: [makeCountry(name: "Japan")])
        await viewModel.retry()

        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.visibleCountries.map(\.name) == ["Japan"])
        #expect(remote.fetchCount == 2)   // initial failure + retry
    }
}
