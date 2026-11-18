import Foundation
import Observation

/// The detail screen's view model.
///
/// Note what it does *not* take: a `Country`. It receives only a code and reads
/// the country from the repository.
///
/// Passing the whole struct would be easier and immediately wrong: structs are
/// copies, so favouriting here would update a copy while the list kept showing
/// the original. Reading both screens from one source means they cannot
/// disagree.
///
/// The same rule holds on Android for a different reason (a stale snapshot
/// stored in a navigation argument). One lesson, two distinct failure modes.
@MainActor
@Observable
final class CountryDetailViewModel {

    private let repository: CountryRepository
    private let countryCode: String

    init(repository: CountryRepository, countryCode: String) {
        self.repository = repository
        self.countryCode = countryCode
    }

    /// Always a fresh read, so a favourite toggle shows immediately.
    var country: Country? {
        repository.country(code: countryCode)
    }

    /// Covers the cold-start case: if the app was launched straight onto this
    /// screen (a deep link, or a restored scene), the cache is empty.
    func loadIfNeeded() async {
        try? await repository.refreshIfEmpty()
    }

    func toggleFavorite() {
        // `guard let country` with no `= country` is Swift 5.7+ shorthand for
        // `guard let country = country`: it shadows the optional with a
        // non-optional of the same name.
        guard let country else { return }
        repository.setFavorite(country.code, isFavorite: !country.isFavorite)
    }
}
