import Observation
import UIKit

/// Owns the schedule and drives the list. Rewritten from the starter's version, which
/// had a retain cycle, an uninvalidated `Timer` and an off-main-actor data race — see
/// DECISIONS.md.
@MainActor
@Observable
final class VisitListViewModel {

    private(set) var visits: [Visit] = []
    private(set) var isLoading = false
    /// The view decides whether this is a note over cached rows or a full error screen.
    private(set) var loadError: (any Error)?
    /// False until the first load finishes, so the empty state can't flash on launch.
    private(set) var hasLoaded = false

    /// Held here, not in the view, so it survives a push to detail and back.
    var filter = VisitFilter()

    let photos: PhotoStore

    private var pets: [String: Pet] = [:]
    private let network: any NetworkClient
    private let cache: VisitCache

    init(
        network: any NetworkClient = MockNetworkClient(),
        cache: VisitCache = VisitCache(),
        photos: PhotoStore = PhotoStore()
    ) {
        self.network = network
        self.cache = cache
        self.photos = photos
    }
}

// MARK: - Loading

extension VisitListViewModel {

    /// Cache first so the app is usable immediately, then refresh. Driven by `.task`,
    /// so SwiftUI owns cancellation.
    func load() async {
        if visits.isEmpty { visits = await cache.load() }
        await refresh()
        hasLoaded = true
    }

    func refresh() async {
        guard !isLoading else { return }  // pull-to-refresh can fire mid-load
        isLoading = true
        defer { isLoading = false }

        do {
            async let incoming = network.fetchVisits()
            async let profiles = network.fetchPets()

            let fetched = try await incoming
            // Profiles are decoration; losing them shouldn't discard a good schedule.
            pets = (try? await profiles).map { list in
                Dictionary(list.map { ($0.name.lowercased(), $0) }) { first, _ in first }
            } ?? [:]

            visits = fetched.merging(local: visits)
            loadError = nil
            await cache.save(visits)
        } catch is CancellationError {
            // Deliberately silent. The screen went away mid-pull, so there's nobody to
            // show an error to and nothing to retry — leaving `loadError` unset is the
            // point, otherwise a swipe-back would surface a spurious failure banner.
        } catch {
            loadError = error
        }
    }

}

// MARK: - Derived state

extension VisitListViewModel {

    /// One value, so the view doesn't have to get the precedence right.
    enum State {
        case loading
        case loaded
        case empty
        case failed(any Error)

        /// `any Error` isn't `Equatable`, so animations key off this instead.
        var id: String {
            switch self {
            case .loading: "loading"
            case .loaded: "loaded"
            case .empty: "empty"
            case .failed: "failed"
            }
        }
    }

    var state: State {
        if !visits.isEmpty { .loaded }
        else if isLoading || !hasLoaded { .loading }
        else if let loadError { .failed(loadError) }
        else { .empty }
    }

    var filtered: [Visit] { filter.apply(to: visits) }

    /// Counts come from the unfiltered set, so they don't shift as you filter.
    func count(_ status: VisitStatus?) -> Int {
        status.map { s in visits.count { $0.status == s } } ?? visits.count
    }

    func has(_ status: VisitStatus) -> Bool { visits.contains { $0.status == status } }

    /// The mock schedule isn't today, so state the day rather than assume it.
    var scheduleDay: String {
        visits.compactMap(\.start).min()?
            .formatted(.dateTime.weekday(.wide).month().day()) ?? ""
    }

    func visit(_ id: String) -> Visit? { visits.first { $0.id == id } }

    func pet(named name: String?) -> Pet? { name.flatMap { pets[$0.lowercased()] } }
}

// MARK: - VisitProviding

/// Mutations are applied locally and saved immediately.
extension VisitListViewModel: VisitProviding {

    func advance(_ id: String) async throws {
        try await update(id) { visit in
            guard let next = visit.status.next else { return }
            try visit.advance(to: next, at: .now)
        }
    }

    func addPhoto(_ image: UIImage, to id: String) async throws {
        guard visits.contains(where: { $0.id == id }) else { return }
        let photoID = "\(id)_\(UUID().uuidString).jpg"
        try await photos.save(image, id: photoID)
        await update(id) { $0.photos.append(Visit.Photo(id: photoID, at: .now, isLocal: true)) }
    }

    func removePhoto(_ photoID: String, from id: String) async {
        await update(id) { $0.photos.removeAll { $0.id == photoID } }
        await photos.delete(id: photoID)
    }

    /// Finds the visit, applies the change, persists. Looking it up *after* any await
    /// matters: `@MainActor` is re-entrant, so a refresh may have replaced `visits`
    /// while a write was in flight, and an index taken earlier could point elsewhere.
    private func update(_ id: String, _ change: (inout Visit) throws -> Void) async rethrows {
        guard let index = visits.firstIndex(where: { $0.id == id }) else { return }
        try change(&visits[index])
        await cache.save(visits)
    }
}
