import SwiftUI

/// Loads one visit photo at the size it's displayed. The unavailable state matters:
/// feed photos name a file that only exists on the server, and without it a failed load
/// spins forever.
struct PhotoView: View {
    let photo: Visit.Photo
    let store: PhotoStore
    /// Side in points. Also the decode size, converted to device pixels below.
    let side: CGFloat
    var corner: CGFloat = 12

    @Environment(\.displayScale) private var scale
    @State private var phase: Phase = .loading

    private enum Phase {
        case loading, unavailable
        case loaded(UIImage)
    }

    var body: some View {
        Group {
            switch phase {
            case .loaded(let image):
                Image(uiImage: image).resizable().scaledToFill()
            case .loading:
                ProgressView()
            case .unavailable:
                VStack(spacing: 4) {
                    Image(systemName: photo.isLocal ? "photo.badge.exclamationmark" : "icloud.slash")
                    Text(photo.isLocal ? "Unavailable" : "On server").font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        // The size lives here rather than on the caller: spreading to infinity and
        // being clamped afterwards makes SwiftUI propose a zero-height frame mid-layout,
        // which UIKit logs as a failed image slot.
        .frame(width: side, height: side)
        .background(.quaternary)
        .clipShape(.rect(cornerRadius: corner))
        .accessibilityLabel(photo.isLocal
            ? "Photo taken \(photo.at.formatted(date: .omitted, time: .shortened))"
            : "Photo stored on the server, not downloaded")
        // `.task(id:)` cancels the decode if the tile scrolls away.
        .task(id: photo.id) {
            guard photo.isLocal else { return phase = .unavailable }
            phase = await store.image(id: photo.id, maxPixel: side * scale)
                .map(Phase.loaded) ?? .unavailable
        }
    }
}
