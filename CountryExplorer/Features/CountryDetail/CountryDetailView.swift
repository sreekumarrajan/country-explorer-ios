import SwiftUI

struct CountryDetailView: View {
    @State private var viewModel: CountryDetailViewModel

    init(repository: CountryRepository, countryCode: String) {
        _viewModel = State(
            initialValue: CountryDetailViewModel(
                repository: repository,
                countryCode: countryCode
            )
        )
    }

    var body: some View {
        Group {
            // `if let` inside a view builder. Swift has no
            // ternary-soup-in-JSX problem: this is ordinary control flow.
            if let country = viewModel.country {
                detail(for: country)
            } else {
                LoadingStateView()
            }
        }
        .navigationTitle(viewModel.country?.name ?? "")
        // `.inline` puts the title in the bar rather than as a large header —
        // the convention for a pushed detail screen.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let country = viewModel.country {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.toggleFavorite()
                    } label: {
                        Image(systemName: country.isFavorite ? "heart.fill" : "heart")
                    }
                    .accessibilityLabel(
                        country.isFavorite ? "Remove from favourites"
                                           : "Add to favourites"
                    )
                }
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    /// A function returning a view rather than a computed property, because it
    /// takes a parameter. `some View` works the same either way.
    private func detail(for country: Country) -> some View {
        // `Form` gives you the inset-grouped look of the Settings app,
        // including spacing, separators and dark mode — free.
        Form {
            Section {
                // The Spacers centre the flag in the row.
                //
                // Worth understanding rather than copying: a SwiftUI view is
                // offered a size by its parent and chooses its own within it.
                // `.aspectRatio(.fit)` makes the image narrower than the row,
                // and a lone child sits at its natural width — left-aligned
                // here, because that is a `Form` row's default alignment.
                // Spacers are greedy, so one on each side splits the slack
                // evenly and the image lands in the middle.
                //
                // Compose solves the same problem differently:
                // `horizontalArrangement = Arrangement.Center` on the Row,
                // i.e. you configure the parent rather than padding the
                // children. SwiftUI leans on filler views, Compose on layout
                // parameters.
                HStack {
                    Spacer()
                    AsyncImage(url: country.flagImageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.gray.opacity(0.1)
                    }
                    .frame(height: 140)
                    // Clip the IMAGE, not the whole row — otherwise the
                    // rounded corners are applied to the full-width container
                    // and you see a rounded white box around the flag.
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }

            Section {
                FactRow(label: "Capital", value: country.capital ?? "—")
                FactRow(label: "Region", value: country.region)
                FactRow(label: "Income level", value: country.incomeLevel)
                FactRow(
                    label: "Population",
                    // `map` on an Optional transforms the value if present.
                    // Kotlin spells this `?.let { ... } ?: "—"`.
                    value: country.population.map(formatPopulation) ?? "—"
                )
                FactRow(label: "ISO codes", value: "\(country.alpha2) · \(country.code)")
                FactRow(label: "Coordinates", value: coordinates(for: country))
            }
        }
    }

    private func coordinates(for country: Country) -> String {
        guard let latitude = country.latitude, let longitude = country.longitude else {
            return "—"
        }
        // `%.2f` is the same printf syntax you know from C, Java and Kotlin.
        return String(format: "%.2f, %.2f", latitude, longitude)
    }
}

/// A tiny view, extracted purely for readability. Creating views is free in
/// SwiftUI — they are structs, not objects with lifecycles — so there is no
/// cost to naming every small piece.
private struct FactRow: View {
    let label: String
    let value: String

    var body: some View {
        // LabeledContent handles label/value alignment and reads to VoiceOver
        // as a single "label, value" unit.
        LabeledContent(label, value: value)
    }
}
