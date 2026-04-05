import SwiftUI

struct HealthKitSettingsView: View {
    @EnvironmentObject private var healthKitService: HealthKitService
    @EnvironmentObject private var store: MeasurementStore
    @State private var selectedRange: HealthKitImportRange = .last30Days
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        if HealthKitService.isAvailable {
            Section(header: Text("Apple Health")) {
                if healthKitService.isAuthorized {
                    HStack {
                        Image(systemName: "heart.circle.fill")
                            .foregroundColor(.red)
                        Text("已连接 Apple Health")
                            .foregroundColor(.secondary)
                    }

                    Picker("导入范围", selection: $selectedRange) {
                        ForEach(HealthKitImportRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }

                    Button(action: performImport) {
                        HStack {
                            Text("从 Health 导入")
                            Spacer()
                            if healthKitService.isImporting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(healthKitService.isImporting)

                    if let result = healthKitService.importResult {
                        if result.imported > 0 {
                            Text("已导入 \(result.imported) 条记录，跳过 \(result.skipped) 条重复")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if result.skipped > 0 {
                            Text("没有新数据，跳过 \(result.skipped) 条重复")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("没有找到血压数据")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Button(action: authorize) {
                        HStack {
                            Image(systemName: "heart.circle")
                                .foregroundColor(.red)
                            Text("连接 Apple Health")
                        }
                    }
                }
            }
            .alert("导入失败", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func authorize() {
        Task {
            do {
                _ = try await healthKitService.requestAuthorization()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func performImport() {
        Task {
            do {
                let newReadings = try await healthKitService.importReadings(
                    range: selectedRange,
                    existingReadings: store.readings
                )
                for reading in newReadings {
                    store.addReading(reading, photo: nil)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
