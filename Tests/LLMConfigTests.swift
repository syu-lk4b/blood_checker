import XCTest
@testable import BloodPressureCam

final class LLMConfigTests: XCTestCase {
    func testProviderConfigCodable() throws {
        let config = ProviderConfig(
            name: "Test",
            type: .openaiCompatible,
            baseURL: "http://localhost:11434/v1",
            modelName: "llama3"
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ProviderConfig.self, from: data)
        XCTAssertEqual(decoded.name, config.name)
        XCTAssertEqual(decoded.baseURL, config.baseURL)
        XCTAssertEqual(decoded.modelName, config.modelName)
        XCTAssertEqual(decoded.type, .openaiCompatible)
    }

    func testProviderConfigIsConfigured() {
        // Ollama doesn't require API key
        let configured = ProviderConfig(
            name: "Test",
            type: .ollama,
            baseURL: "http://localhost:11434",
            modelName: "llama3"
        )
        XCTAssertTrue(configured.isConfigured)

        let empty = ProviderConfig(name: "Empty", type: .ollama, baseURL: "", modelName: "")
        XCTAssertFalse(empty.isConfigured)
    }

    func testKeychainHelperAliases() {
        KeychainHelper.save("test-value", forKey: "test_key")
        XCTAssertEqual(KeychainHelper.load(forKey: "test_key"), "test-value")
        XCTAssertEqual(KeychainHelper.get(key: "test_key"), "test-value")
        KeychainHelper.delete(forKey: "test_key")
        XCTAssertNil(KeychainHelper.get(key: "test_key"))
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

    func testChatMessageExcludesImageData() throws {
        let msg = ChatMessage(
            role: .user,
            content: "Photo",
            imageData: Data([0x01, 0x02, 0x03])
        )
        let data = try JSONEncoder().encode(msg)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertFalse(json.contains("imageData"))
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
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
