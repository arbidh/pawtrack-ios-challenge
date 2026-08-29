import SwiftUI
import UIKit

/// Camera capture. UIKit because SwiftUI still has no native camera control, and
/// adopting AVFoundation for one JPEG isn't a good trade.
struct CameraPicker: UIViewControllerRepresentable {
    /// `nil` means the sitter cancelled.
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {
        // Keep the closure current so a capture never reaches a stale view model.
        context.coordinator.onFinish = onFinish
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onFinish(nil) }
    }
}

/// iOS prompts once per install, so after a denial Settings is the only way back. It also
/// offers the library, so a denied camera never blocks proof of service.
struct CameraDeniedView: View {
    let onUseLibrary: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ContentUnavailableView {
            Label("Camera access is off", systemImage: "camera.fill")
        } description: {
            Text("PawTrack needs the camera to capture proof of service. You can turn it back on in Settings.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)

            Button("Choose an Existing Photo", action: onUseLibrary)
        }
        .presentationDetents([.medium])
    }
}
