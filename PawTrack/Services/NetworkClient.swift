import Foundation
import OSLog

protocol NetworkClient: Sendable {
    func fetchVisits() async throws -> [Visit]
    func fetchPets() async throws -> [Pet]
}

enum NetworkError: LocalizedError, Equatable {
    case offline
    case unavailable

    var errorDescription: String? {
        switch self {
        case .offline: "No connection."
        case .unavailable: "Couldn't reach the schedule."
        }
    }

    var hint: String { "Your saved visits are still here. Pull down to try again." }
}

/// Reads the bundled JSON as if it were an API.
struct MockNetworkClient: NetworkClient {
    private enum Resource {
        static let visits = "visits"
        static let pets = "pets"
    }

    var latency: Duration = .milliseconds(400)
    var bundle: Bundle = .main

    func fetchVisits() async throws -> [Visit] {
        Wire.visits(from: try await load(Resource.visits))
    }

    func fetchPets() async throws -> [Pet] {
        decode([Pet].self, from: try await load(Resource.pets))
    }

    private func load(_ name: String) async throws -> Data {
        try await Task.sleep(for: latency)
        try Task.checkCancellation()  // a cancelled pull-to-refresh unwinds here

        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw NetworkError.unavailable
        }
        return try await Task.detached(priority: .utility) { try Data(contentsOf: url) }.value
    }
}

struct FailingNetworkClient: NetworkClient {
    var error: any Error = NetworkError.offline

    func fetchVisits() async throws -> [Visit] { throw error }
    func fetchPets() async throws -> [Pet] { throw error }
}

// MARK: - Decoding

/// Never throws, so one bad element doesn't fail the array. Catching around a plain
/// `decode` doesn't work: the container won't advance past an element that threw.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: any Decoder) throws { value = try? Value(from: decoder) }
}

private func decode<T: Decodable>(_ type: [T].Type, from data: Data) -> [T] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return (try? decoder.decode([Lossy<T>].self, from: data))?.compactMap(\.value) ?? []
}

/// The feed's shape, kept private so it can't leak into the views.
private enum Wire {

    struct VisitJSON: Decodable {
        let id: String
        let petName: String?
        let petType: String?
        let ownerName: String?
        let address: String?
        let scheduledWindow: Window?
        let status: String?
        let notes: String?
        let photos: [String]?
        let specialInstructions: String?

        struct Window: Decodable {
            let start: Date?
            let end: Date?
        }
    }

    static func visits(from data: Data) -> [Visit] {
        var seen = Set<String>()

        return decode([VisitJSON].self, from: data).compactMap { json -> Visit? in
            // v_003 appears twice. First wins: there's no updatedAt to arbitrate with,
            // and "first" is stable across refreshes where "last" lets field order decide.
            guard seen.insert(json.id).inserted else {
                Logger.feed.warning("Duplicate \(json.id, privacy: .public), kept the first")
                return nil
            }

            let start = json.scheduledWindow?.start
            var end = json.scheduledWindow?.end
            if let e = end, let s = start, e <= s {
                // v_006 ends before it starts. Guessing which end was the typo would put
                // a fabricated time on a service record, so keep only the start.
                Logger.feed.warning("\(json.id, privacy: .public) ends before it starts")
                end = nil
            }

            return Visit(
                id: json.id,
                petName: json.petName?.cleaned,
                petType: json.petType?.cleaned ?? "pet",
                ownerName: json.ownerName?.cleaned ?? "Unknown owner",
                address: json.address?.cleaned,
                start: start,
                end: end,
                notes: json.notes?.cleaned,
                specialInstructions: json.specialInstructions?.cleaned,
                // `.distantPast`, not `.now`: a fresh timestamp every fetch would let a
                // server photo out-rank the sitter's latest capture.
                photos: (json.photos ?? []).map {
                    Visit.Photo(id: $0, at: start ?? .distantPast, isLocal: false)
                },
                // A missing status defaults to upcoming; an unrecognised one becomes
                // `.unknown`, which is inert rather than advanceable.
                status: json.status.map(VisitStatus.init(rawValue:)) ?? .upcoming
            )
        }
        // Unscheduled last, then by id so the order is stable.
        .sorted { ($0.start ?? .distantFuture, $0.id) < ($1.start ?? .distantFuture, $1.id) }
    }
}

private extension String {
    /// Blank feed values (v_005's address) become genuinely absent.
    var cleaned: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Logger {
    static let feed = Logger(subsystem: "com.pawtrack.app", category: "feed")
}
