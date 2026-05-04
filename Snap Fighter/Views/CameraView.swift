import SwiftUI
import UIKit
import PhotosUI

struct CameraView: UIViewControllerRepresentable {
    enum Source {
        case camera
        case photoLibrary
    }

    let source: Source
    let onImagePicked: (UIImage) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        if source == .photoLibrary {
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }

        #if targetEnvironment(simulator)
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
        #else
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.allowsEditing = false
            picker.delegate = context.coordinator
            return picker
        } else {
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }
        #endif
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onDismiss: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onDismiss = onDismiss
        }

        // MARK: UIImagePickerController (real device camera)
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            onDismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onDismiss()
        }

        // MARK: PHPickerViewController (simulator photo library)
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                onDismiss()
                return
            }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self?.onImagePicked(image)
                    }
                    self?.onDismiss()
                }
            }
        }
    }
}
