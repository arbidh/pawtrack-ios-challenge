import Foundation
import Testing
import UIKit
@testable import PawTrack

@MainActor
@Suite("List view model")
struct VisitListViewModelTests {

    private struct Stub: NetworkClient {
        func fetchVisits() async throws -> [Visit] {
            [Visit(id: "a", petName: "Rex", petType: "dog", ownerName: "Owner",
                   address: "1 Main St", status: .upcoming)]
        }
        func fetchPets() async throws -> [Pet] { [] }
    }

    @Test("A check-in survives a relaunch with no network")
    func persistsAcrossRelaunch() async throws {
        // Its own temp directory, so the test doesn't share the app's cache file.
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        func model(_ network: any NetworkClient) -> VisitListViewModel {
            VisitListViewModel(network: network, cache: VisitCache(directory: directory),
                               photos: PhotoStore(directory: directory))
        }

        let first = model(Stub())
        await first.load()
        try await first.advance("a")
        #expect(first.visit("a")?.status == .enRoute)

        // A fresh model over the same cache, offline, is a relaunch in a dead zone.
        let relaunched = model(FailingNetworkClient())
        await relaunched.load()
        #expect(relaunched.visit("a")?.status == .enRoute)
        #expect(relaunched.loadError != nil)
    }

    @Test("Filter and search compose; counts ignore the filter")
    func filtering() async {
        let model = VisitListViewModel(
            network: TwoVisits(),
            cache: VisitCache(directory: URL.temporaryDirectory.appending(path: UUID().uuidString)),
            photos: PhotoStore(directory: URL.temporaryDirectory)
        )
        await model.load()

        model.filter.status = .completed
        #expect(model.filtered.map(\.id) == ["b"])

        model.filter.search = "maple"
        #expect(model.filtered.isEmpty, "Completed AND matching 'maple' is nothing")

        model.filter.status = nil
        #expect(model.filtered.map(\.id) == ["a"])
        #expect(model.count(nil) == 2, "Counts come from the unfiltered set")
    }

    private struct TwoVisits: NetworkClient {
        func fetchVisits() async throws -> [Visit] {
            [Visit(id: "a", petName: "Rex", petType: "dog", ownerName: "O",
                   address: "1 Maple Court", status: .upcoming),
             Visit(id: "b", petName: "Ada", petType: "cat", ownerName: "O2",
                   address: "2 Elm Street", status: .completed)]
        }
        func fetchPets() async throws -> [Pet] { [] }
    }

    @Test("Deleting a photo removes the reference and the file")
    func deletePhoto() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let photos = PhotoStore(directory: directory)
        let model = VisitListViewModel(
            network: Stub(), cache: VisitCache(directory: directory), photos: photos
        )
        await model.load()

        try await model.addPhoto(.swatch, to: "a")
        let photoID = try #require(model.visit("a")?.photos.first?.id)
        #expect(await photos.image(id: photoID, maxPixel: 40) != nil)

        await model.removePhoto(photoID, from: "a")
        #expect(model.visit("a")?.photos.isEmpty == true)
        #expect(await photos.image(id: photoID, maxPixel: 40) == nil, "The file is gone too")
    }
}

private extension UIImage {
    /// Smallest thing that survives a JPEG round-trip.
    static var swatch: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}
