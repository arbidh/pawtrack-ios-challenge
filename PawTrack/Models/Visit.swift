import Foundation

/// One assignment on the schedule. `petName` and `address` stay optional because the
/// feed sends them null or blank, and `""` would render as a convincing blank row.
struct Visit: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var petName: String?
    var petType: String
    var ownerName: String
    var address: String?
    var start: Date?
    /// Only set when it's after `start`; `v_006` ends before it begins.
    var end: Date?
    var notes: String?
    var specialInstructions: String?
    var photos: [Photo] = []
    private(set) var status: VisitStatus
    private(set) var history: [Change] = []

    struct Change: Hashable, Codable, Sendable {
        let status: VisitStatus
        let at: Date
    }

    struct Photo: Identifiable, Hashable, Codable, Sendable {
        let id: String
        let at: Date
        /// Feed photos name a file that only exists on the server.
        let isLocal: Bool
    }

    enum TransitionError: LocalizedError, Equatable {
        case outOfOrder(VisitStatus, VisitStatus)
        case alreadyFinished(VisitStatus)

        var errorDescription: String? {
            switch self {
            case .outOfOrder(let from, let to):
                "A visit can't go from \(from.title.lowercased()) to \(to.title.lowercased())."
            case .alreadyFinished(let status):
                "This visit is already \(status.title.lowercased())."
            }
        }
    }

    /// On the model, not in a button's `isEnabled`, so a stale view can't bypass it.
    mutating func advance(to new: VisitStatus, at date: Date) throws {
        guard let allowed = status.next else { throw TransitionError.alreadyFinished(status) }
        guard new == allowed else { throw TransitionError.outOfOrder(status, new) }
        status = new
        history.append(Change(status: new, at: date))
    }

    /// A refresh must never walk a checked-in visit back to `upcoming`. `cancelled` is
    /// the exception: it's the office's call and arrives with no history.
    func keepingProgress(of local: Visit) -> Visit {
        guard status != .cancelled, local.history.count > history.count else { return self }
        var copy = self
        copy.status = local.status
        copy.history = local.history
        return copy
    }

    /// `v_004` has no pet name, so fall back to the owner.
    var displayName: String { petName ?? "\(ownerName)'s \(petType)" }

    var scheduleText: String {
        guard let start else { return "No time set" }
        let from = start.formatted(date: .omitted, time: .shortened)
        guard let end else { return "From \(from)" }
        return "\(from) – \(end.formatted(date: .omitted, time: .shortened))"
    }
}

/// Care profile. No entry exists for the rabbit at `v_004`, so lookups are optional.
struct Pet: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let breed: String
    let age: Int
    let weight: Int
    let temperament: String
    let feedingInstructions: String
    let vetContact: String

    var needsCare: Bool { temperament == "anxious" || temperament == "shy" }
}
