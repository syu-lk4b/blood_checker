import Foundation

struct ProviderConfig: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var type: ProviderType
    var baseURL: String
    var modelName: String
    var supportsVision: Bool = false
    var supportsStreaming: Bool = true
    var isBuiltIn: Bool = false
    var isEnabled: Bool = true
    var isDefault: Bool = false
    var sortOrder: Int = 0

    var isConfigured: Bool {
        if !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if type.requiresAPIKey {
                return apiKey != nil && !apiKey!.isEmpty
            }
            return true
        }
        return false
    }

    /// API Key stored in Keychain, not serialized
    var apiKey: String? {
        get { KeychainHelper.get(key: "provider_\(id)") }
        nonmutating set {
            if let value = newValue, !value.isEmpty {
                KeychainHelper.set(key: "provider_\(id)", value: value)
            } else {
                KeychainHelper.delete(key: "provider_\(id)")
            }
        }
    }

    var chatCompletionsURL: URL? {
        let base = baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        switch type {
        case .claude:
            return URL(string: "\(base)/v1/messages")
        case .openai:
            return URL(string: "\(base)/v1/chat/completions")
        case .openaiCompatible:
            // User provides full base URL, append /chat/completions if needed
            if base.hasSuffix("/chat/completions") {
                return URL(string: base)
            }
            let cleaned = base.hasSuffix("/v1") ? base : "\(base)/v1"
            return URL(string: "\(cleaned)/chat/completions")
        case .ollama:
            return URL(string: "\(base)/v1/chat/completions")
        }
    }

    // Exclude apiKey from Codable
    enum CodingKeys: String, CodingKey {
        case id, name, type, baseURL, modelName
        case supportsVision, supportsStreaming
        case isBuiltIn, isEnabled, isDefault, sortOrder
    }

    /// Built-in provider seeds
    static let builtInProviders: [ProviderConfig] = [
        // Local Ollama (default)
        ProviderConfig(
            name: "Ollama (本地)", type: .ollama,
            baseURL: "http://localhost:11434", modelName: "llama3.2",
            supportsVision: false, supportsStreaming: true,
            isBuiltIn: true, isEnabled: true, isDefault: true, sortOrder: 0
        ),
        // Claude
        ProviderConfig(
            name: "Claude", type: .claude,
            baseURL: "https://api.anthropic.com", modelName: "claude-sonnet-4-20250514",
            supportsVision: true, supportsStreaming: true,
            isBuiltIn: true, isEnabled: true, isDefault: false, sortOrder: 1
        ),
        // OpenAI
        ProviderConfig(
            name: "OpenAI", type: .openai,
            baseURL: "https://api.openai.com", modelName: "gpt-4o",
            supportsVision: true, supportsStreaming: true,
            isBuiltIn: true, isEnabled: true, isDefault: false, sortOrder: 2
        ),
        // DeepSeek
        ProviderConfig(
            name: "DeepSeek", type: .openaiCompatible,
            baseURL: "https://api.deepseek.com", modelName: "deepseek-chat",
            supportsVision: false, supportsStreaming: true,
            isBuiltIn: true, isEnabled: true, isDefault: false, sortOrder: 3
        ),
        // Kimi (Moonshot)
        ProviderConfig(
            name: "Kimi (月之暗面)", type: .openaiCompatible,
            baseURL: "https://api.moonshot.cn", modelName: "moonshot-v1-8k",
            supportsVision: false, supportsStreaming: true,
            isBuiltIn: true, isEnabled: true, isDefault: false, sortOrder: 4
        ),
        // Qwen
        ProviderConfig(
            name: "通义千问", type: .openaiCompatible,
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode", modelName: "qwen-turbo",
            supportsVision: false, supportsStreaming: true,
            isBuiltIn: true, isEnabled: true, isDefault: false, sortOrder: 5
        ),
    ]
}
