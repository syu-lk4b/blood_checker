import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var range: DateRangeOption = .last30Days

    private var data: [BloodPressureReading] {
        store.readings(in: range.interval(), category: .bloodPressure)
    }

    private var metrics: ReportMetrics {
        ReportMetrics.make(from: data, range: range.interval())
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    rangePicker
                    chartSection
                    metricsSection
                }
                .padding()
            }
            .navigationTitle("趋势统计")
        }
    }

    private var rangePicker: some View {
        Picker("时间范围", selection: $range) {
            ForEach(DateRangeOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("血压趋势")
                .font(.headline)
            if data.isEmpty {
                Text("当前时间范围内暂无数据")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Chart(data) { reading in
                    LineMark(
                        x: .value("日期", reading.recordedAt),
                        y: .value("高压", reading.systolic)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)

                    LineMark(
                        x: .value("日期", reading.recordedAt),
                        y: .value("低压", reading.diastolic)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor.opacity(0.5))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: range == .last7Days ? 1 : 5)) { value in
                        if let dateValue = value.as(Date.self) {
                            AxisValueLabel {
                                Text(dateValue, format: .dateTime.month(.defaultDigits).day())
                            }
                        }
                    }
                }
                .frame(height: 220)
                .accessibilityLabel("血压趋势图表，共\(data.count)条数据")
            }
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("统计")
                .font(.headline)
            VStack(spacing: 12) {
                HStack {
                    StatisticBadge(title: "平均高压", value: String(format: "%.0f", metrics.averageSystolic))
                    StatisticBadge(title: "平均低压", value: String(format: "%.0f", metrics.averageDiastolic))
                }
                HStack {
                    StatisticBadge(title: "最高高压", value: metrics.highestSystolic.map(String.init) ?? "-")
                    StatisticBadge(title: "最低高压", value: metrics.lowestSystolic.map(String.init) ?? "-")
                }
                HStack {
                    StatisticBadge(title: "最高低压", value: metrics.highestDiastolic.map(String.init) ?? "-")
                    StatisticBadge(title: "最低低压", value: metrics.lowestDiastolic.map(String.init) ?? "-")
                }
                if let heart = metrics.averageHeartRate {
                    StatisticBadge(title: "平均心率", value: String(format: "%.0f", heart))
                }
                Text(metrics.trendSummary)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct StatisticBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
}
