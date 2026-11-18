import SwiftUI

/// The three states every data-loading screen must handle: busy, broken, empty.
/// Factoring them out once means no screen can forget one.
///
/// ## What a SwiftUI `View` is
///
/// A `struct` conforming to `View`, with a `body` that returns a description of
/// the UI. SwiftUI recreates these structs constantly — they are cheap values,
/// not objects with lifecycles. Treat `body` as a pure function of the view's
/// properties, exactly as you would a React function component.
///
/// The difference from Compose: a `@Composable` is a *function* that emits UI
/// and returns nothing, while a SwiftUI `View` is a *type* whose body returns a
/// value. That is why SwiftUI can diff by comparing structs, and why Compose
/// instead tracks reads of observable state.
struct LoadingStateView: View {
    var body: some View {
        // `some View` is an opaque return type: "one specific View type, which
        // I am not going to spell out". The compiler knows it exactly; you are
        // spared writing the (often absurd) nested generic type by hand.
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void      // a closure property = a callback prop

    var body: some View {
        // ContentUnavailableView is the system-standard error/empty
        // presentation. Using it instead of a hand-built VStack makes your app
        // match Mail, Photos and Settings for free — and inherit their
        // accessibility and Dynamic Type behaviour.
        ContentUnavailableView {
            Label("Could not load countries", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
    }
}

/// `#Preview` renders a view in Xcode's canvas without running the app — the
/// closest thing to Storybook, built into the IDE. It is also the practical
/// argument for small, parameter-driven views: each can be previewed in
/// isolation, in every state, in light and dark mode.
#Preview("Error") {
    ErrorStateView(message: "The Internet connection appears to be offline.") {}
}

#Preview("Empty") {
    EmptyStateView(
        title: "No favourites yet",
        systemImage: "heart",
        message: "Tap the heart on any country to add it here."
    )
}
