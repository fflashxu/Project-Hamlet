import SwiftUI
import Combine

struct WarmTheme: HamletTheme {
    let name = "Warm"
    let background    = Color(hex: "#FAFAF8")
    let surface       = Color(hex: "#FFFFFF")
    let surfaceSecondary = Color(hex: "#F5F4F0")
    let primary       = Color(hex: "#C8956C")
    let textPrimary   = Color(hex: "#1A1714")
    let textSecondary = Color(hex: "#6B6560")
    let textTertiary  = Color(hex: "#B0AAA4")
    let border        = Color(hex: "#E8E4DF")
    let glow          = Color(hex: "#C8956C")
}

struct ProfessionalTheme: HamletTheme {
    let name = "Professional"
    let background    = Color(hex: "#0F1117")
    let surface       = Color(hex: "#1A1D27")
    let surfaceSecondary = Color(hex: "#232736")
    let primary       = Color(hex: "#5B8DEF")
    let textPrimary   = Color(hex: "#E8EAF0")
    let textSecondary = Color(hex: "#8B90A0")
    let textTertiary  = Color(hex: "#4A4F60")
    let border        = Color(hex: "#2A2F42")
    let glow          = Color(hex: "#5B8DEF")
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
