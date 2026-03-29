import XCTest
@testable import BloodPressureCam

final class LLMServiceTests: XCTestCase {
    func testSSEParseContentDelta() {
        let line1 = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
        XCTAssertEqual(SSEStreamParser.parseContentDelta(from: line1), "Hello")

        // Without space after data:
        let line1b = "data:{\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
        XCTAssertEqual(SSEStreamParser.parseContentDelta(from: line1b), "Hello")

        let line2 = "data: {\"choices\":[{\"delta\":{}}]}"
        XCTAssertNil(SSEStreamParser.parseContentDelta(from: line2))

        let line3 = "data: [DONE]"
        XCTAssertNil(SSEStreamParser.parseContentDelta(from: line3))

        let line4 = "event: message"
        XCTAssertNil(SSEStreamParser.parseContentDelta(from: line4))

        let line5 = "data:"
        XCTAssertNil(SSEStreamParser.parseContentDelta(from: line5))
    }

    func testSSEParseClaudeDelta() {
        let line = "data: {\"type\":\"content_block_delta\",\"delta\":{\"text\":\"World\"}}"
        XCTAssertEqual(SSEStreamParser.parseClaudeContentDelta(from: line), "World")

        let nonDelta = "data: {\"type\":\"message_start\"}"
        XCTAssertNil(SSEStreamParser.parseClaudeContentDelta(from: nonDelta))
    }

    func testProviderConfigIsConfigured() {
        // Ollama doesn't need API key
        let ollama = ProviderConfig(
            name: "Test Ollama", type: .ollama,
            baseURL: "http://localhost:11434", modelName: "llama3"
        )
        XCTAssertTrue(ollama.isConfigured)

        // Empty config
        let empty = ProviderConfig(
            name: "Empty", type: .openaiCompatible,
            baseURL: "", modelName: ""
        )
        XCTAssertFalse(empty.isConfigured)
    }

    func testProviderConfigCodable() throws {
        let config = ProviderConfig(
            name: "DeepSeek", type: .openaiCompatible,
            baseURL: "https://api.deepseek.com", modelName: "deepseek-chat"
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ProviderConfig.self, from: data)
        XCTAssertEqual(decoded.name, "DeepSeek")
        XCTAssertEqual(decoded.type, .openaiCompatible)
        XCTAssertEqual(decoded.modelName, "deepseek-chat")
    }

    func testBuiltInProvidersExist() {
        let providers = ProviderConfig.builtInProviders
        XCTAssertTrue(providers.count >= 6)

        let names = providers.map(\.name)
        XCTAssertTrue(names.contains("DeepSeek"))
        XCTAssertTrue(names.contains("Kimi (月之暗面)"))
        XCTAssertTrue(names.contains("通义千问"))
    }

    func testMakeProviderOllama() {
        let config = ProviderConfig(
            name: "Test", type: .ollama,
            baseURL: "http://localhost:11434", modelName: "llama3"
        )
        let provider = makeProvider(from: config)
        XCTAssertNotNil(provider)
        XCTAssertFalse(provider!.supportsVision)
    }
}
