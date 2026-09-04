import SwiftUI

/// Visit lifecycle. Replaces the starter's `status: String`, where a typo like
/// `"en-route"` compiled and silently matched nothing.
///
/// `unknown` exists because the office can add a status this build has never heard of.
/// Coercing one to `upcoming` would be worse than useless: it would hand the sitter a
/// *Start driving* button for a visit whose real state we can't reason about. An unknown
/// status is inert — no successor, no action — and keeps its raw value so it round-trips
/// through the cache and displays honestly.
enum VisitStatus: Codable, Sendable, Hashable {
    case upcoming
    case enRoute
    case inProgress
    case completed
    case cancelled
    case unknown(String)

    /// The only status a sitter may move to from here. One successor rather than a set
    /// of allowed edges makes skipping a step unrepresentable.
    var next: VisitStatus? {
        switch self {
        case .upcoming: .enRoute
        case .enRoute: .inProgress
        case .inProgress: .completed
        case .completed, .cancelled, .unknown: nil
        }
    }

    var title: String {
        switch self {
        case .upcoming: "Upcoming"
        case .enRoute: "En route"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        // Shown as sent, so a sitter can read it back to the office over the phone.
        case .unknown(let raw): raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Label for the button that moves a visit *into* this status.
    var actionTitle: String {
        switch self {
        case .upcoming: "Reset"
        case .enRoute: "Start driving"
        case .inProgress: "Check in"
        case .completed: "Check out"
        case .cancelled: "Cancel"
        case .unknown: ""
        }
    }

    var symbol: String {
        switch self {
        case .upcoming: "calendar"
        case .enRoute: "car.fill"
        case .inProgress: "figure.walk"
        case .completed: "checkmark.seal.fill"
        case .cancelled: "xmark.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .upcoming: .secondary
        case .enRoute: .orange
        case .inProgress: .blue
        case .completed: .green
        case .cancelled: .red
        case .unknown: .purple
        }
    }

    /// What to tell the sitter when there's no action to offer.
    var terminalMessage: String {
        switch self {
        case .completed: "Visit complete."
        case .cancelled: "The office cancelled this visit."
        case .unknown(let raw):
            "This visit is marked “\(raw)”, which this version of PawTrack doesn't handle. Check with the office."
        default: ""
        }
    }
}

// MARK: - Wire representation

extension VisitStatus: RawRepresentable {

    init(rawValue: String) {
        switch rawValue {
        case "upcoming": self = .upcoming
        case "en_route": self = .enRoute
        case "in_progress": self = .inProgress
        case "completed": self = .completed
        case "cancelled": self = .cancelled
        default: self = .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .upcoming: "upcoming"
        case .enRoute: "en_route"
        case .inProgress: "in_progress"
        case .completed: "completed"
        case .cancelled: "cancelled"
        case .unknown(let raw): raw
        }
    }
}

extension VisitStatus: CaseIterable {
    /// The statuses the app can filter by. `unknown` is deliberately absent: it isn't a
    /// single status, and a chip per unrecognised string would be noise.
    static let allCases: [VisitStatus] = [.upcoming, .enRoute, .inProgress, .completed, .cancelled]
}
