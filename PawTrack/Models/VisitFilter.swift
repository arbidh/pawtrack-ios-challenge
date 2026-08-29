import Foundation

/// What the sitter has narrowed the list to. A value type rather than two properties on
/// the view model: filtering is a rule about visits, testable without a view model, and
/// keeping it here leaves the view model responsible only for owning the schedule.
struct VisitFilter: Equatable {
    var search = ""
    var status: VisitStatus?

    var isActive: Bool { status != nil || !query.isEmpty }

    private var query: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func apply(to visits: [Visit]) -> [Visit] {
        visits.filter { visit in
            guard status == nil || visit.status == status else { return false }
            guard !query.isEmpty else { return true }
            // Owner included: it's the only way to find the pet with no name.
            return [visit.petName, visit.address, visit.ownerName, visit.petType]
                .contains { $0?.localizedCaseInsensitiveContains(query) == true }
        }
    }
}

extension Array where Element == Visit {
    /// Reconciles a fetch with what's already on the device.
    ///
    /// The office owns the descriptive fields, but the sitter's progress and any photo
    /// they captured win — a refresh must never undo work done on the road.
    func merging(local: [Visit]) -> [Visit] {
        let byID = Dictionary(local.map { ($0.id, $0) }) { first, _ in first }
        return map { incoming in
            guard let mine = byID[incoming.id] else { return incoming }
            var merged = incoming.keepingProgress(of: mine)
            merged.photos += mine.photos.filter { photo in
                !merged.photos.contains { $0.id == photo.id }
            }
            return merged
        }
    }
}
