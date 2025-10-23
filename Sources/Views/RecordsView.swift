import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var selectedCategory: MeasurementCategory = .bloodPressure
    @State private var showAddSheet = false

    private var filteredReadings: [BloodPressureReading] {
        store.readings(for: selectedCategory).sortedByDateDescending()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                categoryPicker
                if filteredReadings.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredReadings) { reading in
                            NavigationLink(destination: ReadingDetailView(reading: reading)) {
                                ReadingRowView(reading: reading)
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                let reading = filteredReadings[index]
                                store.deleteReading(reading)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("健康记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationView {
                    ManualEntryView(existingReading: nil)
                        .environmentObject(store)
                }
            }
        }
    }

    private var categoryPicker: some View {
        Picker("类别", selection: $selectedCategory) {
            ForEach(MeasurementCategory.allCases) { category in
                Text(category.displayName).tag(category)
            }
        }
        .pickerStyle(.segmented)
        .padding([.horizontal, .top])
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            Text("暂无记录")
                .font(.title3)
            Text("点击右上角的 + 号，或者在拍照标签中识别血压仪屏幕")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReadingRowView: View {
    let reading: BloodPressureReading

    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM月dd日 HH:mm"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formatter.string(from: reading.recordedAt))
                    .font(.headline)
                Spacer()
                Text(reading.level.title)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(reading.level.colorHex))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            HStack(spacing: 16) {
                metric("高压", value: reading.systolic)
                metric("低压", value: reading.diastolic)
                if let heartRate = reading.heartRate {
                    metric("心率", value: heartRate)
                }
            }
            .font(.title3)
        }
        .padding(.vertical, 8)
    }

    private func metric(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(value)")
                .fontWeight(.semibold)
        }
    }
}

struct ReadingDetailView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    let reading: BloodPressureReading
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = store.image(for: reading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                }
                detailRow(title: "测量时间", value: reading.title)
                detailRow(title: "高压", value: "\(reading.systolic) mmHg")
                detailRow(title: "低压", value: "\(reading.diastolic) mmHg")
                if let heartRate = reading.heartRate {
                    detailRow(title: "心率", value: "\(heartRate) bpm")
                }
                detailRow(title: "体感", value: reading.feeling.displayName)
                detailRow(title: "姿势", value: reading.posture.displayName)
                detailRow(title: "位置", value: reading.location.displayName)
                if let weight = reading.weight {
                    detailRow(title: "体重", value: String(format: "%.1f kg", weight))
                }
                if !reading.note.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("备注")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(reading.note)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("详情")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationView {
                ManualEntryView(existingReading: reading)
                    .environmentObject(store)
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
