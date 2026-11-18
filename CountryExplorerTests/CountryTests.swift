import Testing
@testable import CountryExplorer

/// ## Swift Testing, not XCTest
///
/// Xcode 16 introduced the `Testing` framework: `@Test` functions and
/// `#expect(...)` macros, replacing `XCTestCase` subclasses and `XCTAssert`.
/// It is the default for new projects, so that is what we use.
///
/// `@testable import` gives the test target access to `internal` declarations
/// (Swift's default access level). Kotlin needs no equivalent because JVM test
/// sources live in the same module and see internals automatically.
struct CountryTests {

    private func country(alpha2: String) -> Country {
        Country(
            code: "XXX", alpha2: alpha2, name: "Test", capital: nil,
            region: "R", incomeLevel: "I", latitude: nil, longitude: nil,
            population: nil
        )
    }

    /// Test names are plain function names with a readable title in the
    /// attribute — nicer than Kotlin's backticked names, and they appear in
    /// Xcode's test navigator exactly as written here.
    @Test("Builds flag emoji from an ISO alpha-2 code")
    func flagEmoji() {
        // `#expect` is a macro: on failure it reports the actual values of the
        // sub-expressions, so you rarely need a custom failure message.
        #expect(country(alpha2: "JP").flagEmoji == "🇯🇵")
        #expect(country(alpha2: "IN").flagEmoji == "🇮🇳")
        #expect(country(alpha2: "ke").flagEmoji == "🇰🇪")   // lowercase works
    }

    @Test("Falls back to a neutral flag for malformed codes")
    func flagEmojiFallback() {
        #expect(country(alpha2: "").flagEmoji == "🏳️")
        #expect(country(alpha2: "X").flagEmoji == "🏳️")
        #expect(country(alpha2: "1A").flagEmoji == "🏳️")
    }

    @Test("Builds a lowercase flag image URL")
    func flagImageURL() {
        #expect(
            country(alpha2: "JP").flagImageURL?.absoluteString
                == "https://flagcdn.com/w320/jp.png"
        )
    }

    /// `arguments:` runs the same test once per value — a parameterised test
    /// with no boilerplate. JUnit needs @ParameterizedTest plus a source
    /// annotation for this.
    @Test("Every ISO code produces a two-scalar flag", arguments: ["US", "GB", "BR", "ZA"])
    func flagEmojiLength(code: String) {
        #expect(country(alpha2: code).flagEmoji.unicodeScalars.count == 2)
    }
}
