import Foundation

enum ProviderType: String, Codable, CaseIterable, Identifiable {
    case claude
    case openai
    case openaiCompatible = "openai_compatible"
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        case .openaiCompatible: return "OpenAI 兼容"
        case .ollama: return "Ollama (本地)"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .claude: return "https://api.anthropic.com"
        case .openai: return "https://api.openai.com"
        case .openaiCompatible: return ""
        case .ollama: return "http://localhost:11434"
        }
    }

    var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-20250514"
        case .openai: return "gpt-4o"
        case .openaiCompatible: return ""
        case .ollama: return "llama3.2"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .claude, .openai, .openaiCompatible: return true
        case .ollama: return false
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .openai: return "globe"
        case .openaiCompatible: return "server.rack"
        case .ollama: return "desktopcomputer"
        }
    }

    var iconColor: String {
        switch self {
        case .claude: return "#D97706"
        case .openai: return "#10A37F"
        case .openaiCompatible: return "#6366F1"
        case .ollama: return "#3B82F6"
        }
    }
}
