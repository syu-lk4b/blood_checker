import Foundation
import UIKit

final class LLMService: ObservableObject {
    @Published var config: LLMConfig {
        didSet { saveConfig() }
    }

    private static let configKey = "llm_config"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.configKey),
           let saved = try? JSONDecoder().decode(LLMConfig.self, from: data) {
            self.config = saved
        } else {
            self.config = LLMConfig()
        }
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.configKey)
        }
    }

    // MARK: - Request Building

    func buildRequestBody(messages: [ChatMessage], stream: Bool) -> Data {
        var msgArray: [[String: Any]] = []

        for message in messages {
            if let imageData = message.imageData {
                let base64 = imageData.base64EncodedString()
                let content: [[String: Any]] = [
                    ["type": "text", "text": message.content],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                ]
                msgArray.append(["role": message.role.rawValue, "content": content])
            } else {
                msgArray.append(["role": message.role.rawValue, "content": message.content])
            }
        }

        let body: [String: Any] = [
            "model": config.modelName,
            "messages": msgArray,
            "stream": stream
        ]

        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    private func buildURLRequest(body: Data, timeout: TimeInterval) throws -> URLRequest {
        guard config.isConfigured else { throw LLMError.notConfigured }
        guard let url = config.chatCompletionsURL else { throw LLMError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        request.timeoutInterval = timeout
        return request
    }

    // MARK: - SSE Parsing

    func parseSSELine(_ line: String) -> String? {
        guard line.hasPrefix("data: ") else { return nil }
        let jsonString = String(line.dropFirst(6))
        guard jsonString != "[DONE]" else { return nil }
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        return content
    }

    // MARK: - Streaming Chat

    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = buildRequestBody(messages: messages, stream: true)
                    let request = try buildURLRequest(body: body, timeout: 60)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line + "\n"
                            if errorBody.count > 1024 { break }
                        }
                        continuation.finish(throwing: LLMError.apiError(httpResponse.statusCode, errorBody))
                        return
                    }

                    for try await line in bytes.lines {
                        if let content = parseSSELine(line) {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch let error as LLMError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: LLMError.networkError(error))
                }
            }
        }
    }

    // MARK: - Vision (OCR)

    func analyzeImage(_ image: UIImage, prompt: String) -> AsyncThrowingStream<String, Error> {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            return AsyncThrowingStream { $0.finish(throwing: LLMError.invalidResponse) }
        }
        let message = ChatMessage(role: .user, content: prompt, imageData: jpegData)
        return streamChat(messages: [message])
    }

    // MARK: - Validation

    func validateConfig() async throws -> Bool {
        let probeMessages = [ChatMessage(role: .user, content: "hi")]
        var body: [String: Any] = (try? JSONSerialization.jsonObject(
            with: buildRequestBody(messages: probeMessages, stream: false)
        ) as? [String: Any]) ?? [:]
        body["max_tokens"] = 1
        let bodyData = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        let request = try buildURLRequest(body: bodyData, timeout: 10)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        if httpResponse.statusCode != 200 {
            throw LLMError.apiError(httpResponse.statusCode, "Validation failed")
        }
        return true
    }
}
