import Foundation
import UIKit

final class PhotoStorage {
    private let fileManager: FileManager
    private let baseURL: URL

    init(fileManager: FileManager = .default, baseURL: URL? = nil) {
        self.fileManager = fileManager
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.baseURL = documents.appendingPathComponent("ReadingPhotos", isDirectory: true)
        }
        ensureDirectoryExists()
    }

    func persist(image: UIImage, id: UUID) throws -> String {
        let filename = "\(id.uuidString).jpg"
        let destination = baseURL.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "PhotoStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法压缩照片数据"])
        }
        try data.write(to: destination, options: .atomic)
        return filename
    }

    func loadImage(named filename: String) -> UIImage? {
        let url = baseURL.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    func removeImage(named filename: String) throws {
        let url = baseURL.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: baseURL.path) {
            try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
    }
}
