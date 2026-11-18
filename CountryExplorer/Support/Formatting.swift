import Foundation

/// A top-level function — no enclosing type required, same as Kotlin.
///
/// `.formatted()` respects the user's locale, so an Indian user sees
/// 12,33,66,734 and a US user sees 123,366,734. Never hand-roll thousands
/// separators.
func formatPopulation(_ value: Int) -> String {
    value.formatted(.number.grouping(.automatic))
}
