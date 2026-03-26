# AI LLM Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AI LLM capabilities to BloodPressureCam — health data analysis, photo OCR recognition, and health Q&A chat — using any OpenAI-compatible API provider.

**Architecture:** Unified `LLMService` handles all API communication (streaming SSE) with a single user-configurable endpoint. `ChatStore` manages conversation persistence. Three AI features (analysis, OCR, chat) share the same service, differing only in prompt construction and response parsing.

**Tech Stack:** Swift, SwiftUI, URLSession (SSE streaming via `bytes(for:)`), JSONEncoder/Decoder, no external dependencies.

---

### Task 1: Models — LLMConfig, ChatMessage, LLMError

**Files:**
- Create: `Sources/Models/LLMConfig.swift`
- Create: `Sources/Models/ChatMessage.swift`
- Test: `Tests/LLMConfigTests.swift`

- [ ] **Step 1: Write the failing test for LLMConfig serialization**

```swift
// Tests/LLMConfigTests.swift
import XCTest
@testable import BloodPressureCam

final class LLMConfigTests: XCTestCase {
    func testLLMConfigCodable() throws {
        let config = LLMConfig(
            baseURL: "http://localhost:11211/api/openai/v1",
            apiKey: "test-key",
            modelName: "gpt-4o"
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LLMConfig.self, from: data)
        XCTAssertEqual(decoded.baseURL, config.baseURL)
        XCTAssertEqual(decoded.apiKey, config.apiKey)
        XCTAssertEqual(decoded.modelName, config.modelName)
    }

    func testLLMConfigIsConfiguredTrue() {
        let config = LLMConfig(
            baseURL: "http://localhost:11211/api/openai/v1",
            apiKey: "",
            modelName: "llama3"
        )
        XCTAssertTrue(config.isConfigured)
    }

    func testLLMConfigIsConfiguredFalseWhenEmpty() {
        let config = LLMConfig(baseURL: "", apiKey: "", modelName: "")
        XCTAssertFalse(config.isConfigured)
    }

    func testChatMessageCodable() throws {
        let msg = ChatMessage(
            role: .user,
            content: "Hello",
            imageData: nil
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.id, msg.id)
        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.content, "Hello")
        XCTAssertNil(decoded.imageData)
    }

    func testChatSessionAddMessage() {
        var session = ChatSession()
        XCTAssertTrue(session.messages.isEmpty)

        let msg = ChatMessage(role: .user, content: "Test")
        session.messages.append(msg)
        XCTAssertEqual(session.messages.count, 1)
        XCTAssertEqual(session.messages[0].content, "Test")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -20`
Expected: FAIL — `LLMConfig`, `ChatMessage`, `ChatSession` not defined.

- [ ] **Step 3: Create LLMConfig.swift**

```swift
// Sources/Models/LLMConfig.swift
import Foundation

struct LLMConfig: Codable, Equatable {
    var baseURL: String = ""
    var apiKey: String = ""
    var modelName: String = ""

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Build the full chat completions URL.
    var chatCompletionsURL: URL? {
        let base = baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        return URL(string: "\(base)/chat/completions")
    }
}

enum LLMError: LocalizedError {
    case notConfigured
    case invalidURL
    case networkError(Error)
    case apiError(Int, String)
    case streamingError
    case visionNotSupported
    case timeout
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI 服务未配置"
        case .invalidURL: return "API 地址格式错误"
        case .networkError(let err): return "网络错误: \(err.localizedDescription)"
        case .apiError(let code, let msg): return "API 错误 (\(code)): \(msg)"
        case .streamingError: return "数据流解析错误"
        case .visionNotSupported: return "当前模型不支持图片识别，请更换支持 Vision 的模型"
        case .timeout: return "请求超时"
        case .invalidResponse: return "无法解析响应"
        }
    }
}
```

- [ ] **Step 4: Create ChatMessage.swift**

```swift
// Sources/Models/ChatMessage.swift
import Foundation

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let imageData: Data?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        imageData: Data? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.imageData = imageData
        self.timestamp = timestamp
    }
}

struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "新对话",
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -20`
Expected: All `LLMConfigTests` PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/Models/LLMConfig.swift Sources/Models/ChatMessage.swift Tests/LLMConfigTests.swift
git commit -m "feat(models): add LLMConfig, ChatMessage, and ChatSession models"
```

---

### Task 2: LLMService — Core Networking & SSE Streaming

**Files:**
- Create: `Sources/Services/LLMService.swift`
- Test: `Tests/LLMServiceTests.swift`

- [ ] **Step 1: Write the failing test for request building and SSE parsing**

```swift
// Tests/LLMServiceTests.swift
import XCTest
@testable import BloodPressureCam

