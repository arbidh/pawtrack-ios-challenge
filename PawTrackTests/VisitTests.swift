import Foundation
import Testing
@testable import PawTrack

/// The transition rule is the core invariant: a sitter must not be able to mark a visit
/// complete without having checked in.
@Suite("Transitions")
struct VisitTests {

    private func visit(_ status: VisitStatus) -> Visit {
        Visit(id: "v_1", petType: "dog", ownerName: "Owner", status: status)
    }

    @Test("Transitions are sequential: no skipping, no going back, no restarting")
    func sequential() {
        var upcoming = visit(.upcoming)
        #expect(throws: Visit.TransitionError.outOfOrder(.upcoming, .completed)) {
            try upcoming.advance(to: .completed, at: .now)
        }
        #expect(upcoming.status == .upcoming, "A rejected transition leaves the visit untouched")
        #expect(upcoming.history.isEmpty)

        var inProgress = visit(.inProgress)
        #expect(throws: Visit.TransitionError.outOfOrder(.inProgress, .upcoming)) {
            try inProgress.advance(to: .upcoming, at: .now)
        }

        for status in [VisitStatus.completed, .cancelled] {
            var finished = visit(status)
            #expect(throws: Visit.TransitionError.alreadyFinished(status)) {
                try finished.advance(to: .upcoming, at: .now)
            }
        }
    }

    @Test("Each step records its own timestamp")
    func timestamps() throws {
        var v = visit(.upcoming)
        let times = [1_000, 2_000, 3_000].map(Date.init(timeIntervalSince1970:))

        try v.advance(to: .enRoute, at: times[0])
        try v.advance(to: .inProgress, at: times[1])
        try v.advance(to: .completed, at: times[2])

        #expect(v.status == .completed)
        #expect(v.history.map(\.status) == [.enRoute, .inProgress, .completed])
        #expect(v.history.map(\.at) == times)
    }

    @Test("A refresh can't walk a locally-advanced visit backwards")
    func mergeKeepsProgress() throws {
        var mine = visit(.upcoming)
        try mine.advance(to: .enRoute, at: .now)

        var fromServer = visit(.upcoming)      // the server hasn't heard yet
        fromServer.address = "999 New Road"    // but it did correct the address

        let merged = fromServer.keepingProgress(of: mine)
        #expect(merged.status == .enRoute, "The sitter's progress wins")
        #expect(merged.address == "999 New Road", "The office still owns descriptive fields")

        // ...but a cancellation is the office's call, even mid-visit. Otherwise the
        // sitter keeps driving to a visit that was called off.
        let cancelled = visit(.cancelled).keepingProgress(of: mine)
        #expect(cancelled.status == .cancelled)
    }

    @Test("An unrecognised status is inert, not silently advanceable")
    func unknownStatus() {
        let status = VisitStatus(rawValue: "awaiting_key_handoff")
        #expect(status == .unknown("awaiting_key_handoff"))
        #expect(status.next == nil, "Never offer an action for a state we can't reason about")
        #expect(status.rawValue == "awaiting_key_handoff", "Round-trips through the cache")
        #expect(status.title == "Awaiting Key Handoff")

        var visit = Visit(id: "v", petType: "dog", ownerName: "O", status: status)
        #expect(throws: Visit.TransitionError.alreadyFinished(status)) {
            try visit.advance(to: .enRoute, at: .now)
        }
    }
}
