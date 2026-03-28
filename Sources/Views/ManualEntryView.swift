import SwiftUI
import UIKit

struct ManualEntryView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var llmService: LLMService
    @Environment(\.dismiss) private var dismiss

    @State private var reading: BloodPressureReading
    @State private var photo: UIImage?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showAlert = false
    @State private var isRecognizing = false
    @State private var recognitionError: String?
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
            if isRecognizing {
                Section {
                    HStack {
                        ProgressView()
                        Text("正在识别血压读数...")
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                }
            }

            if let error = recognitionError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

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
                    .disabled(isRecognizing)
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
        .onAppear {
            if existingReading == nil, let image = initialPhoto {
                performOCR(on: image)
            }
        }
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

    private func performOCR(on image: UIImage) {
        guard llmService.config.isConfigured else { return }

        isRecognizing = true
        recognitionError = nil

        let prompt = """
        请识别这张血压计照片中的读数。只返回 JSON 格式，不要其他文字：
        {"systolic": 数值, "diastolic": 数值, "heartRate": 数值}
        如果无法识别某个值，对应字段设为 null。
        """

        Task {
            var result = ""
            do {
                for try await chunk in llmService.analyzeImage(image, prompt: prompt) {
                    result += chunk
                }
                let jsonString = extractJSON(from: result)
                if let data = jsonString.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    await MainActor.run {
                        if let sys = (parsed["systolic"] as? NSNumber)?.intValue { reading.systolic = sys }
                        if let dia = (parsed["diastolic"] as? NSNumber)?.intValue { reading.diastolic = dia }
                        if let hr = (parsed["heartRate"] as? NSNumber)?.intValue { reading.heartRate = hr }
                        isRecognizing = false
                    }
                } else {
                    await MainActor.run {
                        recognitionError = "无法识别读数，请手动输入"
                        isRecognizing = false
                    }
                }
            } catch let error as LLMError {
                await MainActor.run {
                    if case .visionNotSupported = error {
                        recognitionError = error.errorDescription
                    } else {
                        recognitionError = "识别失败: \(error.localizedDescription)"
                    }
                    isRecognizing = false
                }
            } catch {
                await MainActor.run {
                    recognitionError = "识别失败，请手动输入"
                    isRecognizing = false
                }
            }
        }
    }

    private func extractJSON(from text: String) -> String {
        if let range = text.range(of: "```json"),
           let endRange = text.range(of: "```", range: range.upperBound..<text.endIndex) {
            return String(text[range.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = text.range(of: "```"),
           let endRange = text.range(of: "```", range: range.upperBound..<text.endIndex) {
            return String(text[range.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