final class LLMServiceTests: XCTestCase {
    func testBuildChatRequestBody() throws {
        let service = LLMService()
        service.config = LLMConfig(
            baseURL: "http://localhost:11211/api/openai/v1",
            apiKey: "test-key",
            modelName: "gpt-4o"
        )

        let messages = [
            ChatMessage(role: .system, content: "You are a helpful assistant."),
            ChatMessage(role: .user, content: "Hello")
        ]

        let body = service.buildRequestBody(messages: messages, stream: true)
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]

        XCTAssertEqual(json["model"] as? String, "gpt-4o")
        XCTAssertEqual(json["stream"] as? Bool, true)

        let msgs = json["messages"] as! [[String: Any]]
        XCTAssertEqual(msgs.count, 2)
        XCTAssertEqual(msgs[0]["role"] as? String, "system")
        XCTAssertEqual(msgs[1]["role"] as? String, "user")
        XCTAssertEqual(msgs[1]["content"] as? String, "Hello")
    }

    func testBuildVisionRequestBody() throws {
        let service = LLMService()
        service.config = LLMConfig(
            baseURL: "http://localhost:11211/api/openai/v1",
            apiKey: "",
            modelName: "gpt-4o"
        )

        let imageData = "fake-image-data".data(using: .utf8)!
        let messages = [
            ChatMessage(role: .user, content: "What is this?", imageData: imageData)
        ]

        let body = service.buildRequestBody(messages: messages, stream: false)
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        let msgs = json["messages"] as! [[String: Any]]
        let content = msgs[0]["content"] as! [[String: Any]]

        // Vision request has content array with text + image_url parts
        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[0]["type"] as? String, "text")
        XCTAssertEqual(content[1]["type"] as? String, "image_url")
    }

    func testParseSSELine() {
        let service = LLMService()

        // Normal data line
        let line1 = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
        XCTAssertEqual(service.parseSSELine(line1), "Hello")

        // Empty data
        let line2 = "data: {\"choices\":[{\"delta\":{}}]}"
        XCTAssertNil(service.parseSSELine(line2))

        // Done signal
        let line3 = "data: [DONE]"
        XCTAssertNil(service.parseSSELine(line3))

        // Non-data line
        let line4 = "event: message"
        XCTAssertNil(service.parseSSELine(line4))
    }

    func testServiceNotConfiguredThrows() async {
        let service = LLMService()
        service.config = LLMConfig(baseURL: "", apiKey: "", modelName: "")

        do {
            _ = try await service.validateConfig()
            XCTFail("Should have thrown")
        } catch let error as LLMError {
            if case .notConfigured = error {
                // expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -20`
Expected: FAIL — `LLMService` not defined.

- [ ] **Step 3: Implement LLMService**

```swift
// Sources/Services/LLMService.swift
import Foundation
import UIKit

final class LLMService: ObservableObject {
    @Published var config: LLMConfig {
        didSet { saveConfig() }
    }

    private let configKey = "llm_config"

    init() {
        if let data = UserDefaults.standard.data(forKey: "llm_config"),
           let saved = try? JSONDecoder().decode(LLMConfig.self, from: data) {
            self.config = saved
        } else {
            self.config = LLMConfig()
        }
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
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
                            errorBody += line
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
        guard config.isConfigured else { throw LLMError.notConfigured }
        guard let url = config.chatCompletionsURL else { throw LLMError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": config.modelName,
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1,
            "stream": false
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -20`
Expected: All `LLMServiceTests` PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/LLMService.swift Tests/LLMServiceTests.swift
git commit -m "feat(services): add LLMService with SSE streaming and vision support"
```

---

### Task 3: ChatStore — Session Persistence

**Files:**
- Create: `Sources/Services/ChatStore.swift`
- Test: `Tests/ChatStoreTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/ChatStoreTests.swift
import XCTest
@testable import BloodPressureCam

final class ChatStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testCreateSession() {
        let store = ChatStore(baseURL: tempDirectory)
        let session = store.createSession()
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(session.title, "新对话")
        XCTAssertTrue(session.messages.isEmpty)
    }

    func testAddMessage() {
        let store = ChatStore(baseURL: tempDirectory)
        let session = store.createSession()
        let msg = ChatMessage(role: .user, content: "Hello")

        store.addMessage(msg, toSessionId: session.id)

        XCTAssertEqual(store.sessions[0].messages.count, 1)
        XCTAssertEqual(store.sessions[0].messages[0].content, "Hello")
    }

    func testDeleteSession() {
        let store = ChatStore(baseURL: tempDirectory)
        let session = store.createSession()
        XCTAssertEqual(store.sessions.count, 1)

        store.deleteSession(session.id)
        XCTAssertTrue(store.sessions.isEmpty)
    }

    func testPersistenceRoundTrip() {
        let store1 = ChatStore(baseURL: tempDirectory)
        let session = store1.createSession()
        let msg = ChatMessage(role: .user, content: "Persisted")
        store1.addMessage(msg, toSessionId: session.id)

        // Create new store from same directory — should load persisted data
        let store2 = ChatStore(baseURL: tempDirectory)
        XCTAssertEqual(store2.sessions.count, 1)
        XCTAssertEqual(store2.sessions[0].messages[0].content, "Persisted")
    }

    func testUpdateSessionTitle() {
        let store = ChatStore(baseURL: tempDirectory)
        let session = store.createSession()

        store.updateSessionTitle(session.id, title: "血压咨询")

        XCTAssertEqual(store.sessions[0].title, "血压咨询")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -20`
Expected: FAIL — `ChatStore` not defined.

- [ ] **Step 3: Implement ChatStore**

```swift
// Sources/Services/ChatStore.swift
import Foundation

final class ChatStore: ObservableObject {
    @Published private(set) var sessions: [ChatSession] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "ChatStore", qos: .userInitiated)

    init(baseURL: URL? = nil) {
        let directory: URL
        if let baseURL {
            directory = baseURL
        } else {
            directory = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        }
        fileURL = directory.appendingPathComponent("chat-sessions.json")
        load()
    }

    @discardableResult
    func createSession() -> ChatSession {
        let session = ChatSession()
        sessions.insert(session, at: 0)
        persist()
        return session
    }

    func addMessage(_ message: ChatMessage, toSessionId sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].messages.append(message)
        sessions[index].updatedAt = Date()
        // Auto-title from first user message
        if sessions[index].title == "新对话",
           message.role == .user {
            let title = String(message.content.prefix(20))
            sessions[index].title = title.isEmpty ? "新对话" : title
        }
        persist()
    }

    func deleteSession(_ sessionId: UUID) {
        sessions.removeAll { $0.id == sessionId }
        persist()
    }

    func updateSessionTitle(_ sessionId: UUID, title: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].title = title
        persist()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try JSONDecoder().decode([ChatSession].self, from: data)
        } catch {
            print("Failed to load chat sessions: \(error)")
            sessions = []
        }
    }

    private func persist() {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let data = try JSONEncoder().encode(self.sessions)
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                assertionFailure("Failed to save chat sessions: \(error)")
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -20`
Expected: All `ChatStoreTests` PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/ChatStore.swift Tests/ChatStoreTests.swift
git commit -m "feat(services): add ChatStore with session persistence"
```

---

### Task 4: LLMSettingsView — AI Configuration UI

**Files:**
- Create: `Sources/Views/LLMSettingsView.swift`
- Modify: `Sources/Views/SettingsView.swift:12-24`

- [ ] **Step 1: Create LLMSettingsView**

```swift
// Sources/Views/LLMSettingsView.swift
import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject private var llmService: LLMService
    @State private var validationState: ValidationState = .idle

    private enum ValidationState {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        Section(header: Text("AI 设置")) {
            TextField("API Base URL", text: $llmService.config.baseURL)
                .textContentType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)

            SecureField("API Key（可选）", text: $llmService.config.apiKey)

            TextField("模型名称", text: $llmService.config.modelName)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            Button(action: testConnection) {
                HStack {
                    Text("测试连接")
                    Spacer()
                    switch validationState {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .failure:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .disabled(!llmService.config.isConfigured)

            if case .failure(let message) = validationState {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func testConnection() {
        validationState = .testing
        Task {
            do {
                _ = try await llmService.validateConfig()
                await MainActor.run { validationState = .success }
            } catch {
                await MainActor.run {
                    validationState = .failure(error.localizedDescription)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Modify SettingsView to include AI settings section**

In `Sources/Views/SettingsView.swift`, add `@EnvironmentObject private var llmService: LLMService` and insert `LLMSettingsView()` before the "通用" section.

The full updated file:

```swift
// Sources/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var llmService: LLMService
    @AppStorage("shouldHighlightHighReadings") private var shouldHighlightHighReadings = true
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 8
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @State private var reminderDate = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()

    var body: some View {
        NavigationView {
            Form {
                LLMSettingsView()

                Section(header: Text("通用")) {
                    Toggle("高血压提醒高亮", isOn: $shouldHighlightHighReadings)
                    Toggle("开启测量提醒", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("提醒时间", selection: $reminderDate, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderDate) { newValue in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                reminderHour = components.hour ?? reminderHour
                                reminderMinute = components.minute ?? reminderMinute
                            }
                    }
                }

                Section(header: Text("关于")) {
                    HStack {
                        Text("应用版本")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
                    Link("意见反馈", destination: URL(string: "mailto:feedback@example.com")!)
                }
            }
            .onAppear {
                if let date = Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) {
                    reminderDate = date
                }
            }
            .navigationTitle("设置")
        }
    }
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED (note: SettingsView now needs `llmService` injected — will be wired in Task 7).

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/LLMSettingsView.swift Sources/Views/SettingsView.swift
git commit -m "feat(views): add LLM settings UI and integrate into SettingsView"
```

---

### Task 5: ChatBubbleView — Message Bubble Component

**Files:**
- Create: `Sources/Views/ChatBubbleView.swift`

- [ ] **Step 1: Create ChatBubbleView**

```swift
// Sources/Views/ChatBubbleView.swift
import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isStreaming: Bool

    init(message: ChatMessage, isStreaming: Bool = false) {
        self.message = message
        self.isStreaming = isStreaming
    }

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.accentColor : Color(.systemGray5))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16)

                if isStreaming {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.leading, 16)
                }

                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/ChatBubbleView.swift
