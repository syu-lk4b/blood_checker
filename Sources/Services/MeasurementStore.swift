import Foundation
import UIKit

final class MeasurementStore: ObservableObject {
    @Published private(set) var readings: [BloodPressureReading] = []
    @Published var filter: MeasurementCategory = .bloodPressure

    private let fileURL: URL
    private let queue = DispatchQueue(label: "MeasurementStore", qos: .userInitiated)
    private let photoStorage: PhotoStorage

    init(fileManager: FileManager = .default, baseURL: URL? = nil) {
        let directory: URL
        if let baseURL {
            directory = baseURL
        } else {
            directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        }
        fileURL = directory.appendingPathComponent("blood-pressure-readings.json")
        photoStorage = PhotoStorage(baseURL: directory.appendingPathComponent("ReadingPhotos", isDirectory: true))
        load()
    }

    func addReading(_ reading: BloodPressureReading, photo: UIImage?) {
        queue.async { [weak self] in
            guard let self else { return }
            var mutableReading = reading
            if let photo {
                mutableReading.photoFilename = try? self.photoStorage.persist(image: photo, id: reading.id)
            }
            DispatchQueue.main.async {
                self.readings.append(mutableReading)
                self.persist()
            }
        }
    }

    func updateReading(_ reading: BloodPressureReading, photo: UIImage?) {
        guard readings.contains(where: { $0.id == reading.id }) else { return }
        queue.async { [weak self] in
            guard let self else { return }
            var mutableReading = reading
            if let photo {
                mutableReading.photoFilename = try? self.photoStorage.persist(image: photo, id: reading.id)
            }
            DispatchQueue.main.async {
                guard let freshIndex = self.readings.firstIndex(where: { $0.id == reading.id }) else { return }
                self.readings[freshIndex] = mutableReading
                self.persist()
            }
        }
    }

    func deleteReading(_ reading: BloodPressureReading) {
        readings.removeAll { $0.id == reading.id }
        if let file = reading.photoFilename {
            try? photoStorage.removeImage(named: file)
        }
        persist()
    }

    func image(for reading: BloodPressureReading) -> UIImage? {
        guard let filename = reading.photoFilename else { return nil }
        return photoStorage.loadImage(named: filename)
    }

    func readings(for category: MeasurementCategory) -> [BloodPressureReading] {
        readings.filter { $0.category == category }
    }

    func readings(in range: DateInterval, category: MeasurementCategory) -> [BloodPressureReading] {
        readings.filter { $0.category == category && range.contains($0.recordedAt) }.sortedByDateDescending()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            readings = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([BloodPressureReading].self, from: data)
            readings = decoded.sortedByDateDescending()
        } catch {
            print("Failed to load readings: \(error)")
            readings = []
        }
    }

    private func persist() {
        let snapshot = readings
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let encoded = try JSONEncoder().encode(snapshot)
                try encoded.write(to: self.fileURL, options: .atomic)
            } catch {
                print("Failed to save readings: \(error)")
            }
        }
    }
}
