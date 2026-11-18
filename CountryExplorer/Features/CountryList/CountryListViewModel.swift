import Foundation
import Observation

/// ## The view model
///
/// Same responsibilities as the Android `CountryListViewModel`: hold screen
/// state, expose intent-named methods, keep logic out of the view.
///
/// Note what is *missing* next to Android: no `ViewModel` base class to
/// inherit, no `viewModelScope`, no factory. iOS has no configuration-change
/// recreation, so nothing needs to survive it — the object simply lives as long
/// as the view does.
///
/// `@Observable` + `@MainActor` is the whole recipe:
///   - `@Observable` makes property reads trackable, so SwiftUI re-renders only
///     the views that read what changed;
///   - `@MainActor` guarantees every method runs on the main thread, making
///     state mutation inside an async function provably safe.
@MainActor
@Observable
final class CountryListViewModel {

    /// ## Modelling state as an enum
    ///
    /// Loading, loaded and failed are mutually exclusive, so an enum says so in
    /// the type system. "Loading AND failed" is not merely avoided — it is
    /// unrepresentable.
    ///
    /// The Android version uses a struct of flags (`isLoading`, `errorMessage`)
    /// because Kotlin sealed classes are heavier to declare and `combine` wants
    /// a single value. This version is the stricter design, and a good example
    /// of how Swift's cheap enums change what you reach for.
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var loadState: LoadState = .loading

    /// These are plain `var`s because the view *binds* to them with `$`.
    /// A SwiftUI binding is two-way: the search field writes straight back here.
    ///
    /// Compose has no two-way binding at all — there you pass `value` down and
    /// an `onValueChange` lambda up, by hand, every time. Swift's binding is
    /// less ceremony; Compose's explicitness makes the data flow impossible to
    /// misread. Worth forming your own opinion once you've used both.
    var query: String = ""
    var favoritesOnly: Bool = false

    private let repository: CountryRepository

    init(repository: CountryRepository) {
        self.repository = repository
    }

    /// Derived state as a computed property.
    ///
    /// No `combine`, no operator chain, no subscription: it reads
    /// `repository.countries`, `query` and `favoritesOnly`, and Observation
    /// records those reads. Change any one and the view re-renders.
    var visibleCountries: [Country] {
        repository.countries.filter { country in
            // `localizedCaseInsensitiveContains` rather than
            // `lowercased().contains()`: it handles accents and non-Latin
            // scripts correctly. Hand-rolled lowercasing silently breaks for a
            // lot of the world's users.
            let matchesQuery = query.isEmpty
                || country.name.localizedCaseInsensitiveContains(query)
                || (country.capital?.localizedCaseInsensitiveContains(query) ?? false)
            let matchesFavorites = !favoritesOnly || country.isFavorite
            return matchesQuery && matchesFavorites
        }
    }

    enum EmptyReason {
        case noFavorites
        case noSearchResults
    }

    /// Why the list is empty, or nil if it isn't. Returning an enum rather than
    /// a bool means the view cannot forget to distinguish the two cases.
    var isEmptyForReason: EmptyReason? {
        guard loadState == .loaded, visibleCountries.isEmpty else { return nil }
        return favoritesOnly ? .noFavorites : .noSearchResults
    }

    // MARK: - Intents

    /// Called from the view's `.task { }`. Async, and never throws outward — a
    /// view model's job is to turn errors into presentable state.
    func load() async {
        loadState = .loading
        await performLoad()
    }

    func retry() async {
        await performLoad()
    }

    /// Pull-to-refresh. Deliberately does NOT reset to `.loading`, so the list
    /// stays on screen while the spinner runs instead of flashing empty.
    func refresh() async {
        await performLoad()
    }

    func toggleFavorite(_ country: Country) {
        repository.setFavorite(country.code, isFavorite: !country.isFavorite)
    }

    private func performLoad() async {
        do {
            try await repository.refresh()
            loadState = .loaded
        } catch is CancellationError {
            // A cancelled load is not a failure — the user just left the
            // screen. Showing an error here would be a bug, and forgetting
            // this case is one of the most common SwiftUI mistakes.
            return
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}
