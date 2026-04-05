import Foundation
import UIKit

// MARK: - Protocol

protocol AIProvider: Sendable {
    var supportsVision: Bool { get }
    var supportsStreaming: Bool { get }

    func chat(
        messages: [(role: String, content: String)],
        systemPrompt: String?
    ) async throws -> String

    func chatStream(
        messages: [(role: String, content: String)],
        systemPrompt: String?
    ) -> AsyncThrowingStream<String, Error>

    func analyzeImage(
        _ image: UIImage,
        prompt: String
    ) async throws -> String
}

// Default implementations
extension AIProvider {
    var supportsStreaming: Bool { false }
    var supportsVision: Bool { false }

    func chatStream(
        messages: [(role: String, content: String)],
        systemPrompt: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await chat(messages: messages, systemPrompt: systemPrompt)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func analyzeImage(_ image: UIImage, prompt: String) async throws -> String {
        throw AIServiceError.visionNotSupported
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case notConfigured
    case invalidURL
    case noAPIKey
    case networkError(Error)
    case apiError(statusCode: Int, message: String)
    case unexpectedResponse
    case visionNotSupported
    case streamingError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI 服务未配置"
        case .invalidURL: return "API 地址格式错误"
        case .noAPIKey: return "未配置 API Key"
        case .networkError(let err): return "网络错误: \(err.localizedDescription)"
        case .apiError(let code, let msg): return "API 错误 (\(code)): \(msg)"
        case .unexpectedResponse: return "AI 返回格式异常"
        case .visionNotSupported: return "当前模型不支持图片识别，请更换支持 Vision 的模型"
        case .streamingError(let msg): return "流式传输错误: \(msg)"
        }
    }
}

// MARK: - OpenAI Compatible Provider (covers OpenAI, DeepSeek, Kimi, Qwen, Ollama, etc.)

struct OpenAICompatibleProvider: AIProvider, Sendable {
    let apiKey: String?
    let model: String
    let baseURL: URL
    let supportsVision: Bool
    let supportsStreaming: Bool = true

    func chat(
        messages: [(role: String, content: String)],
        systemPrompt: String?
    ) async throws -> String {
        let body = buildBody(messages: messages, systemPrompt: systemPrompt, stream: false)
        let request = try buildRequest(body: body, timeout: 60)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.unexpectedResponse
        }
        return content
    }

    func chatStream(
        messages: [(role: String, content: String)],
        systemPrompt: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = buildBody(messages: messages, systemPrompt: systemPrompt, stream: true)
                    let request = try buildRequest(body: body, timeout: 60)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 1024 { break }
                        }
                        continuation.finish(throwing: AIServiceError.apiError(statusCode: http.statusCode, message: errorBody))
                        return
                    }

                    for try await line in bytes.lines {
                        if let content = SSEStreamParser.parseContentDelta(from: line) {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch let error as AIServiceError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: AIServiceError.networkError(error))
                }
            }
        }
    }

    func analyzeImage(_ image: UIImage, prompt: String) async throws -> String {
        guard supportsVision else { throw AIServiceError.visionNotSupported }
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw AIServiceError.unexpectedResponse
        }

        let base64 = jpegData.base64EncodedString()
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
        ]

        let allMessages: [[String: Any]] = [
            ["role": "user", "content": content]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": allMessages,
            "stream": false,
            "max_tokens": 4096
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = try buildRequest(body: bodyData, timeout: 30)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let responseContent = message["content"] as? String else {
            throw AIServiceError.unexpectedResponse
        }
        return responseContent
    }

    // MARK: - Private

    private func buildBody(messages: [(role: String, content: String)], systemPrompt: String?, stream: Bool) -> Data {
        var msgArray: [[String: Any]] = []
        if let system = systemPrompt {
            msgArray.append(["role": "system", "content": system])
        }
        for msg in messages {
            msgArray.append(["role": msg.role, "content": msg.content])
        }
        let body: [String: Any] = [
            "model": model,
            "messages": msgArray,
            "stream": stream
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    private func buildRequest(body: Data, timeout: TimeInterval) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        request.timeoutInterval = timeout
        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.unexpectedResponse
        }
        if http.statusCode != 200 {
            throw AIServiceError.apiError(statusCode: http.statusCode, message: "Request failed")
        }
    }
}

// MARK: - Claude Provider

struct ClaudeProvider: AIProvider, Sendable {
    let apiKey: String
    let model: String
    let supportsVision: Bool = true
    let supportsStreaming: Bool = true

    func chat(
        messages: [(role: String, content: String)],
        systemPrompt: String?
    ) async throws -> String {
        let body = buildBody(messages: messages, systemPrompt: systemPrompt, stream: false)
        let request = try buildRequest(body: body, timeout: 60)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AIServiceError.unexpectedResponse
        }
        return text
    }

    func chatStream(
        messages: [(role: String, content: String)],
        systemPrompt: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = buildBody(messages: messages, systemPrompt: systemPrompt, stream: true)
                    let request = try buildRequest(body: body, timeout: 60)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 1024 { break }
                        }
                        continuation.finish(throwing: AIServiceError.apiError(statusCode: http.statusCode, message: errorBody))
                        return
                    }

                    for try await line in bytes.lines {
                        if let content = SSEStreamParser.parseClaudeContentDelta(from: line) {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch let error as AIServiceError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: AIServiceError.networkError(error))
                }
            }
        }
    }

    func analyzeImage(_ image: UIImage, prompt: String) async throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw AIServiceError.unexpectedResponse
        }
        let base64 = jpegData.base64EncodedString()
        let content: [[String: Any]] = [
            ["type": "image", "source": [
                "type": "base64",
                "media_type": "image/jpeg",
                "data": base64
            ]],
            ["type": "text", "text": prompt]
        ]

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [["role": "user", "content": content]]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = try buildRequest(body: bodyData, timeout: 30)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArr = json["content"] as? [[String: Any]],
              let text = contentArr.first?["text"] as? String else {
            throw AIServiceError.unexpectedResponse
        }
        return text
    }

    // MARK: - Private

    private func buildBody(messages: [(role: String, content: String)], systemPrompt: String?, stream: Bool) -> Data {
        var msgArray: [[String: Any]] = []
        for msg in messages {
            msgArray.append(["role": msg.role, "content": msg.content])
        }
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": msgArray,
            "stream": stream
        ]
        if let system = systemPrompt {
            body["system"] = system
        }
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    private func buildRequest(body: Data, timeout: TimeInterval) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw AIServiceError.noAPIKey }
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = body
        request.timeoutInterval = timeout
        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.unexpectedResponse
        }
        if http.statusCode != 200 {
            throw AIServiceError.apiError(statusCode: http.statusCode, message: "Request failed")
        }
    }
}

// MARK: - Provider Factory

func makeProvider(from config: ProviderConfig) -> (any AIProvider)? {
    switch config.type {
    case .claude:
        guard let key = config.apiKey, !key.isEmpty else { return nil }
        return ClaudeProvider(apiKey: key, model: config.modelName)

    case .openai:
        guard let key = config.apiKey, !key.isEmpty else { return nil }
        guard let url = URL(string: config.baseURL) else { return nil }
        return OpenAICompatibleProvider(
            apiKey: key, model: config.modelName,
            baseURL: url, supportsVision: config.supportsVision
        )

    case .openaiCompatible, .ollama:
        guard let url = URL(string: config.baseURL) else { return nil }
        return OpenAICompatibleProvider(
            apiKey: config.apiKey,
            model: config.modelName,
            baseURL: url,
            supportsVision: config.supportsVision
        )
    }
}
