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
        XCTAssertEqual(decoded.modelName, config.modelName)
        // apiKey is stored in Keychain, not in JSON — decoded value comes from Keychain
        // In test environment without prior Keychain write, it should be empty
        XCTAssertEqual(decoded.apiKey, "")
    }

    func testLLMConfigApiKeyViaKeychain() {
        KeychainHelper.save("secret-key", forKey: "llm_api_key")
        let data = try! JSONEncoder().encode(LLMConfig(baseURL: "http://test", modelName: "m"))
        let decoded = try! JSONDecoder().decode(LLMConfig.self, from: data)
        XCTAssertEqual(decoded.apiKey, "secret-key")
        KeychainHelper.delete(forKey: "llm_api_key")
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
