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

        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[0]["type"] as? String, "text")
        XCTAssertEqual(content[1]["type"] as? String, "image_url")
    }

    func testParseSSELine() {
        let service = LLMService()

        let line1 = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
        XCTAssertEqual(service.parseSSELine(line1), "Hello")

        let line2 = "data: {\"choices\":[{\"delta\":{}}]}"
        XCTAssertNil(service.parseSSELine(line2))

        let line3 = "data: [DONE]"
        XCTAssertNil(service.parseSSELine(line3))

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
