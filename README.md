# Country Explorer — iOS (Swift + SwiftUI)

A deliberately small app that exercises every fundamental you need for real iOS
work: networking, JSON, structured concurrency, local persistence, list/detail
navigation, state management, and unit testing.

Its twin lives at [country-explorer-android](https://github.com/sreekumarrajan/country-explorer-android)
and implements the **same requirements** with Kotlin and Jetpack Compose, so you
can read the two side by side.

---

## What it does

- Loads ~217 countries from the World Bank API (no API key required)
- Loads each country's latest population from a **second** endpoint, in parallel
- Search by country name or capital
- Tap a row for a detail screen
- Favourite countries with the heart; favourites persist via SwiftData
- "Favourites only" filter
- Loading / error / empty states, with retry and pull-to-refresh

## The data sources

| Need | Endpoint |
|---|---|
| Countries | `https://api.worldbank.org/v2/country?format=json&per_page=400` |
| Population | `https://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL?format=json&mrv=1` |
| Flag images | `https://flagcdn.com/w320/{iso2}.png` |

No signup, no API key.

> The response envelope is `[metadata, [rows]]` — a JSON array holding two
> *different* types. That is deliberate: real APIs are full of shapes no single
> `Decodable` struct describes, and `WorldBankResponse` shows how to write
> `init(from:)` by hand when `Codable`'s synthesis isn't enough.

---

## Running it

```bash
open CountryExplorer.xcodeproj     # then press ⌘R
```

From the command line:

```bash
# Unit tests
xcodebuild test -scheme CountryExplorer \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Build only
xcodebuild -scheme CountryExplorer -sdk iphonesimulator build
```

**Requirements:** Xcode 26+ and an iOS 18+ simulator runtime.

### The project file

`CountryExplorer.xcodeproj` is **generated** from `project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen). Edit `project.yml`, then:

```bash
xcodegen generate
```

Why: `project.pbxproj` is a machine-written file that produces merge conflicts
whenever two people add a file on different branches. Describing the project in
YAML keeps it readable and diffable. `project.yml` is heavily commented and maps
every setting back to the field the Xcode **New Project wizard** would have
asked you for — read it to see what the GUI writes on your behalf.

---

## How the code is organised

```
CountryExplorer/
├── CountryExplorerApp.swift     # @main entry point; builds the dependency graph
├── Domain/
│   └── Country.swift            # the model the UI wants
├── Data/
│   ├── CountryAPIClient.swift   # URLSession + async let; the envelope decoding
│   ├── WorldBankDTOs.swift      # wire shapes + mapping to domain
│   ├── FavoritesStore.swift     # SwiftData @Model and its wrapper
│   └── CountryRepository.swift  # single source of truth; merges net + db
├── Features/
│   ├── CountryList/             # list screen + its view model
│   ├── CountryDetail/           # detail screen + its view model
│   └── Components/              # reusable views
└── Support/Formatting.swift
```

The dependency rule: **Features → Data → Domain**, never backwards. A view model
imports no SwiftUI, which is what keeps it testable.

---

## Coming from Angular or React?

| You know | iOS equivalent | File to read |
|---|---|---|
| React component | `struct X: View` | `Features/Components/CountryRow.swift` |
| `useState` | `@State` | `Features/CountryList/CountryListView.swift` |
| `useEffect(fn, [])` | `.task { }` (and it auto-cancels) | `Features/CountryList/CountryListView.swift` |
| Controlled input | `$binding` (two-way) | `Features/CountryList/CountryListView.swift` |
| `key` prop | `Identifiable.id` | `Domain/Country.swift` |
| Store / context | `@Observable` class | `Data/CountryRepository.swift` |
| `Promise.all` | `async let` | `Data/CountryAPIClient.swift` |
| `fetch` + `.json()` | `URLSession` + `Codable` | `Data/CountryAPIClient.swift` |
| Angular service + DI | repository, injected via `init` | `CountryExplorerApp.swift` |
| React Router | `NavigationStack` + `.navigationDestination` | `CountryExplorerApp.swift` |
| `package.json` | `project.yml` | `project.yml` |
| Storybook | `#Preview` | `Features/Components/StateViews.swift` |

Read the files in this order:

1. `Domain/Country.swift` — structs vs classes, value semantics, optionals
2. `Data/WorldBankDTOs.swift` — Codable, custom decoding, extensions
3. `Data/CountryAPIClient.swift` — `async let`, protocols, error enums
4. `Data/FavoritesStore.swift` — SwiftData, macros, `@MainActor`
5. `Data/CountryRepository.swift` — `@Observable`, merging state
6. `Features/CountryList/CountryListViewModel.swift` — state as an enum
7. `Features/CountryList/CountryListView.swift` — SwiftUI, `@State`, modifiers
8. `CountryExplorerTests/` — Swift Testing, fakes, `@testable`

---

## Swift vs Kotlin: the differences that actually matter

**Value types.** `struct` copies on assignment. Kotlin's `data class` is a
reference type with an explicit `copy()`. This changes how you think about
mutation: in `CountryRepository.merge()` the `var copy = country` genuinely
cannot affect the cached original.

**Enums with associated values.** `LoadState.failed(String)` is one declaration.
Kotlin needs a sealed interface plus a class per case, which is why the Android
version models the same state as a struct of flags instead.

**Observation vs Flow.** SwiftUI tracks property reads automatically; Kotlin
makes streams explicit values you can `combine`, `debounce` and test. Swift's is
less ceremony, Kotlin's is more inspectable. Read `CountryRepository` in both
repos back to back — it is the clearest illustration in the project.

**`@MainActor`.** Swift proves thread-correctness at compile time. Android
enforces the same rule at runtime, with a crash. Same rule, caught earlier.

**No configuration-change recreation.** Android destroys and recreates your
screen on rotation, which is the entire reason `ViewModel` exists there. iOS has
no equivalent, so view models need no base class, no factory, no scope.

---

## Exercises

1. **Sort control.** Toggle between name and population descending.
2. **Region filter.** A `Picker` of distinct regions, derived from the data.
3. **Offline cache.** Persist countries in SwiftData and serve them when the
   network fails, so the app opens with data on a plane.
4. **Map on the detail screen.** Use MapKit with the lat/long.
5. **A decoding test for a malformed payload.** Prove `CountryDataError` is
   thrown rather than the app crashing.
6. **Widget or App Intent.** Something with no Android equivalent — a good way
   to see what the platform offers beyond the app itself.