git commit -m "feat(views): add ChatBubbleView message bubble component"
```

---

### Task 6: AIAssistantView — Main AI Tab

**Files:**
- Create: `Sources/Views/AIAssistantView.swift`

- [ ] **Step 1: Create AIAssistantView**

```swift
// Sources/Views/AIAssistantView.swift
import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject private var llmService: LLMService
    @EnvironmentObject private var chatStore: ChatStore
    @EnvironmentObject private var measurementStore: MeasurementStore
    @AppStorage("hasAcceptedAIPrivacy") private var hasAcceptedAIPrivacy = false

    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var streamingContent = ""
    @State private var attachData = false
    @State private var currentSessionId: UUID?
    @State private var showPrivacyAlert = false
    @State private var showSessionList = false
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            Group {
                if !llmService.config.isConfigured {
                    notConfiguredView
                } else {
                    chatView
                }
            }
            .navigationTitle("AI 助手")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSessionList.toggle() }) {
                        Image(systemName: "list.bullet")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createNewSession) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showSessionList) {
                sessionListView
            }
            .alert("数据隐私说明", isPresented: $showPrivacyAlert) {
                Button("我知道了") {
                    hasAcceptedAIPrivacy = true
                    attachData = true
                }
                Button("取消", role: .cancel) {
                    attachData = false
                }
            } message: {
                Text("您的血压数据将发送到所配置的 AI 服务进行分析。数据安全取决于您所选的服务提供商。")
            }
            .onAppear {
                if currentSessionId == nil, let first = chatStore.sessions.first {
                    currentSessionId = first.id
                }
            }
        }
    }

    // MARK: - Not Configured View

    private var notConfiguredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("AI 助手未配置")
                .font(.title2)
            Text("请前往「设置」页面配置 AI 服务")
                .foregroundColor(.secondary)
            NavigationLink(destination: LLMSettingsFormView()) {
                Text("前往设置")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Chat View

    private var chatView: some View {
        VStack(spacing: 0) {
            // Analysis quick action
            Button(action: analyzeData) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                    Text("分析我的血压数据")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .disabled(isStreaming)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        if let session = currentSession {
                            ForEach(session.messages.filter { $0.role != .system }) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        if isStreaming, !streamingContent.isEmpty {
                            ChatBubbleView(
                                message: ChatMessage(
                                    role: .assistant,
                                    content: streamingContent
                                ),
                                isStreaming: true
                            )
                            .id("streaming")
                        }
                    }
                }
                .onChange(of: streamingContent) { _ in
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }

            Divider()

            // Input bar
            inputBar
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 8) {
            if attachData {
                HStack {
                    Image(systemName: "heart.text.square")
                    Text("已附加血压数据")
                        .font(.caption)
                    Spacer()
                    Button(action: { attachData = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Button(action: toggleAttachData) {
                    Image(systemName: attachData ? "heart.text.square.fill" : "heart.text.square")
                        .font(.title3)
                        .foregroundColor(attachData ? .accentColor : .secondary)
                }

                TextField("输入问题...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming
                                ? .secondary : .accentColor
                        )
                }
                .disabled(
                    inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Session List

    private var sessionListView: some View {
        NavigationView {
            List {
                ForEach(chatStore.sessions) { session in
                    Button(action: {
                        currentSessionId = session.id
                        showSessionList = false
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)
                            Text(sessionDateString(session.updatedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let session = chatStore.sessions[index]
                        if currentSessionId == session.id {
                            currentSessionId = nil
                        }
                        chatStore.deleteSession(session.id)
                    }
                }
            }
            .navigationTitle("对话记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showSessionList = false }
                }
            }
        }
    }

    // MARK: - Actions

    private var currentSession: ChatSession? {
        chatStore.sessions.first { $0.id == currentSessionId }
    }

    private func createNewSession() {
        let session = chatStore.createSession()
        currentSessionId = session.id
    }

    private func toggleAttachData() {
        if !attachData && !hasAcceptedAIPrivacy {
            showPrivacyAlert = true
        } else {
            attachData.toggle()
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if currentSessionId == nil {
            let session = chatStore.createSession()
            currentSessionId = session.id
        }
        guard let sessionId = currentSessionId else { return }

        var fullContent = text
        if attachData {
            let dataContext = formatReadingsForContext()
            fullContent = "以下是我的血压数据:\n\(dataContext)\n\n我的问题是: \(text)"
        }

        let userMessage = ChatMessage(role: .user, content: text)
        chatStore.addMessage(userMessage, toSessionId: sessionId)

        let allMessages = buildMessagesForAPI(userContent: fullContent, sessionId: sessionId)
        inputText = ""
        attachData = false

        startStreaming(messages: allMessages, sessionId: sessionId)
    }

    private func analyzeData() {
        if currentSessionId == nil {
            let session = chatStore.createSession()
            currentSessionId = session.id
        }
        guard let sessionId = currentSessionId else { return }

        let dataContext = formatReadingsForContext()
        let userText = "请分析我的血压数据趋势，给出健康建议。"

        let userMessage = ChatMessage(role: .user, content: "📊 分析我的血压数据")
        chatStore.addMessage(userMessage, toSessionId: sessionId)

        let fullContent = "以下是用户的血压测量记录:\n\(dataContext)\n\n请分析血压趋势，指出是否有异常，并给出健康建议。"
        let messages = [
            ChatMessage(role: .system, content: "你是一个专业的健康助手，擅长分析血压数据。请用中文回答。注意：你的分析仅供参考，不构成医疗建议。"),
            ChatMessage(role: .user, content: fullContent)
        ]

        startStreaming(messages: messages, sessionId: sessionId)
    }

    private func startStreaming(messages: [ChatMessage], sessionId: UUID) {
        isStreaming = true
        streamingContent = ""

        streamTask?.cancel()
        streamTask = Task {
            do {
                for try await chunk in llmService.streamChat(messages: messages) {
                    if Task.isCancelled { break }
                    await MainActor.run {
                        streamingContent += chunk
                    }
                }
                if !Task.isCancelled {
                    await MainActor.run {
                        let assistantMessage = ChatMessage(
                            role: .assistant,
                            content: streamingContent
                        )
                        chatStore.addMessage(assistantMessage, toSessionId: sessionId)
                        streamingContent = ""
                        isStreaming = false
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        role: .assistant,
                        content: "⚠️ \(error.localizedDescription)"
                    )
                    chatStore.addMessage(errorMessage, toSessionId: sessionId)
                    streamingContent = ""
                    isStreaming = false
                }
            }
        }
    }

    private func buildMessagesForAPI(userContent: String, sessionId: UUID) -> [ChatMessage] {
        var messages: [ChatMessage] = [
            ChatMessage(
                role: .system,
                content: "你是一个专业的健康助手，擅长血压相关的健康问题。请用中文回答。注意：你的回答仅供参考，不构成医疗建议。"
            )
        ]
        // Include recent conversation history (last 10 messages)
        if let session = chatStore.sessions.first(where: { $0.id == sessionId }) {
            let recentMessages = session.messages.suffix(10)
            messages.append(contentsOf: recentMessages.filter { $0.role != .system })
        }
        // Replace last user message content with full content (including attached data)
        if let lastIndex = messages.lastIndex(where: { $0.role == .user }) {
            messages[lastIndex] = ChatMessage(
                role: .user,
                content: userContent,
                timestamp: messages[lastIndex].timestamp
            )
        }
        return messages
    }

    private func formatReadingsForContext() -> String {
        let readings = measurementStore.readings(for: .bloodPressure)
            .prefix(30)
        if readings.isEmpty { return "暂无血压数据" }

        return readings.map { r in
            let dateStr = r.title
            var line = "\(dateStr) | 高压:\(r.systolic) 低压:\(r.diastolic)"
            if let hr = r.heartRate { line += " 心率:\(hr)" }
            line += " 姿势:\(r.posture.displayName)"
            line += " 级别:\(r.level.title)"
            return line
        }.joined(separator: "\n")
    }

    private func sessionDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

/// Wrapper to embed LLMSettingsView inside a Form for NavigationLink usage
private struct LLMSettingsFormView: View {
    var body: some View {
        Form {
            LLMSettingsView()
        }
        .navigationTitle("AI 设置")
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/AIAssistantView.swift
git commit -m "feat(views): add AIAssistantView with chat, analysis, and data attachment"
```

---

### Task 7: Wire Up — ContentView Tab & App Entry Point

**Files:**
- Modify: `Sources/Views/ContentView.swift:9-30`
- Modify: `Sources/BloodPressureCamApp.swift:4-13`

- [ ] **Step 1: Update ContentView to add AI tab**

Replace `Sources/Views/ContentView.swift` with:

```swift
import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var showCapture = false

    var body: some View {
        TabView {
            RecordsView()
                .tabItem {
                    Label("记录", systemImage: "heart.text.square")
                }
            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.line.uptrend.xyaxis")
                }
            CaptureEntryView(isPresented: $showCapture)
                .tabItem {
                    Label("拍照", systemImage: "camera.fill")
                }
            AIAssistantView()
                .tabItem {
                    Label("AI 助手", systemImage: "brain")
                }
            ReportsView()
                .tabItem {
                    Label("报告", systemImage: "doc.plaintext")
                }
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MeasurementStore())
            .environmentObject(LLMService())
            .environmentObject(ChatStore())
    }
}
```

- [ ] **Step 2: Update BloodPressureCamApp to inject LLMService and ChatStore**

Replace `Sources/BloodPressureCamApp.swift` with:

```swift
import SwiftUI

@main
struct BloodPressureCamApp: App {
    @StateObject private var store = MeasurementStore()
    @StateObject private var llmService = LLMService()
    @StateObject private var chatStore = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(llmService)
                .environmentObject(chatStore)
        }
    }
}
```

- [ ] **Step 3: Build and run tests**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -20`
Expected: BUILD SUCCEEDED, all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/BloodPressureCamApp.swift Sources/Views/ContentView.swift
git commit -m "feat(app): wire AI tab, inject LLMService and ChatStore"
```

---

### Task 8: OCR Integration — CaptureEntryView & ManualEntryView

**Files:**
- Modify: `Sources/Views/CaptureEntryView.swift:45-58`
- Modify: `Sources/Views/ManualEntryView.swift:4-21`

- [ ] **Step 1: Update CaptureEntryView to pass LLMService for OCR**

Replace `Sources/Views/CaptureEntryView.swift` with:

```swift
import SwiftUI
import UIKit

struct CaptureEntryView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var llmService: LLMService
    @Binding var isPresented: Bool
    @State private var showCameraSheet = false
    @State private var capturedImage: UIImage?
    @State private var showManualEntry = false

    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "camera.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.accentColor)
                Text("对准血压计的屏幕，拍照识别")
                    .font(.title2)
                Text("拍照后可对识别出来的数据进行校准和补充")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if llmService.config.isConfigured {
                    Text("AI 识别已启用")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
                Button(action: { showCameraSheet = true }) {
                    Label("开始拍照", systemImage: "camera")
                        .font(.title3)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                Button(action: { showManualEntry = true }) {
                    Text("手动录入")
                        .padding(.bottom)
                }
            }
            .navigationTitle("拍照录入")
        }
        .sheet(isPresented: $showCameraSheet) {
            PhotoAuthorizationView {
                CameraCaptureView { image in
                    capturedImage = image
                    showManualEntry = true
                }
            }
        }
        .sheet(isPresented: $showManualEntry, onDismiss: { capturedImage = nil }) {
            NavigationView {
                ManualEntryView(existingReading: nil, initialPhoto: capturedImage)
                    .environmentObject(store)
                    .environmentObject(llmService)
            }
        }
    }
}
```

- [ ] **Step 2: Update ManualEntryView to support OCR**

Replace `Sources/Views/ManualEntryView.swift` with:

```swift
import SwiftUI
import UIKit

struct ManualEntryView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var llmService: LLMService
    @Environment(\.dismiss) private var dismiss

    @State private var reading: BloodPressureReading
    @State private var photo: UIImage?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showAlert = false
    @State private var isRecognizing = false
    @State private var recognitionError: String?
    let existingReading: BloodPressureReading?
    let initialPhoto: UIImage?

    init(existingReading: BloodPressureReading?, initialPhoto: UIImage? = nil) {
        self.existingReading = existingReading
        self.initialPhoto = initialPhoto
        _reading = State(initialValue: existingReading ?? BloodPressureReading(systolic: 120, diastolic: 80, heartRate: 70))
        _photo = State(initialValue: initialPhoto)
    }

    var body: some View {
        Form {
            if isRecognizing {
                Section {
                    HStack {
                        ProgressView()
                        Text("正在识别血压读数...")
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                }
            }

            if let error = recognitionError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("测量数据")) {
                Stepper(value: $reading.systolic, in: 60...250, step: 1) {
                    HStack {
                        Text("高压")
                        Spacer()
                        Text("\(reading.systolic) mmHg")
                            .foregroundColor(.secondary)
                    }
                }
                Stepper(value: $reading.diastolic, in: 40...150, step: 1) {
                    HStack {
                        Text("低压")
                        Spacer()
                        Text("\(reading.diastolic) mmHg")
                            .foregroundColor(.secondary)
                    }
                }
                Stepper(value: Binding(get: { reading.heartRate ?? 70 }, set: { reading.heartRate = $0 }), in: 30...200, step: 1) {
                    HStack {
                        Text("心率")
                        Spacer()
                        Text("\(reading.heartRate ?? 0) bpm")
                            .foregroundColor(.secondary)
                    }
                }
                DatePicker("测量时间", selection: $reading.recordedAt)
            }

            Section(header: Text("状态")) {
                Picker("体感", selection: $reading.feeling) {
                    ForEach(Feeling.allCases) { feeling in
                        Text(feeling.displayName).tag(feeling)
                    }
                }
                Picker("姿势", selection: $reading.posture) {
                    ForEach(MeasurementPosture.allCases) { posture in
                        Text(posture.displayName).tag(posture)
                    }
                }
                Picker("位置", selection: $reading.location) {
                    ForEach(MeasurementLocation.allCases) { location in
                        Text(location.displayName).tag(location)
                    }
                }
                Stepper(value: Binding(get: { reading.weight ?? 65 }, set: { reading.weight = $0 }), in: 30...200, step: 0.5) {
                    HStack {
                        Text("体重")
                        Spacer()
                        Text(String(format: "%.1f kg", reading.weight ?? 0))
                            .foregroundColor(.secondary)
                    }
                }
                TextField("备注", text: $reading.note, axis: .vertical)
            }

            Section(header: Text("照片")) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                } else if let existing = existingReading, let storedImage = store.image(for: existing) {
                    Image(uiImage: storedImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                } else {
                    Text("尚未添加照片")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Button("拍照") { showCamera = true }
                    Spacer()
                    Button("从相册选取") { showPhotoLibrary = true }
                }
            }
        }
        .navigationTitle(existingReading == nil ? "新增记录" : "编辑记录")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") { save() }
                    .disabled(isRecognizing)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                self.photo = image
            }
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary) { image in
                self.photo = image
            }
        }
        .alert("请输入正确的血压数据", isPresented: $showAlert) {}
        .onAppear {
            if existingReading == nil, let image = initialPhoto {
                performOCR(on: image)
            }
        }
    }

    private func performOCR(on image: UIImage) {
        guard llmService.config.isConfigured else { return }

        isRecognizing = true
        recognitionError = nil

        let prompt = """
        请识别这张血压计照片中的读数。只返回 JSON 格式，不要其他文字：
        {"systolic": 数值, "diastolic": 数值, "heartRate": 数值}
        如果无法识别某个值，对应字段设为 null。
        """

        Task {
            var result = ""
            do {
                for try await chunk in llmService.analyzeImage(image, prompt: prompt) {
                    result += chunk
                }
                // Parse JSON from response (handle markdown code blocks)
                let jsonString = extractJSON(from: result)
                if let data = jsonString.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    await MainActor.run {
                        if let sys = parsed["systolic"] as? Int { reading.systolic = sys }
                        if let dia = parsed["diastolic"] as? Int { reading.diastolic = dia }
                        if let hr = parsed["heartRate"] as? Int { reading.heartRate = hr }
                        isRecognizing = false
                    }
                } else {
                    await MainActor.run {
                        recognitionError = "无法识别读数，请手动输入"
                        isRecognizing = false
                    }
                }
            } catch let error as LLMError {
                await MainActor.run {
                    if case .visionNotSupported = error {
                        recognitionError = error.errorDescription
                    } else {
                        recognitionError = "识别失败: \(error.localizedDescription)"
                    }
                    isRecognizing = false
                }
            } catch {
                await MainActor.run {
                    recognitionError = "识别失败，请手动输入"
                    isRecognizing = false
                }
            }
        }
    }

    /// Extract JSON from LLM response, handling markdown code blocks
    private func extractJSON(from text: String) -> String {
        // Try to find JSON in code blocks first
        if let range = text.range(of: "```json"),
           let endRange = text.range(of: "```", range: range.upperBound..<text.endIndex) {
            return String(text[range.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = text.range(of: "```"),
           let endRange = text.range(of: "```", range: range.upperBound..<text.endIndex) {
            return String(text[range.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Try to find raw JSON object
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard reading.systolic >= reading.diastolic else {
            showAlert = true
            return
        }
        if existingReading != nil {
            store.updateReading(reading, photo: photo)
        } else {
            store.addReading(reading, photo: photo ?? initialPhoto)
        }
        dismiss()
    }
}

private struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType {
        case photoLibrary
    }

    var sourceType: SourceType
    var completion: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.completion(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
```

- [ ] **Step 3: Build and run all tests**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -20`
Expected: BUILD SUCCEEDED, all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/CaptureEntryView.swift Sources/Views/ManualEntryView.swift
git commit -m "feat(ocr): integrate LLM vision OCR into capture and manual entry flow"
```

---

### Task 9: Final Verification & Cleanup

**Files:**
- All previously created/modified files

- [ ] **Step 1: Run full build**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Run all tests**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -20`
Expected: All tests PASS.

- [ ] **Step 3: Verify file structure**

Run: `find Sources -name "*.swift" | sort`
Expected output should include all new files:
```
Sources/BloodPressureCamApp.swift
Sources/Models/BloodPressureReading.swift
Sources/Models/ChatMessage.swift
Sources/Models/LLMConfig.swift
Sources/Services/ChatStore.swift
Sources/Services/LLMService.swift
Sources/Services/MeasurementStore.swift
Sources/Services/PhotoStorage.swift
Sources/Services/ReportGenerator.swift
Sources/Views/AIAssistantView.swift
Sources/Views/CameraCaptureView.swift
Sources/Views/CaptureEntryView.swift
Sources/Views/ChatBubbleView.swift
Sources/Views/ContentView.swift
Sources/Views/LLMSettingsView.swift
Sources/Views/ManualEntryView.swift
Sources/Views/RecordsView.swift
Sources/Views/ReportsView.swift
Sources/Views/SettingsView.swift
Sources/Views/StatisticsView.swift
```

- [ ] **Step 4: Commit any remaining changes**

```bash
git add -A
git status
# Only commit if there are changes
git commit -m "chore: final cleanup for AI LLM integration"
```
