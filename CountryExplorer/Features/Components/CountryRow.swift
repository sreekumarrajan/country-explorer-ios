import SwiftUI

/// One row of the list.
struct CountryRow: View {
    let country: Country
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // `AsyncImage` downloads, decodes and displays — the direct
            // counterpart of Coil's `AsyncImage` on Android.
            //
            // One real difference worth knowing: AsyncImage caches only as far
            // as URLCache's defaults, while Coil caches aggressively out of the
            // box. For an image-heavy production app people reach for Nuke or
            // Kingfisher; for a flag list, the built-in is the right amount of
            // machinery.
            AsyncImage(url: country.flagImageURL) { phase in
                // The closure receives a `phase` enum — empty, success,
                // failure. Switching over it is how you control each state
                // rather than accepting a default spinner.
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Color.gray.opacity(0.2)
                case .empty:
                    Color.gray.opacity(0.1)
                @unknown default:
                    // Required because the enum may gain cases in a future SDK.
                    // Swift makes you acknowledge that possibility; Kotlin's
                    // `when` over a sealed class has the same exhaustiveness
                    // rule but no cross-version concern.
                    Color.gray.opacity(0.1)
                }
            }
            .frame(width: 48, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(country.flagEmoji)  \(country.name)")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Spacer expands to fill available space, pushing the button right.
            // Compose expresses the same idea as `Modifier.weight(1f)` on the
            // element that should absorb the slack.
            Spacer()

            Button(action: onToggleFavorite) {
                // SF Symbols are vector icons shipped with the OS — thousands
                // of them, weight-matched to the system font. No asset files
                // and no icon dependency, unlike Compose's material-icons.
                Image(systemName: country.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(country.isFavorite ? .pink : .secondary)
            }
            // Without this, tapping ANYWHERE in the row triggers the button,
            // because SwiftUI gives a Button inside a List row a full-row tap
            // style by default. A genuinely surprising default, and a bug you
            // will hit at least once.
            .buttonStyle(.plain)
            .accessibilityLabel(country.isFavorite ? "Remove from favourites"
                                                   : "Add to favourites")
        }
        .padding(.vertical, 4)
    }

    /// Splitting a sub-expression into a computed property keeps `body`
    /// readable — and it helps the type-checker, which gets slow on long
    /// chained view expressions.
    private var subtitle: String {
        var parts: [String] = [country.capital ?? country.region]
        if let population = country.population {
            parts.append(formatPopulation(population))
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    List {
        CountryRow(
            country: Country(
                code: "JPN", alpha2: "JP", name: "Japan", capital: "Tokyo",
                region: "East Asia & Pacific", incomeLevel: "High income",
                latitude: 35.67, longitude: 139.77, population: 123_366_734,
                isFavorite: true
            ),
            onToggleFavorite: {}
        )
    }
}
