import Foundation
import SwiftUI
import PDFKit
#if os(iOS)
import UIKit
#endif

final class ReportGenerator {
    func exportReport<Content: View>(for view: Content, to url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        Task {
            do {
                let uiImage = try await renderImage(from: view)
                try generatePDF(from: uiImage, to: url)
                await MainActor.run {
                    completion(.success(url))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    @MainActor
    private func renderImage<Content: View>(from view: Content) throws -> UIImage {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
#if os(iOS)
        renderer.scale = UIScreen.main.scale
#else
        renderer.scale = 2.0
#endif
        guard let image = renderer.uiImage else {
            throw ReportGeneratorError.renderFailed
        }
        return image
    }

    private func generatePDF(from image: UIImage, to url: URL) throws {
        let pdfDocument = PDFDocument()
        guard let pdfPage = PDFPage(image: image) else {
            throw ReportGeneratorError.pageCreationFailed
        }
        pdfDocument.insert(pdfPage, at: 0)
        guard let data = pdfDocument.dataRepresentation() else {
            throw ReportGeneratorError.dataGenerationFailed
        }
        try data.write(to: url)
    }
}

private enum ReportGeneratorError: LocalizedError {
    case renderFailed
    case pageCreationFailed
    case dataGenerationFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "无法渲染报告视图"
        case .pageCreationFailed:
            return "无法创建PDF页面"
        case .dataGenerationFailed:
            return "无法生成PDF数据"
        }
    }
}
