import Foundation

/// The app's own model of a country — the shape the UI wants, not the shape any
/// API happens to return.
///
/// ## `struct`, not `class`
///
/// This is the biggest mental shift from both TypeScript and Kotlin. A struct is
/// a **value type**: assigning it copies it, and there is no shared reference
/// anyone else can mutate behind your back.
///
///     var a = country
///     var b = a            // b is a COPY
///     b.isFavorite = true  // a is untouched
///
/// SwiftUI depends on this. It re-renders by comparing old and new values, and
/// values cannot change underneath it. Reach for `class` only when you need
/// shared identity or state observed in place (the view models do).
///
/// Kotlin's `data class` is the rough counterpart, but it is still a *reference*
/// type — there, `copy()` is an explicit call. Here, copying is simply what
/// assignment means.
struct Country: Identifiable, Hashable, Sendable {
    let code: String        // ISO 3166-1 alpha-3 ("JPN") — our stable identity
    let alpha2: String      // ISO 3166-1 alpha-2 ("JP")  — for flags
    let name: String
    let capital: String?    // optional: a few territories have no capital
    let region: String
    let incomeLevel: String
    let latitude: Double?
    let longitude: Double?
    let population: Int?    // optional: the World Bank lacks data for a few
    var isFavorite: Bool = false

    /// `Identifiable` requires `id`. SwiftUI's `List` and `ForEach` use it the
    /// way React uses `key` — to track items across updates. Satisfying the
    /// protocol with a computed property means no extra stored field.
    var id: String { code }

    /// A computed property: recalculated on each read, stores nothing.
    /// Equivalent to a TS getter, or Kotlin's `val x get() = ...`.
    var flagImageURL: URL? {
        URL(string: "https://flagcdn.com/w320/\(alpha2.lowercased()).png")
    }

    /// Turns "JP" into 🇯🇵. Flag emoji are two "regional indicator symbols",
    /// which live at Unicode 0x1F1E6 ('A') through 0x1F1FF ('Z').
    ///
    /// Compare the Kotlin version in the Android repo: same algorithm, but
    /// Swift's `Unicode.Scalar` is a first-class type, whereas Kotlin drops to
    /// `Character.toChars` returning a raw `CharArray`. Swift treats text as
    /// Unicode scalars by default; Kotlin's `Char` is a UTF-16 code unit, which
    /// is why an emoji needs two of them there and one scalar here.
    var flagEmoji: String {
        let letters = Array(alpha2.uppercased().unicodeScalars)
        guard letters.count == 2,
              letters.allSatisfy({ ("A"..."Z").contains(Character($0)) })
        else {
            return "🏳️"
        }
        // `compactMap` = map + drop nils — Kotlin's mapNotNull.
        return String(
            letters.compactMap { Unicode.Scalar(0x1F1E6 + $0.value - 65) }
                .map { Character($0) }
        )
    }
}
