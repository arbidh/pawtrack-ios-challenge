import SwiftUI

enum Metrics {
    static let cardCorner: CGFloat = 14
    static let cardPadding: CGFloat = 14
    static let rowSpacing: CGFloat = 5
    static let margin: CGFloat = 16
    static let railWidth: CGFloat = 3
    /// Wide enough for a two-digit hour with AM/PM on one line.
    static let timeColumn: CGFloat = 78
    static let heroPhoto: CGFloat = 260
    static let thumbnail: CGFloat = 78
}

extension View {
    /// A list row that carries no chrome of its own: the card is the row's background,
    /// so the disclosure chevron lands inside it.
    func cardRow() -> some View {
        listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Metrics.cardPadding,
                                      leading: Metrics.margin + Metrics.cardPadding,
                                      bottom: Metrics.cardPadding, trailing: Metrics.margin))
            .listRowBackground(
                RoundedRectangle(cornerRadius: Metrics.cardCorner)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.07), radius: 5, y: 2)
                    .padding(.horizontal, Metrics.margin)
                    .padding(.vertical, Metrics.rowSpacing)
            )
    }
}

extension View {
    /// Animates `value` changes with the app's standard motion, or not at all when the
    /// user has asked for reduced motion. Every animation in the app goes through here
    /// so there's one place to tune the feel — and one place that respects the setting.
    func animatedChange(_ value: some Equatable, reduceMotion: Bool) -> some View {
        animation(reduceMotion ? nil : .snappy(duration: 0.28), value: value)
    }
}
