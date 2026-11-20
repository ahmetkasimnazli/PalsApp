import SwiftUI
import UIKit

/// System camera for taking a single photo. Falls back to the photo library
/// where there's no camera (e.g. the Simulator).
struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    static var hasCamera: Bool {
        #if targetEnvironment(simulator)
        // The Simulator's camera is a placeholder that can't take photos.
        false
        #else
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = Self.hasCamera ? .camera : .photoLibrary
        if Self.hasCamera { picker.cameraDevice = .front }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPick(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
