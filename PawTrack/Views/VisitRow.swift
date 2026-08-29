import SwiftUI

/// One assignment. At normal text sizes it reads as a timetable — time in a leading
/// column, a status-coloured rail, then the details — because a sitter scans this list
/// to answer "where am I going next", and the times need to line up.
///
/// At accessibility sizes that column would take most of the width and squeeze the pet
/// name out entirely, so the row stacks instead.
struct VisitRow: View {
    let visit: Visit

    @Environment(\.dynamicTypeSize) private var typeSize
    /// Grows the time column with the user's text size, up to the point where the
    /// stacked layout takes over.
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth = Metrics.timeColumn

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { stacked } else { timetable }
        }
        .padding(Metrics.cardPadding)
        .contentShape(.rect)
        // One sentence for VoiceOver instead of five fragments. The dash is spoken as
        // "to" because "9:00 – 10:00" is otherwise read as a subtraction.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the visit")
        .accessibilityAddTraits(.isButton)
    }

    private var timetable: some View {
        HStack(alignment: .top, spacing: 12) {
            time.frame(width: timeWidth, alignment: .trailing)
            Capsule().fill(visit.status.tint).frame(width: Metrics.railWidth)
            details
        }
    }

    /// No rail and no side-by-side pairs: at these sizes every element needs the full
    /// width, and the status badge already carries the colour the rail was showing.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: 8) {
            time
            name
            StatusBadge(status: visit.status, compact: true)
            address
            photoCountLabel
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                name
                Spacer(minLength: 6)
                StatusBadge(status: visit.status, compact: true)
            }
            address
            photoCountLabel
        }
    }

    private var address: some View {
        Text(visit.address ?? "No address on file")
            .font(.subheadline)
            .foregroundStyle(visit.address == nil ? .tertiary : .secondary)
            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
    }

    @ViewBuilder
    private var photoCountLabel: some View {
        if !visit.photos.isEmpty {
            Text(photoCount).font(.caption).foregroundStyle(.tertiary)
        }
    }

    private var name: some View {
        Text(visit.displayName)
            .font(.headline)
            // A name derived from the owner is secondary, so it doesn't pose as the
            // pet's real name.
            .foregroundStyle(visit.petName == nil ? .secondary : .primary)
            // The owner-derived fallback for `v_004` is long. Two lines with a little
            // scaling keeps it whole without truncating to "Tom Whitf…" or hyphenating
            // mid-word, and the card grows to fit.
            .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var time: some View {
        if let start = visit.start {
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                Text(start.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .lineLimit(1)
                if let end = visit.end {
                    Text(end.formatted(date: .omitted, time: .shortened))
                        .font(.caption).foregroundStyle(.tertiary).monospacedDigit()
                }
            }
        } else {
            // `v_007` has no window at all.
            Text("No time set").font(.subheadline.weight(.semibold)).foregroundStyle(.tertiary)
        }
    }

    private var photoCount: String {
        "\(visit.photos.count) photo\(visit.photos.count == 1 ? "" : "s")"
    }

    private var accessibilityLabel: String {
        var parts = [visit.displayName, visit.address ?? "no address on file"]
        parts.append(visit.scheduleText.replacingOccurrences(of: "–", with: "to"))
        parts.append(visit.status.title)
        if !visit.photos.isEmpty { parts.append(photoCount) }
        return parts.joined(separator: ", ")
    }
}
