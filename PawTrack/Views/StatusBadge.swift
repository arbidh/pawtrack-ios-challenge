import SwiftUI

/// Colour-coded status pill.
///
/// The symbol isn't decoration: colour alone fails for colour vision deficiency, and
/// orange-vs-red is exactly the pair that fails. Shape and text carry the meaning.
struct StatusBadge: View {
    let status: VisitStatus
    var compact = false

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Label(status.title, systemImage: status.symbol)
            .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            .padding(.horizontal, compact ? 7 : 9)
            .padding(.vertical, compact ? 3 : 5)
            .foregroundStyle(status.tint)
            // One line normally, so a long pet name can't hyphenate the badge. At
            // accessibility sizes there's room to wrap, and truncating "Cancelled" to
            // "Cancell…" loses the meaning the badge exists to carry.
            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            .background(status.tint.opacity(0.14), in: .capsule)
            // Keeps the pill in place while its label and colour change.
            .contentTransition(.opacity)
            // Keeps the badge at its natural width so a long pet name can't squeeze
            // the title into a hyphenated two-line pill.
            .layoutPriority(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Status: \(status.title)")
    }
}
