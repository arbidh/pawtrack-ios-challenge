import PhotosUI
import SwiftUI

struct VisitDetailView: View {
    @State private var model: VisitDetailViewModel
    @State private var libraryItem: PhotosPickerItem?
    @State private var showLibrary = false
    /// Set when the denial sheet asks for the library; acted on once it has dismissed.
    @State private var libraryAfterDismiss = false
    /// Set from a context menu; the confirmation reads it.
    @State private var photoPendingDeletion: String?

    init(model: VisitDetailViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model

        return content
            .navigationTitle(model.visit?.displayName ?? "Visit")
            .navigationBarTitleDisplayMode(.inline)
            // Presenting the picker while the sheet is still dismissing usually drops it.
            .sheet(item: $model.sheet, onDismiss: presentLibraryIfRequested, content: sheet)
            .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .images)
            .task(id: libraryItem) { await addFromLibrary() }
            .alert("Couldn't do that", isPresented: hasError, presenting: model.errorMessage) { _ in
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: { Text($0) }
            // Deleting proof of service is worth one confirmation.
            .confirmationDialog(
                "Delete this photo?",
                isPresented: .init(
                    get: { photoPendingDeletion != nil },
                    set: { if !$0 { photoPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let id = photoPendingDeletion else { return }
                    photoPendingDeletion = nil
                    Task { await model.remove(id) }
                }
                Button("Cancel", role: .cancel) { photoPendingDeletion = nil }
            } message: {
                Text("It will be removed from this visit and deleted from the device.")
            }
    }

    @ViewBuilder
    private var content: some View {
        if let visit = model.visit {
            List {
                VisitSections.LatestPhoto(visit: visit, store: model.photoStore) {
                    photoPendingDeletion = $0
                }
                VisitSections.Summary(visit: visit)
                VisitSections.Progress(visit: visit) { await model.advance() }
                VisitSections.Photos(visit: visit, model: model) {
                    showLibrary = true
                } onDelete: {
                    photoPendingDeletion = $0
                }
                VisitSections.Care(pet: model.pet)
                VisitSections.Instructions(visit: visit)
            }
            .listStyle(.insetGrouped)
        } else {
            // A refresh dropped the visit while it was open.
            ContentUnavailableView("Visit unavailable", systemImage: "questionmark.folder")
        }
    }
}

// MARK: - Photo capture

private extension VisitDetailView {

    @ViewBuilder
    func sheet(_ sheet: VisitDetailViewModel.Sheet) -> some View {
        switch sheet {
        case .camera:
            CameraPicker { image in
                model.sheet = nil
                if let image { Task { await model.add(image) } }
            }
            .ignoresSafeArea()
        case .cameraDenied:
            CameraDeniedView { libraryAfterDismiss = true; model.sheet = nil }
        }
    }

    func presentLibraryIfRequested() {
        guard libraryAfterDismiss else { return }
        libraryAfterDismiss = false
        showLibrary = true
    }

    func addFromLibrary() async {
        guard let item = libraryItem else { return }
        defer { libraryItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            model.errorMessage = PhotoError.unreadable.localizedDescription
            return
        }
        await model.add(image)
    }

    var hasError: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}
