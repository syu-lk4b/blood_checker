import XCTest
@testable import BloodPressureCam

final class HealthKitServiceTests: XCTestCase {
    func testDeduplicationExactMatch() {
        let existing = [
            BloodPressureReading(systolic: 120, diastolic: 80, heartRate: 70),
        ]
        XCTAssertTrue(HealthKitService.isDuplicate(
            recordedAt: existing[0].recordedAt,
            existingReadings: existing,
            toleranceSeconds: 300
        ))
    }

    func testDeduplicationOutsideTolerance() {
        let existing = [
            BloodPressureReading(systolic: 120, diastolic: 80, heartRate: 70),
        ]
        let later = existing[0].recordedAt.addingTimeInterval(600)
        XCTAssertFalse(HealthKitService.isDuplicate(
            recordedAt: later,
            existingReadings: existing,
            toleranceSeconds: 300
        ))
    }

    func testDeduplicationWithinTolerance() {
        let existing = [
            BloodPressureReading(systolic: 120, diastolic: 80, heartRate: 70),
        ]
        let within = existing[0].recordedAt.addingTimeInterval(240)
        XCTAssertTrue(HealthKitService.isDuplicate(
            recordedAt: within,
            existingReadings: existing,
            toleranceSeconds: 300
        ))
    }

    func testDeduplicationEmptyExisting() {
        XCTAssertFalse(HealthKitService.isDuplicate(
            recordedAt: Date(),
            existingReadings: [],
            toleranceSeconds: 300
        ))
    }

    func testImportRangeOptions() {
        let cases = HealthKitImportRange.allCases
        XCTAssertEqual(cases.count, 4)
        XCTAssertEqual(cases[0].title, "近 30 天")
        XCTAssertEqual(cases[3].title, "全部")
    }
}
