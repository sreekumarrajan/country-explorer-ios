import Foundation
import Observation

/// The repository is the view models' single source of truth. It decides where
/// data comes from, so no screen has to care: countries from the network,
/// favourites from the database, merged into one array the UI renders.
///
/// ## `@Observable` — SwiftUI's reactivity, and the deepest divergence from Android
///
/// This macro makes stored properties observable. Any SwiftUI view that *reads*
/// `countries` re-renders when it changes; a view reading only some other
/// property does not. The tracking is per-property and automatic.
///
/// The Android repo achieves the same result with explicit streams:
/// `MutableStateFlow` + `combine` + `collectAsStateWithLifecycle`. Here there is
/// no stream at all — you mutate a property and the UI follows.
///
/// Worth sitting with, because it is the biggest philosophical difference
/// between the two stacks:
///
///   - Kotlin Flow is *explicit and composable*: a stream is a value you can
///     debounce, retry, flatMap and test. The cost is ceremony.
///   - Swift Observation is *implicit and ergonomic*: almost no ceremony, but
///     "what causes this to update?" is answered by the compiler rather than by
///     code you can point at.
///
/// Both are unidirectional data flow. Only the plumbing differs.
@MainActor
@Observable
final class CountryRepository {

    /// `private(set)` is "readable everywhere, writable only in here" —
    /// Kotlin's `var x: T private set`. The UI can read but never corrupt it.
    private(set) var countries: [Country] = []

    private let remoteDataSource: any CountryRemoteDataSource
    private let favoritesStore: any FavoritesStoring

    /// Raw network results, kept separate from the merged `countries`, so
    /// toggling a favourite never requires a refetch.
    private var rawCountries: [Country] = []
    private var favoriteCodes: Set<String> = []

    /// `any` before a protocol means "some value conforming to this, decided at
    /// runtime" (an existential). Swift makes the dynamic dispatch visible in
    /// the type; Kotlin interface types are always like this implicitly.
    init(
        remoteDataSource: any CountryRemoteDataSource,
        favoritesStore: any FavoritesStoring
    ) {
        self.remoteDataSource = remoteDataSource
        self.favoritesStore = favoritesStore
        self.favoriteCodes = favoritesStore.favoriteCodes()
    }

    /// Hit the network and replace the cache. `throws` on failure so callers
    /// decide how to present it — a data layer should not invent UI copy.
    func refresh() async throws {
        rawCountries = try await remoteDataSource.fetchCountries()
        merge()
    }

    /// Load only if we have nothing yet (used when a screen appears).
    func refreshIfEmpty() async throws {
        guard rawCountries.isEmpty else { return }
        try await refresh()
    }

    func country(code: String) -> Country? {
        countries.first { $0.code == code }
    }

    /// Writes one row, then re-merges.
    ///
    /// Compare Android, where the write lands in SQLite and Room's Flow
    /// re-emits automatically. Here the merge is an explicit call: Observation
    /// tells the *UI* that `countries` changed, but nothing tells *us* that the
    /// database changed. Slightly more code — and a good reminder of what
    /// Room's reactive queries were doing for free.
    func setFavorite(_ code: String, isFavorite: Bool) {
        favoritesStore.setFavorite(code, isFavorite: isFavorite)
        favoriteCodes = favoritesStore.favoriteCodes()
        merge()
    }

    /// The single place where network data and local favourites become one list.
    private func merge() {
        countries = rawCountries.map { country in
            // Structs are value types, so this copies and mutates the copy —
            // no chance of editing the cached original by accident.
            var copy = country
            // Set membership is O(1). An Array here would mean ~217 × 217
            // comparisons every time anything changed.
            copy.isFavorite = favoriteCodes.contains(country.code)
            return copy
        }
    }
}
