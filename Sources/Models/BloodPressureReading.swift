import Foundation
import CoreLocation

enum MeasurementCategory: String, Codable, CaseIterable, Identifiable {
    case bloodPressure = "bloodPressure"
    case bloodSugar = "bloodSugar"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bloodPressure:
            return "血压"
        case .bloodSugar:
            return "血糖"
        }
    }
}

enum Feeling: String, Codable, CaseIterable, Identifiable {
    case excellent
    case good
    case fair
    case poor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .excellent: return "很好"
        case .good: return "好"
        case .fair: return "一般"
        case .poor: return "差"
        }
    }
}

enum MeasurementPosture: String, Codable, CaseIterable, Identifiable {
    case seated
    case standing
    case supine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .seated: return "坐着"
        case .standing: return "站着"
        case .supine: return "仰卧"
        }
    }
}

enum MeasurementLocation: String, Codable, CaseIterable, Identifiable {
    case leftArm
    case rightArm
    case wrist

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leftArm: return "左臂"
        case .rightArm: return "右臂"
        case .wrist: return "手腕"
        }
    }
}

enum BloodPressureLevel: String, Codable {
    case optimal
    case normal
    case elevated
    case hypertensionStage1
    case hypertensionStage2
    case hypertensiveCrisis

    var title: String {
        switch self {
        case .optimal: return "理想"
        case .normal: return "正常"
        case .elevated: return "偏高"
        case .hypertensionStage1: return "高血压一期"
        case .hypertensionStage2: return "高血压二期"
        case .hypertensiveCrisis: return "高血压危象"
        }
    }

    var colorHex: String {
        switch self {
        case .optimal: return "#00A693"
        case .normal: return "#55C686"
        case .elevated: return "#F2B035"
        case .hypertensionStage1: return "#EC6941"
        case .hypertensionStage2: return "#D64550"
        case .hypertensiveCrisis: return "#A02C2C"
        }
    }
}

struct BloodPressureReading: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var category: MeasurementCategory = .bloodPressure
    var recordedAt: Date = Date()
    var systolic: Int
    var diastolic: Int
    var heartRate: Int?
    var feeling: Feeling = .good
    var location: MeasurementLocation = .leftArm
    var posture: MeasurementPosture = .seated
    var weight: Double?
    var note: String = ""
    var photoFilename: String?
    var deviceName: String?
    var geoLocation: CLLocationCoordinate2DCodable?

    var level: BloodPressureLevel {
        switch (systolic, diastolic) {
        case (..<120, ..<80):
            return diastolic < 70 ? .optimal : .normal
        case (120..<130, ..<80):
            return .elevated
        case (130..<140, 80..<90), (..<140, 80..<90):
            return .hypertensionStage1
        case (140..<180, 90..<120):
            return .hypertensionStage2
        default:
            return .hypertensiveCrisis
        }
    }

    var title: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: recordedAt)
    }

    var subtitle: String {
        "高压: \(systolic) 低压: \(diastolic)" + (heartRate.map { " 心率: \($0)" } ?? "")
    }
}

struct CLLocationCoordinate2DCodable: Codable, Equatable {
    var latitude: Double
    var longitude: Double
}

extension Array where Element == BloodPressureReading {
    func sortedByDateDescending() -> [BloodPressureReading] {
        sorted { $0.recordedAt > $1.recordedAt }
    }
}
