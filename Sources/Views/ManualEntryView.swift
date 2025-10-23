import SwiftUI
import UIKit

struct ManualEntryView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss

    @State private var reading: BloodPressureReading
    @State private var photo: UIImage?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showAlert = false
    let existingReading: BloodPressureReading?
    let initialPhoto: UIImage?

    init(existingReading: BloodPressureReading?, initialPhoto: UIImage? = nil) {
        self.existingReading = existingReading
        self.initialPhoto = initialPhoto
        _reading = State(initialValue: existingReading ?? BloodPressureReading(systolic: 120, diastolic: 80, heartRate: 70))
        _photo = State(initialValue: initialPhoto)
    }

    var body: some View {
        Form {
            Section(header: Text("测量数据")) {
                Stepper(value: $reading.systolic, in: 60...250, step: 1) {
                    HStack {
                        Text("高压")
                        Spacer()
                        Text("\(reading.systolic) mmHg")
                            .foregroundColor(.secondary)
                    }
                }
                Stepper(value: $reading.diastolic, in: 40...150, step: 1) {
                    HStack {
                        Text("低压")
                        Spacer()
                        Text("\(reading.diastolic) mmHg")
                            .foregroundColor(.secondary)
                    }
                }
                Stepper(value: Binding(get: { reading.heartRate ?? 70 }, set: { reading.heartRate = $0 }), in: 30...200, step: 1) {
                    HStack {
                        Text("心率")
                        Spacer()
                        Text("\(reading.heartRate ?? 0) bpm")
                            .foregroundColor(.secondary)
                    }
                }
                DatePicker("测量时间", selection: $reading.recordedAt)
            }

            Section(header: Text("状态")) {
                Picker("体感", selection: $reading.feeling) {
                    ForEach(Feeling.allCases) { feeling in
                        Text(feeling.displayName).tag(feeling)
                    }
                }
                Picker("姿势", selection: $reading.posture) {
                    ForEach(MeasurementPosture.allCases) { posture in
                        Text(posture.displayName).tag(posture)
                    }
                }
                Picker("位置", selection: $reading.location) {
                    ForEach(MeasurementLocation.allCases) { location in
                        Text(location.displayName).tag(location)
                    }
                }
                Stepper(value: Binding(get: { reading.weight ?? 65 }, set: { reading.weight = $0 }), in: 30...200, step: 0.5) {
                    HStack {
                        Text("体重")
                        Spacer()
                        Text(String(format: "%.1f kg", reading.weight ?? 0))
                            .foregroundColor(.secondary)
                    }
                }
                TextField("备注", text: $reading.note, axis: .vertical)
            }

            Section(header: Text("照片")) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                } else if let existing = existingReading, let storedImage = store.image(for: existing) {
                    Image(uiImage: storedImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                } else {
                    Text("尚未添加照片")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Button("拍照") { showCamera = true }
                    Spacer()
                    Button("从相册选取") { showPhotoLibrary = true }
                }
            }
        }
        .navigationTitle(existingReading == nil ? "新增记录" : "编辑记录")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") { save() }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                self.photo = image
            }
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary) { image in
                self.photo = image
            }
        }
        .alert("请输入正确的血压数据", isPresented: $showAlert) {}
    }

    private func save() {
        guard reading.systolic >= reading.diastolic else {
            showAlert = true
            return
        }
        if existingReading != nil {
            store.updateReading(reading, photo: photo)
        } else {
            store.addReading(reading, photo: photo ?? initialPhoto)
        }
        dismiss()
    }
}

private struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType {
        case photoLibrary
    }

    var sourceType: SourceType
    var completion: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.completion(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
