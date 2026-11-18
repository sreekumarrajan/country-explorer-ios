import SwiftUI

/// ## The list screen
struct CountryListView: View {

    /// `@State` owns the view model and keeps it alive across the many times
    /// SwiftUI recreates this struct.
    ///
    /// This is the most confusing part for newcomers, so to be precise:
    /// `CountryListView` itself is a throwaway value, rebuilt on every render.
    /// `@State` storage is NOT thrown away — SwiftUI keeps it outside the
    /// struct, keyed by the view's position in the hierarchy.
    ///
    /// With an `@Observable` class, `@State` is the correct wrapper for
    /// ownership; it supersedes the older `@StateObject`/`@ObservedObject` pair
    /// you will still see in most tutorials.
    @State private var viewModel: CountryListViewModel

    /// A custom `init` is needed because the view model requires the
    /// repository. Assigning to a `@State` property here uses the underscore
    /// form: `_viewModel` is the wrapper itself, not its wrapped value.
    init(repository: CountryRepository) {
        _viewModel = State(initialValue: CountryListViewModel(repository: repository))
    }

    var body: some View {
        content
            .navigationTitle("Country Explorer")
            // `.searchable` gives you the system search field, with its
            // scroll-to-reveal behaviour, cancel button, keyboard handling and
            // accessibility included. One modifier. On Android you assemble the
            // equivalent yourself from a TextField and your own layout.
            .searchable(text: $viewModel.query, prompt: "Search countries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $viewModel.favoritesOnly) {
                        Label("Favourites only", systemImage: "heart")
                    }
                    .toggleStyle(.button)
                }
            }
            // `.task` runs an async job when the view appears and — crucially —
            // CANCELS it when the view disappears. That cancellation is why
            // `performLoad` handles `CancellationError`.
            //
            // Compose's counterpart is `LaunchedEffect(Unit) { }` and React's
            // is `useEffect(fn, [])`, but neither cancels in-flight work for
            // you automatically.
            .task {
                await viewModel.load()
            }
            // Pull-to-refresh in one modifier. The spinner stays up until this
            // async function returns, so the gesture feels correct with no
            // manual state wiring at all.
            .refreshable {
                await viewModel.refresh()
            }
    }

    /// Splitting `body` into computed properties is idiomatic: it keeps each
    /// piece readable and stops Swift's type-checker from crawling on deeply
    /// nested view builders.
    ///
    /// `@ViewBuilder` is what allows a `switch` here, with each branch
    /// returning a different view type.
    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            LoadingStateView()

        case .failed(let message):
            ErrorStateView(message: message) {
                // `Task { }` bridges from a synchronous closure into async work
                // — the equivalent of calling an async function without
                // awaiting in JS, but scoped and cancellable.
                Task { await viewModel.retry() }
            }

        case .loaded:
            if let reason = viewModel.isEmptyForReason {
                switch reason {
                case .noFavorites:
                    EmptyStateView(
                        title: "No favourites yet",
                        systemImage: "heart",
                        message: "Tap the heart on any country to add it here."
                    )
                case .noSearchResults:
                    EmptyStateView(
                        title: "No matches",
                        systemImage: "magnifyingglass",
                        message: "No countries match “\(viewModel.query)”."
                    )
                }
            } else {
                countryList
            }
        }
    }

    private var countryList: some View {
        // `List` is already lazy — it builds only the rows on screen, like
        // Compose's `LazyColumn`. There is no non-lazy trap to fall into here,
        // which is one fewer performance mistake available to you.
        List(viewModel.visibleCountries) { country in
            // `NavigationLink(value:)` pushes a *value*, not a view. The
            // destination is resolved by `.navigationDestination` up in
            // CountryExplorerApp.
            //
            // That indirection is what makes deep links and state restoration
            // work: the navigation path becomes an array of values you can save
            // and restore, rather than a stack of live view objects.
            NavigationLink(value: country.code) {
                CountryRow(country: country) {
                    viewModel.toggleFavorite(country)
                }
            }
        }
        .listStyle(.plain)
        // Because the array is Equatable and each element is Identifiable,
        // insertions and removals animate automatically when the filter
        // changes. The id plays the same role as `key` in Compose's `items(...)`
        // and in React.
        .animation(.default, value: viewModel.visibleCountries)
    }
}
