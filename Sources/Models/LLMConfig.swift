import Foundation

struct LLMConfig: Codable, Equatable {
    var baseURL: String = ""
    var apiKey: String = ""
    var modelName: String = ""

    private enum CodingKeys: String, CodingKey {
        case baseURL, modelName
    }

    init(baseURL: String = "", apiKey: String = "", modelName: String = "") {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.modelName = modelName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        modelName = try container.decodeIfPresent(String.self, forKey: .modelName) ?? ""
        apiKey = KeychainHelper.load(forKey: "llm_api_key") ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(modelName, forKey: .modelName)
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
