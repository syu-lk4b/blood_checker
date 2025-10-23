import XCTest
@testable import BloodPressureCam

final class MeasurementStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testAddReadingPersistsToDisk() throws {
        let store = MeasurementStore(baseURL: tempDirectory)
        let expectation = XCTestExpectation(description: "Wait for persistence")
        let reading = BloodPressureReading(systolic: 130, diastolic: 85, heartRate: 72)

        store.addReading(reading, photo: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(store.readings.count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testLoadExistingData() throws {
        let url = tempDirectory.appendingPathComponent("blood-pressure-readings.json")
        let reading = BloodPressureReading(systolic: 125, diastolic: 78, heartRate: 70)
        let data = try JSONEncoder().encode([reading])
        try data.write(to: url)

        let store = MeasurementStore(baseURL: tempDirectory)

        XCTAssertEqual(store.readings.count, 1)
        XCTAssertEqual(store.readings.first?.systolic, 125)
    }
}
