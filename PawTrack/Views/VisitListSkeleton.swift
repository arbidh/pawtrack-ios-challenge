import SwiftUI

/// The loading state, shaped like the list it's about to become.
///
/// A bare spinner says "wait" and nothing else, and then the schedule lands and shoves
/// the screen around. These are real `VisitRow`s over placeholder data, redacted — so the
/// skeleton holds the final geometry and can't drift from the layout it stands in for,
/// including the stacked variant at accessibility text sizes.
struct VisitListSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        List {
            Section {
                ForEach(Self.rows) { visit in
                    VisitRow(visit: visit).cardRow()
                }
            } header: {
                chips
                    .textCase(nil)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .scrollDisabled(true)
        .redacted(reason: .placeholder)
        // A slow pulse rather than a sweeping gradient: it reads as "working" in both
        // colour schemes, without a highlight colour that only looks right in one.
        .opacity(dimmed ? 0.55 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                   value: dimmed)
        .onAppear { dimmed = true }
        // One announcement for the whole screen. Swiping VoiceOver through four rows of
        // blanked-out text would be worse than the spinner this replaces.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading today's visits")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Chip-shaped blanks, so the filter header doesn't pop in after the rows do.
    private var chips: some View {
        HStack(spacing: 8) {
            ForEach([44, 72, 64, 58], id: \.self) { width in
                Capsule()
                    .fill(.quaternary)
                    .frame(width: CGFloat(width), height: 30)
            }
        }
        .padding(.horizontal, Metrics.margin)
    }

    /// Varied name and address lengths — four identical rows read as a rendering bug
    /// rather than as loading.
    private static let rows: [Visit] = {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let sample = [("Bella", "12 Alder Street"),
                      ("Marmalade", "4 Priory Gardens, Flat 2"),
                      ("Nugget", "88 Fenwick Road"),
                      ("Juniper", "7 Old Mill Lane")]
        return sample.enumerated().map { index, row in
            Visit(id: "placeholder_\(index)", petName: row.0, petType: "dog",
                  ownerName: "—", address: row.1,
                  start: start, end: start.addingTimeInterval(3600),
                  status: .upcoming)
        }
    }()
}
