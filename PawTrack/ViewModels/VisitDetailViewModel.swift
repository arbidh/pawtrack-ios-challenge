import AVFoundation
import Observation
import UIKit

/// What the detail screen needs from whoever owns the schedule.
///
/// Declared here, by the consumer, so the detail model depends on an interface rather
/// than on `VisitListViewModel` — and so it can be tested against a stub. It's
/// deliberately narrower than the list model: five members instead of everything.
@MainActor
protocol VisitProviding: AnyObject {
    var photos: PhotoStore { get }
    func visit(_ id: String) -> Visit?
    func pet(named name: String?) -> Pet?
    func advance(_ id: String) async throws
    func addPhoto(_ image: UIImage, to id: String) async throws
    func removePhoto(_ photoID: String, from id: String) async
}

/// Drives one visit's detail screen.
@MainActor
@Observable
final class VisitDetailViewModel {

    /// One optional enum rather than a `Bool` per sheet, so two can't present at once.
    enum Sheet: String, Identifiable {
        case camera, cameraDenied
        var id: String { rawValue }
    }

    let visitID: String
    var sheet: Sheet?
    var errorMessage: String?
    private(set) var isSaving = false

    private let store: any VisitProviding

    init(visitID: String, store: any VisitProviding) {
        self.visitID = visitID
        self.store = store
    }
}

// MARK: - Derived state

extension VisitDetailViewModel {

    var visit: Visit? { store.visit(visitID) }
    var pet: Pet? { store.pet(named: visit?.petName) }
    var photoStore: PhotoStore { store.photos }

    /// The owner asked for photo proof and none has been taken.
    var needsPhotoProof: Bool {
        guard let visit else { return false }
        return visit.photos.isEmpty
            && visit.specialInstructions?.localizedCaseInsensitiveContains("photo") == true
    }
}

// MARK: - Actions

extension VisitDetailViewModel {

    func advance() async {
        do { try await store.advance(visitID) }
        catch { errorMessage = error.localizedDescription }
    }

    /// Deletes both the reference and the file. Only offered for photos actually held
    /// on this device — a server-side one isn't ours to remove.
    func remove(_ photoID: String) async {
        await store.removePhoto(photoID, from: visitID)
    }

    func add(_ image: UIImage) async {
        isSaving = true
        defer { isSaving = false }
        do { try await store.addPhoto(image, to: visitID) }
        catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - Camera permission

extension VisitDetailViewModel {

    /// The Simulator has none; the library path still works.
    ///
    /// Resolved once per process: `AVCaptureDevice.default(for:)` performs device
    /// discovery, and this is read on every render of the photos section. Hardware
    /// can't appear mid-session, so caching it is safe and keeps AVFoundation from
    /// logging a capture error each time SwiftUI re-evaluates the body.
    var hasCamera: Bool { Self.deviceHasCamera }

    private static let deviceHasCamera = AVCaptureDevice.default(for: .video) != nil

    /// iOS prompts once per install, so after a denial Settings is the only way back
    /// and the app has to say so rather than leaving a dead button.
    func startCamera() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sheet = .camera
        case .notDetermined:
            sheet = await AVCaptureDevice.requestAccess(for: .video) ? .camera : .cameraDenied
        default:
            sheet = .cameraDenied
        }
    }
}
