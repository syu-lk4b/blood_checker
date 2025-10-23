import Foundation

enum DateRangeOption: String, CaseIterable, Identifiable {
    case last7Days
    case last30Days
    case last90Days
    case lastYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7Days: return "近7天"
        case .last30Days: return "近30天"
        case .last90Days: return "近90天"
        case .lastYear: return "近1年"
        }
    }

    func interval(referenceDate: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
            return DateInterval(start: start, end: referenceDate)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
            return DateInterval(start: start, end: referenceDate)
        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
            return DateInterval(start: start, end: referenceDate)
        case .lastYear:
            let start = calendar.date(byAdding: .year, value: -1, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
            return DateInterval(start: start, end: referenceDate)
        }
    }
}
