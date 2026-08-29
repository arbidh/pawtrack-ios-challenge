import Foundation
import Testing
@testable import PawTrack

/// The provided `visits.json` is dirty on purpose. Every test here fails against the
/// starter's `Visit`, whose non-optional fields made `JSONDecoder` throw on the first
/// `null` — the app could never have shown a single visit.
@Suite("Decoding the provided data")
struct VisitDecodingTests {

    private func visits() async throws -> [Visit] {
        try await MockNetworkClient(latency: .zero).fetchVisits()
    }

    @Test("Duplicates collapse; every other record survives")
    func duplicates() async throws {
        let visits = try await visits()
        // Ten records in the file; v_003 appears twice.
        #expect(visits.count == 9)
        #expect(Set(visits.map(\.id)).count == 9)
    }

    @Test("Null and blank fields become absent, not empty strings")
    func missingFields() async throws {
        let visits = try await visits()

        #expect(try #require(visits.first { $0.id == "v_005" }).address == nil)

        let rabbit = try #require(visits.first { $0.id == "v_004" })
        #expect(rabbit.petName == nil)
        #expect(rabbit.displayName == "Tom Whitfield's rabbit")
        #expect(rabbit.petType == "rabbit", "An unknown species is carried through")
    }

    @Test("Broken and missing windows are repaired rather than dropped")
    func schedules() async throws {
        let visits = try await visits()

        // v_006 ends 90 minutes before it starts: keep the start, drop the end.
        let whiskers = try #require(visits.first { $0.id == "v_006" })
        #expect(whiskers.start != nil)
        #expect(whiskers.end == nil)
        #expect(whiskers.scheduleText.hasPrefix("From "))

        // v_007 has no window at all, so it sorts last.
        let cooper = try #require(visits.first { $0.id == "v_007" })
        #expect(cooper.start == nil)
        #expect(visits.last?.id == cooper.id)
        #expect(cooper.photos.allSatisfy { !$0.isLocal }, "Feed photos have no local bytes")

        // v_009 is cancelled, which is terminal rather than a step on the path.
        #expect(try #require(visits.first { $0.id == "v_009" }).status.next == nil)
    }
}
