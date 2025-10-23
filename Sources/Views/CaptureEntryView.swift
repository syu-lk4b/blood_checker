import SwiftUI
import UIKit

struct CaptureEntryView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Binding var isPresented: Bool
    @State private var showCameraSheet = false
    @State private var capturedImage: UIImage?
    @State private var showManualEntry = false

    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "camera.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.accentColor)
                Text("对准血压计的屏幕，拍照识别")
                    .font(.title2)
                Text("拍照后可对识别出来的数据进行校准和补充")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showCameraSheet = true }) {
                    Label("开始拍照", systemImage: "camera")
                        .font(.title3)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                Button(action: { showManualEntry = true }) {
                    Text("手动录入")
                        .padding(.bottom)
                }
            }
            .navigationTitle("拍照录入")
        }
        .sheet(isPresented: $showCameraSheet) {
            PhotoAuthorizationView {
                CameraCaptureView { image in
                    capturedImage = image
                    showManualEntry = true
                }
            }
        }
        .sheet(isPresented: $showManualEntry, onDismiss: { capturedImage = nil }) {
            NavigationView {
                ManualEntryView(existingReading: nil, initialPhoto: capturedImage)
                    .environmentObject(store)
            }
        }
    }
}
