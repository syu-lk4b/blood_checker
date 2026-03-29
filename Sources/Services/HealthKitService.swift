import Foundation
import HealthKit

enum HealthKitImportRange: String, CaseIterable, Identifiable {
    case last30Days
    case last90Days
    case lastYear
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last30Days: return "近 30 天"
        case .last90Days: return "近 90 天"
        case .lastYear: return "近 1 年"
        case .allTime: return "全部"
        }
    }

    var startDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .last30Days: return cal.date(byAdding: .day, value: -30, to: now) ?? now
        case .last90Days: return cal.date(byAdding: .day, value: -90, to: now) ?? now
        case .lastYear: return cal.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime: return Date.distantPast
        }
    }
}

final class HealthKitService: ObservableObject {
    @Published var isAuthorized = false
    @Published var isImporting = false
    @Published var importResult: ImportResult?

    struct ImportResult {
        let imported: Int
        let skipped: Int
    }

    private let healthStore: HKHealthStore?

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    init() {
        if Self.isAvailable {
            healthStore = HKHealthStore()
        } else {
            healthStore = nil
        }
        checkAuthorization()
    }

    // MARK: - Authorization

    private var readTypes: Set<HKObjectType> {
        Set([
            HKQuantityType(.bloodPressureSystolic),
            HKQuantityType(.bloodPressureDiastolic),
            HKQuantityType(.heartRate),
            HKCorrelationType(.bloodPressure),
        ].compactMap { $0 })
    }

    private var writeTypes: Set<HKSampleType> {
        Set([
            HKQuantityType(.bloodPressureSystolic),
            HKQuantityType(.bloodPressureDiastolic),
            HKQuantityType(.heartRate),
            HKCorrelationType(.bloodPressure),
        ].compactMap { $0 })
    }

    func requestAuthorization() async throws -> Bool {
        guard let healthStore else { return false }
        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        await MainActor.run { isAuthorized = true }
        return true
    }

    private func checkAuthorization() {
        guard let healthStore else {
            isAuthorized = false
            return
        }
        let systolicType = HKQuantityType(.bloodPressureSystolic)
        let status = healthStore.authorizationStatus(for: systolicType)
        isAuthorized = (status == .sharingAuthorized)
    }

    // MARK: - Write

    func saveBloodPressure(_ reading: BloodPressureReading) async {
        guard let healthStore, isAuthorized else { return }

        let mmHg = HKUnit.millimeterOfMercury()
        let date = reading.recordedAt
        let metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: reading.id.uuidString
        ]

        let systolicSample = HKQuantitySample(
            type: HKQuantityType(.bloodPressureSystolic),
            quantity: HKQuantity(unit: mmHg, doubleValue: Double(reading.systolic)),
            start: date, end: date, metadata: metadata
        )
        let diastolicSample = HKQuantitySample(
            type: HKQuantityType(.bloodPressureDiastolic),
            quantity: HKQuantity(unit: mmHg, doubleValue: Double(reading.diastolic)),
            start: date, end: date, metadata: metadata
        )

        let bpType = HKCorrelationType(.bloodPressure)
        let correlation = HKCorrelation(
            type: bpType,
            start: date, end: date,
            objects: [systolicSample, diastolicSample],
            metadata: metadata
        )

        do {
            try await healthStore.save(correlation)
            if let hr = reading.heartRate {
                let bpm = HKUnit.count().unitDivided(by: .minute())
                let hrSample = HKQuantitySample(
                    type: HKQuantityType(.heartRate),
                    quantity: HKQuantity(unit: bpm, doubleValue: Double(hr)),
                    start: date, end: date, metadata: metadata
                )
                try await healthStore.save(hrSample)
            }
        } catch {
            print("HealthKit save failed: \(error)")
        }
    }

    func deleteBloodPressure(_ reading: BloodPressureReading) async {
        guard let healthStore, isAuthorized else { return }

        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyExternalUUID,
            allowedValues: [reading.id.uuidString]
        )
        let bpType = HKCorrelationType(.bloodPressure)

        do {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.correlation(type: bpType, predicate: predicate)],
                sortDescriptors: []
            )
            let results = try await descriptor.result(for: healthStore)
            for sample in results {
                try await healthStore.delete(sample)
            }
        } catch {
            print("HealthKit delete failed: \(error)")
        }
    }

    // MARK: - Import

    func importReadings(
        range: HealthKitImportRange,
        existingReadings: [BloodPressureReading]
    ) async throws -> [BloodPressureReading] {
        guard let healthStore else { return [] }

        await MainActor.run {
            isImporting = true
            importResult = nil
        }

        defer {
            Task { @MainActor in isImporting = false }
        }

        let bpType = HKCorrelationType(.bloodPressure)
        let predicate = HKQuery.predicateForSamples(
            withStart: range.startDate,
            end: Date(),
            options: .strictStartDate
        )
        let sortDescriptor = SortDescriptor(\HKCorrelation.startDate, order: .reverse)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.correlation(type: bpType, predicate: predicate)],
            sortDescriptors: [sortDescriptor],
            limit: nil
        )

        let correlations = try await descriptor.result(for: healthStore)

        var imported: [BloodPressureReading] = []
        var skipped = 0

        let mmHg = HKUnit.millimeterOfMercury()

        for correlation in correlations {
            let date = correlation.startDate

            if Self.isDuplicate(recordedAt: date, existingReadings: existingReadings, toleranceSeconds: 300) {
                skipped += 1
                continue
            }
            if Self.isDuplicate(recordedAt: date, existingReadings: imported, toleranceSeconds: 300) {
                skipped += 1
                continue
            }

            var systolic: Int?
            var diastolic: Int?

            for sample in correlation.objects {
                guard let quantitySample = sample as? HKQuantitySample else { continue }
                if quantitySample.quantityType == HKQuantityType(.bloodPressureSystolic) {
                    systolic = Int(quantitySample.quantity.doubleValue(for: mmHg))
                } else if quantitySample.quantityType == HKQuantityType(.bloodPressureDiastolic) {
                    diastolic = Int(quantitySample.quantity.doubleValue(for: mmHg))
                }
            }

            guard let sys = systolic, let dia = diastolic else { continue }

            let heartRate = await fetchHeartRate(near: date)

            var reading = BloodPressureReading(systolic: sys, diastolic: dia, heartRate: heartRate)
            reading.recordedAt = date
            imported.append(reading)
        }

        await MainActor.run {
            importResult = ImportResult(imported: imported.count, skipped: skipped)
        }

        return imported
    }

    private func fetchHeartRate(near date: Date) async -> Int? {
        guard let healthStore else { return nil }

        let hrType = HKQuantityType(.heartRate)
        let start = date.addingTimeInterval(-300)
        let end = date.addingTimeInterval(300)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = SortDescriptor(\HKQuantitySample.startDate, order: .reverse)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrType, predicate: predicate)],
            sortDescriptors: [sortDescriptor],
            limit: 1
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            if let sample = results.first {
                let bpm = HKUnit.count().unitDivided(by: .minute())
                return Int(sample.quantity.doubleValue(for: bpm))
            }
        } catch {
            print("HealthKit heart rate fetch failed: \(error)")
        }
        return nil
    }

    // MARK: - Dedup Helper

    static func isDuplicate(
        recordedAt: Date,
        existingReadings: [BloodPressureReading],
        toleranceSeconds: TimeInterval
    ) -> Bool {
        existingReadings.contains { existing in
            abs(existing.recordedAt.timeIntervalSince(recordedAt)) <= toleranceSeconds
        }
    }
}
