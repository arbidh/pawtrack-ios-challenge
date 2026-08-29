import ImageIO
import UIKit

/// Saves visit photos to disk and loads them back at display size. Replaces the
/// starter's `ImageLoader` — see DECISIONS.md.
///
/// `@unchecked Sendable`: `NSCache` isn't marked `Sendable` but is thread-safe, and both
/// stored properties are `let`.
final class PhotoStore: @unchecked Sendable {
    /// Long edge kept for a stored capture. Proof of service doesn't need more, and
    /// every byte eventually crosses a client's unreliable Wi-Fi.
    private static let maxStoredEdge: CGFloat = 1600
    private static let jpegQuality: CGFloat = 0.8
    private static let cachedThumbnails = 50
    /// Count alone doesn't bound memory — a hero-sized thumbnail is far larger than a
    /// tile, so the cache is capped by decoded bytes as well.
    private static let cacheBytes = 32 * 1024 * 1024

    private let directory: URL
    private let cache = NSCache<NSString, UIImage>()

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "PawTrack/Photos")) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
        cache.countLimit = Self.cachedThumbnails
        cache.totalCostLimit = Self.cacheBytes
    }

}

// MARK: - Reading and writing

extension PhotoStore {

    /// Shrinks before saving — a raw capture is several megabytes and proof of service
    /// doesn't need that.
    func save(_ image: UIImage, id: String) async throws {
        let url = directory.appending(path: id)
        try await Task.detached(priority: .userInitiated) {
            guard let data = Self.resized(image, max: Self.maxStoredEdge).jpegData(compressionQuality: Self.jpegQuality) else {
                throw PhotoError.unreadable
            }
            try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        }.value
    }

    func delete(id: String) async {
        let url = directory.appending(path: id)
        await Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: url)
        }.value
        // Thumbnails are keyed by size, so there's no single entry to evict.
        cache.removeAllObjects()
    }

    /// `nil` only when the file is genuinely unreadable, which the UI shows as a
    /// placeholder rather than an endless spinner.
    func image(id: String, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(id)@\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let url = directory.appending(path: id)
        let image = await Task.detached(priority: .userInitiated) {
            Self.downsample(at: url, maxPixel: maxPixel)
        }.value

        if let image { cache.setObject(image, forKey: key, cost: image.decodedBytes) }
        return image
    }

}

// MARK: - Downsampling

private extension PhotoStore {

    /// Not `byPreparingThumbnail(ofSize:)`: it returns nil when the requested aspect
    /// ratio doesn't match the source, which left every tile stuck loading.
    static func downsample(at url: URL, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // honour EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            .map(UIImage.init(cgImage:))
    }

    /// Scales down only. Drawing into a renderer also flattens EXIF orientation.
    static func resized(_ image: UIImage, max maxDimension: CGFloat) -> UIImage {
        let longest = Swift.max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let size = CGSize(width: (image.size.width * scale).rounded(),
                          height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

enum PhotoError: LocalizedError {
    case unreadable
    var errorDescription: String? { "That image couldn't be saved." }
}

private extension UIImage {
    /// Rough decoded size, so `totalCostLimit` means something.
    var decodedBytes: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
