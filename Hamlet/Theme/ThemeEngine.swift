import SwiftUI
import Combine

// MARK: - Theme Protocol

protocol HamletTheme {
    var name: String { get }
    var background: Color { get }
    var surface: Color { get }
    var surfaceSecondary: Color { get }
    var primary: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var border: Color { get }
    var glow: Color { get }
}

// MARK: - Theme Types

enum ThemeType: String, CaseIterable {
    case warm = "warm"
    case professional = "professional"

    var displayName: String {
        switch self {
        case .warm: return "Warm"
        case .professional: return "Professional"
        }
    }

    var unlockDescription: String {
        switch self {
        case .warm: return "Default theme"
        case .professional: return "Unlocked by analytical thinking patterns"
        }
    }

    func theme() -> any HamletTheme {
        switch self {
        case .warm: return WarmTheme()
        case .professional: return ProfessionalTheme()
        }
    }
}

// MARK: - Theme Engine

class ThemeEngine: ObservableObject {
    static let shared = ThemeEngine()

    @Published var current: ThemeType = .warm
    @Published var unlockedThemes: Set<ThemeType> = [.warm]

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "current_theme"),
           let type = ThemeType(rawValue: saved) {
            current = type
        }
        loadUnlocked()
    }

    var theme: any HamletTheme { current.theme() }

    func apply(_ type: ThemeType) {
        guard unlockedThemes.contains(type) else { return }
        current = type
        UserDefaults.standard.set(type.rawValue, forKey: "current_theme")
    }

    func unlock(_ type: ThemeType) {
        unlockedThemes.insert(type)
        saveUnlocked()
    }

    private func saveUnlocked() {
        let raw = unlockedThemes.map { $0.rawValue }
        UserDefaults.standard.set(raw, forKey: "unlocked_themes")
    }

    private func loadUnlocked() {
        guard let raw = UserDefaults.standard.stringArray(forKey: "unlocked_themes") else { return }
        unlockedThemes = Set(raw.compactMap { ThemeType(rawValue: $0) })
        unlockedThemes.insert(.warm)
    }
}
