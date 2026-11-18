import Foundation
import SwiftData

/// ## SwiftData: the local database
///
/// `@Model` is a *macro*. At compile time it rewrites this class to be
/// persistable and observable, generating storage, change tracking and schema.
/// Macros are Swift's answer to annotation processors — the Android repo's Room
/// `@Entity` plus KSP codegen does the same job. The difference is that you can
/// read the expansion here (right-click → Expand Macro in Xcode), whereas
/// Room's generated code hides in a build folder.
///
/// It must be a `class`: a database row has identity, and SwiftData tracks
/// changes to it in place. This is the one place a reference type is clearly
/// correct.
@Model
final class FavoriteCountry {
    /// The primary-key constraint — Room's `@PrimaryKey`. With `.unique`,
    /// inserting an existing code updates that row instead of adding a second.
    @Attribute(.unique) var countryCode: String

    init(countryCode: String) {
        self.countryCode = countryCode
    }
}

/// ## `@MainActor`: the concept with no Kotlin equivalent
///
/// This is a compile-time guarantee that every member runs on the main thread.
/// Android enforces the same rule *at runtime* — touch a View off the main
/// thread and you get a CalledFromWrongThreadException in production. Swift
/// turns that whole class of bug into a build error.
///
/// It is on the protocol rather than just the class because `ModelContext` is
/// not `Sendable`: confining it here lets the compiler prove no other task can
/// reach it.
@MainActor
protocol FavoritesStoring {
    func favoriteCodes() -> Set<String>
    func setFavorite(_ code: String, isFavorite: Bool)
}

/// Wraps SwiftData so the rest of the app never imports it — which keeps the
/// persistence choice swappable and the repository testable.
@MainActor
final class FavoritesStore: FavoritesStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func favoriteCodes() -> Set<String> {
        // `FetchDescriptor` is a type-safe query. Compare Room, where you write
        // real SQL in a @Query annotation that the compiler verifies at build
        // time. Two defensible designs: Room gives you SQL's full power with
        // build-time checking; SwiftData gives you Swift predicates and no SQL.
        let descriptor = FetchDescriptor<FavoriteCountry>()

        // `try?` turns a throwing call into an Optional. Right here: an
        // unreadable favourites table should degrade to "no favourites" rather
        // than take down the screen.
        let rows = (try? context.fetch(descriptor)) ?? []

        // `\.countryCode` is a *key path* — a reference to the property itself,
        // not its value. `map(\.countryCode)` is shorthand for
        // `map { $0.countryCode }`. Kotlin has no direct equivalent.
        return Set(rows.map(\.countryCode))
    }

    func setFavorite(_ code: String, isFavorite: Bool) {
        if isFavorite {
            context.insert(FavoriteCountry(countryCode: code))
        } else {
            let descriptor = FetchDescriptor<FavoriteCountry>(
                // `#Predicate` is another macro: it compiles this Swift closure
                // into a query the store executes, rather than loading every
                // row and filtering in memory.
                predicate: #Predicate { $0.countryCode == code }
            )
            for row in (try? context.fetch(descriptor)) ?? [] {
                context.delete(row)
            }
        }
        // SwiftData autosaves, but saving explicitly makes a failed write
        // visible rather than silent — worth it for a user-initiated action.
        try? context.save()
    }
}
