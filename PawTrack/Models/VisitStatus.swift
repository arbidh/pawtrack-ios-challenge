import SwiftUI

/// Visit lifecycle. Replaces the starter's `status: String`, where a typo like
/// `"en-route"` compiled and silently matched nothing.
///
/// `cancelled` is terminal and only ever arrives from the server — `v_009` is already
/// in that state.
enum VisitStatus: String, Codable, CaseIterable, Sendable {
    case upcoming
    case enRoute = "en_route"
    case inProgress = "in_progress"
    case completed
    case cancelled

    /// The only status a sitter may move to from here. One successor rather than a set
    /// of allowed edges makes skipping a step unrepresentable.
    var next: VisitStatus? {
        switch self {
        case .upcoming: .enRoute
        case .enRoute: .inProgress
        case .inProgress: .completed
        case .completed, .cancelled: nil
        }
    }

    var title: String {
        switch self {
        case .upcoming: "Upcoming"
        case .enRoute: "En route"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
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
        }
    }

    var symbol: String {
        switch self {
        case .upcoming: "calendar"
        case .enRoute: "car.fill"
        case .inProgress: "figure.walk"
        case .completed: "checkmark.seal.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .upcoming: .secondary
        case .enRoute: .orange
        case .inProgress: .blue
        case .completed: .green
        case .cancelled: .red
        }
    }
}
