import SwiftUI
import AVFoundation
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCaptureView

        init(_ parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    @Environment(\.presentationMode) private var presentationMode
    var onCapture: (UIImage) -> Void
    var allowsLibrary: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.cameraCaptureMode = .photo
        if allowsLibrary {
            picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? ["public.image"]
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

struct PhotoAuthorizationView<Content: View>: View {
    @State private var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    let content: () -> Content

    var body: some View {
        Group {
            switch authorizationStatus {
            case .authorized:
                content()
            case .notDetermined:
                VStack(spacing: 16) {
                    Text("需要相机权限")
                        .font(.title2)
                    Text("允许后即可拍照记录血压数据")
                        .foregroundColor(.secondary)
                    Button("授权相机") {
                        AVCaptureDevice.requestAccess(for: .video) { granted in
                            DispatchQueue.main.async {
                                self.authorizationStatus = granted ? .authorized : .denied
                            }
                        }
                    }
                }
            case .denied, .restricted:
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    Text("请在系统设置中开启相机权限")
                        .font(.headline)
                    Link("前往设置", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
            @unknown default:
                content()
            }
        }
        .onAppear {
            authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
}
