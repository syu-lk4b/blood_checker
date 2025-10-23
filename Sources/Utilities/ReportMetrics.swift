import Foundation

struct ReportMetrics {
    let averageSystolic: Double
    let averageDiastolic: Double
    let averageHeartRate: Double?
    let highestSystolic: Int?
    let lowestSystolic: Int?
    let highestDiastolic: Int?
    let lowestDiastolic: Int?
    let dateRange: DateInterval

    var trendSummary: String {
        guard let highestSystolic, let lowestSystolic else { return "样本太少，暂无法计算趋势" }
        let delta = Double(highestSystolic - lowestSystolic)
        switch delta {
        case ..<5:
            return "血压稳定"
        case ..<15:
            return "血压小幅波动"
        default:
            return "血压波动较大，建议关注"
        }
    }

    static func make(from readings: [BloodPressureReading], range: DateInterval) -> ReportMetrics {
        guard !readings.isEmpty else {
            return ReportMetrics(
                averageSystolic: 0,
                averageDiastolic: 0,
                averageHeartRate: nil,
                highestSystolic: nil,
                lowestSystolic: nil,
                highestDiastolic: nil,
                lowestDiastolic: nil,
                dateRange: range
            )
        }
        let systolicValues = readings.map { $0.systolic }
        let diastolicValues = readings.map { $0.diastolic }
        let heartValues = readings.compactMap { $0.heartRate }

        let avgS = Double(systolicValues.reduce(0, +)) / Double(systolicValues.count)
        let avgD = Double(diastolicValues.reduce(0, +)) / Double(diastolicValues.count)
        let avgH = heartValues.isEmpty ? nil : Double(heartValues.reduce(0, +)) / Double(heartValues.count)

        return ReportMetrics(
            averageSystolic: avgS,
            averageDiastolic: avgD,
            averageHeartRate: avgH,
            highestSystolic: systolicValues.max(),
            lowestSystolic: systolicValues.min(),
            highestDiastolic: diastolicValues.max(),
            lowestDiastolic: diastolicValues.min(),
            dateRange: range
        )
    }
}
