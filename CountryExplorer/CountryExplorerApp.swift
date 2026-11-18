import SwiftUI
import SwiftData

/// ## The app entry point
///
/// `@main` marks the type the OS launches — the counterpart of `MainActivity`
/// plus the launcher `<intent-filter>` in AndroidManifest.xml, compressed into
/// one attribute with no XML anywhere.
///
/// Note what is absent next to Android: no Activity, no manifest, no lifecycle
/// callbacks to override. A SwiftUI app is a `Scene` tree and the system drives
/// it.
@main
struct CountryExplorerApp: App {

    /// The SwiftData stack, created once for the app's lifetime.
    ///
    /// `ModelContainer` owns the store file; `mainContext` is the
    /// `@MainActor`-bound context we read and write through. Room's equivalent
    /// pair is `RoomDatabase` and its DAOs.
    private let modelContainer: ModelContainer

    /// Our hand-rolled dependency container — deliberately not a framework.
    /// Building it by hand once teaches what Hilt (Android) or a DI library
    /// would be automating.
    @State private var repository: CountryRepository

    init() {
        do {
            // The schema lists every @Model type. Adding a model later and
            // forgetting to list it here is a silent "my data isn't saving" bug.
            let container = try ModelContainer(for: FavoriteCountry.self)
            modelContainer = container

            // `MainActor.assumeIsolated` tells the compiler "this really is the
            // main thread" — true inside an App's init, but not something it
            // can prove. Without this, touching the @MainActor-isolated
            // FavoritesStore here is a build error.
            //
            // Swift 6 strict concurrency in action: the compiler will not take
            // your word for thread safety unless you say so explicitly, at one
            // auditable point.
            let repository = MainActor.assumeIsolated {
                CountryRepository(
                    remoteDataSource: WorldBankAPIClient(),
                    favoritesStore: FavoritesStore(context: container.mainContext)
                )
            }
            _repository = State(initialValue: repository)
        } catch {
            // If the local store cannot be opened there is no sensible degraded
            // mode — fail loudly rather than shipping an app that silently
            // loses every favourite.
            fatalError("Could not create the SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            // `NavigationStack` is the navigation host — Compose's `NavHost`.
            //
            // `.navigationDestination(for:)` maps a *value type* to a screen.
            // Pushing is then `NavigationLink(value: someString)` anywhere
            // below, with no reference to the destination view. That is the
            // same decoupling Android's typed routes give you, reached through
            // the type system instead of a route table.
            NavigationStack {
                CountryListView(repository: repository)
                    .navigationDestination(for: String.self) { countryCode in
                        CountryDetailView(
                            repository: repository,
                            countryCode: countryCode
                        )
                    }
            }
        }
        // Makes the container available to any view that wants to query
        // SwiftData directly with @Query. We don't use that here — the
        // repository owns persistence — but wiring it is conventional.
        .modelContainer(modelContainer)
    }
}
