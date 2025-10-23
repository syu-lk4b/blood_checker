import SwiftUI
import Charts
import UIKit

struct ReportsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var range: DateRangeOption = .last30Days
    @State private var isGenerating = false
    @State private var shareURL: ShareDestination?
    private let generator = ReportGenerator()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("报告周期", selection: $range) {
                        ForEach(DateRangeOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    ReportPreview(readings: readings, range: range)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                        )
                        .padding(.top)
                }
                .padding()
            }
            .navigationTitle("健康报告")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Button(action: exportReport) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(readings.isEmpty)
                    }
                }
            }
            .sheet(item: $shareURL) { destination in
                ShareSheet(items: [destination.url])
            }
        }
    }

    private var readings: [BloodPressureReading] {
        store.readings(in: range.interval(), category: .bloodPressure)
    }

    private func exportReport() {
        guard !readings.isEmpty else { return }
        isGenerating = true

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Report-\(UUID().uuidString).pdf")
        let view = ReportPreview(readings: readings, range: range)

        generator.exportReport(for: view, to: url) { result in
            switch result {
            case .success(let url):
                shareURL = ShareDestination(url: url)
            case .failure(let error):
                print("Export failed: \(error)")
            }
            isGenerating = false
        }
    }
}

struct ReportPreview: View {
    let readings: [BloodPressureReading]
    let range: DateRangeOption

    private var metrics: ReportMetrics {
        ReportMetrics.make(from: readings, range: range.interval())
    }

    private var groupedByDay: [(key: Date, value: [BloodPressureReading])] {
        Dictionary(grouping: readings) { reading in
            Calendar.current.startOfDay(for: reading.recordedAt)
        }
        .sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if readings.isEmpty {
                Text("当前周期暂无数据")
                    .foregroundColor(.secondary)
            } else {
                trendChart
                metricsSummary
                Divider()
                tableHeader
                ForEach(groupedByDay, id: \.key) { entry in
                    tableRow(for: entry.key, readings: entry.value)
                    Divider()
                }
            }
        }
        .padding(24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("血压报告单")
                .font(.title2)
                .fontWeight(.bold)
            let interval = range.interval()
            Text("\(interval.start.formatted(date: .numeric, time: .omitted)) ➜ \(interval.end.formatted(date: .numeric, time: .omitted))")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var trendChart: some View {
        Chart(readings) { reading in
            LineMark(
                x: .value("日期", reading.recordedAt),
                y: .value("高压", reading.systolic)
            )
            .symbol(.circle)
            .symbolSize(40)
            AreaMark(
                x: .value("日期", reading.recordedAt),
                y: .value("低压", reading.diastolic)
            )
            .foregroundStyle(.linearGradient(colors: [Color.accentColor.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
            if let heartRate = reading.heartRate {
                LineMark(
                    x: .value("日期", reading.recordedAt),
                    y: .value("心率", heartRate)
                )
                .foregroundStyle(.red)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2))
        }
        .frame(height: 220)
    }

    private var metricsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                summaryTile(title: "平均高压", value: String(format: "%.0f", metrics.averageSystolic))
                summaryTile(title: "平均低压", value: String(format: "%.0f", metrics.averageDiastolic))
            }
            if let heart = metrics.averageHeartRate {
                summaryTile(title: "平均心率", value: String(format: "%.0f", heart))
            }
            Text(metrics.trendSummary)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var tableHeader: some View {
        HStack {
            Text("日期").frame(width: 72, alignment: .leading)
            Spacer()
            Text("高压")
            Spacer()
            Text("低压")
            Spacer()
            Text("心率")
            Spacer()
            Text("姿势")
            Spacer()
            Text("备注")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func tableRow(for date: Date, readings: [BloodPressureReading]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(readings) { reading in
                HStack(alignment: .top) {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .frame(width: 72, alignment: .leading)
                    Spacer()
                    Text("\(reading.systolic)")
                    Spacer()
                    Text("\(reading.diastolic)")
                    Spacer()
                    Text(reading.heartRate.map { "\($0)" } ?? "-")
                    Spacer()
                    Text(reading.posture.displayName)
                    Spacer()
                    Text(reading.note.isEmpty ? "-" : reading.note)
                        .frame(width: 100, alignment: .leading)
                }
                .font(.caption)
            }
        }
    }

    private func summaryTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemFill))
        .cornerRadius(12)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct ShareDestination: Identifiable {
    let url: URL
    var id: URL { url }
}
