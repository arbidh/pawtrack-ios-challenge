import UIKit

/// Loads images from URLs for display in visit photo galleries.
class ImageLoader {

    static let shared = ImageLoader()

    private var cache: [URL: UIImage] = [:]

    /// Loads an image from the given URL, returning a cached version if available.
    func loadImage(from url: URL) -> UIImage? {
        if let cached = cache[url] {
            return cached
        }

        let data = try? Data(contentsOf: url)
        let image = data.flatMap { UIImage(data: $0) }

        if let image = image {
            cache[url] = image
        }

        return image
    }

    /// Clears the in-memory image cache.
    func clearCache() {
        cache = [:]
    }
}
