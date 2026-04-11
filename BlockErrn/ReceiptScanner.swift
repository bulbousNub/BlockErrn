import SwiftUI
import UIKit
import VisionKit

private let targetEnvironmentSimulator: Bool = {
#if targetEnvironment(simulator)
    return true
#else
    return false
#endif
}()

struct ReceiptScanner: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let useDocumentScanner = VNDocumentCameraViewController.isSupported && !targetEnvironmentSimulator
        if useDocumentScanner {
            let controller = VNDocumentCameraViewController()
            controller.delegate = context.coordinator
            return controller
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
            picker.delegate = context.coordinator
            picker.cameraCaptureMode = .photo
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ReceiptScanner

        init(parent: ReceiptScanner) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)
                parent.onComplete(image)
            }
            parent.isPresented = false
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.isPresented = false
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.isPresented = false
            parent.onCancel()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
            parent.onCancel()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onComplete(image)
            }
            parent.isPresented = false
        }
    }
}
