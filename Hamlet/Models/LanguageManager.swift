import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case chinese = "zh"
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .chinese: return "中文"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    var resolvedCode: String {
        if self == .system {
            return Locale.current.language.languageCode?.identifier ?? "en"
        }
        return rawValue
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var current: AppLanguage = .system

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let lang = AppLanguage(rawValue: saved) {
            current = lang
        }
    }

    func set(_ language: AppLanguage) {
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: "app_language")
    }

    var langCode: String { current.resolvedCode }
}
