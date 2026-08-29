import Foundation
import OSLog

/// The local copy of the schedule, so the app opens to the sitter's day with no network.
///
/// A `Codable` snapshot rather than SwiftData or Core Data: one sitter's day, read whole
/// and written whole, with no relational queries to gain from. See DECISIONS.md.
/// An `actor` so writes serialise: `.atomic` prevents a torn file but not two
/// concurrent renames landing out of order, which could persist an older snapshot over
/// a newer one.
actor VisitCache {
    private let fileURL: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "PawTrack")) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appending(path: "visits.json")
    }

    func load() -> [Visit] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }  // first launch
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // A corrupt cache is never fatal — the network can rebuild it.
        return (try? decoder.decode([Visit].self, from: data)) ?? []
    }

    func save(_ visits: [Visit]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            // `.atomic` keeps the last good snapshot if we crash mid-write; file
            // protection keeps client addresses encrypted on a locked device.
            try encoder.encode(visits)
                .write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            Logger.feed.error("Couldn't save visits: \(error.localizedDescription)")
        }
    }
}
