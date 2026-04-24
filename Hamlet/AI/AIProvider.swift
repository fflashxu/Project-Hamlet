import Foundation
import Combine

// MARK: - AI Provider Protocol

protocol AIProvider {
    var name: String { get }
    var requiresAPIKey: Bool { get }
    func extractSignals(from text: String) async throws -> [SignalData]
    func extractSignals(from text: String, additionalContext: String) async throws -> [SignalData]
}

// MARK: - Provider Registry

enum AIProviderType: String, CaseIterable, Identifiable {
    case claude = "claude"
    case qwen = "qwen"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .qwen: return "Qwen (Alibaba)"
        }
    }

    var baseURL: String {
        switch self {
        case .claude: return "https://api.anthropic.com/v1/messages"
        case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        }
    }

    var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-6"
        case .qwen: return "qwen-plus"
        }
    }
}

// MARK: - API Key Storage

class APIKeyStore {
    static let shared = APIKeyStore()
    private let defaults = UserDefaults.standard

    private init() {}

    func save(key: String, for provider: AIProviderType) {
        defaults.set(key, forKey: "apikey_\(provider.rawValue)")
    }

    func get(for provider: AIProviderType) -> String? {
        let key = defaults.string(forKey: "apikey_\(provider.rawValue)")
        return (key?.isEmpty == false) ? key : nil
    }

    func remove(for provider: AIProviderType) {
        defaults.removeObject(forKey: "apikey_\(provider.rawValue)")
    }
}

// MARK: - Provider Manager

class AIProviderManager: ObservableObject {
    static let shared = AIProviderManager()

    @Published var selectedProvider: AIProviderType = .claude

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "selected_provider"),
           let type = AIProviderType(rawValue: saved) {
            selectedProvider = type
        }
    }

    func select(_ provider: AIProviderType) {
        selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "selected_provider")
    }

    func currentProvider() -> any AIProvider {
        switch selectedProvider {
        case .claude: return ClaudeProvider()
        case .qwen: return QwenProvider()
        }
    }

    var hasAPIKey: Bool {
        APIKeyStore.shared.get(for: selectedProvider) != nil
    }
}

// MARK: - Signal Extraction Error

enum AIError: LocalizedError {
    case missingAPIKey
    case networkError(String)
    case parseError
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Please add your API key in Settings"
        case .networkError(let msg): return "Network error: \(msg)"
        case .parseError: return "Could not parse AI response"
        case .rateLimited: return "Rate limited, please try again later"
        }
    }
}
