import SwiftUI

/// Témata aplikace.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case midnight
    case graphite
    case paper
    case ocean
    case forest
    case warm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .midnight: String(localized: "Midnight")
        case .graphite: String(localized: "Graphite")
        case .paper: String(localized: "Paper")
        case .ocean: String(localized: "Ocean")
        case .forest: String(localized: "Forest")
        case .warm: String(localized: "Warm")
        }
    }

    var subtitle: String {
        switch self {
        case .system: String(localized: "Podle macOS")
        case .midnight: String(localized: "Vždy tmavé")
        case .graphite: String(localized: "Neutrální šedá")
        case .paper: String(localized: "Krémový papír")
        case .ocean: String(localized: "Chladná modrá")
        case .forest: String(localized: "Klidná zelená")
        case .warm: String(localized: "Teplé tóny")
        }
    }

    /// Barvy tématu. `accent` = vlastní volba uživatele (nil = accent tématu).
    func colors(accent override: Color?) -> ThemeColors {
        var colors = baseColors
        if let override {
            colors.accent = override
            colors.typingHighlight = override
        }
        return colors
    }

    private var baseColors: ThemeColors {
        switch self {
        case .system:
            return ThemeColors(
                background: nil,
                cardBackground: Color.primary.opacity(0.04),
                cardBorder: Color.primary.opacity(0.07),
                accent: .accentColor,
                secondaryAccent: .secondary,
                textPrimary: nil,
                textSecondary: .secondary,
                typingHighlight: .accentColor,
                progressTrack: Color.primary.opacity(0.1),
                paper: Color(light: 0xF8F4EA, dark: 0x25221D),
                paperText: Color(light: 0x2B2620, dark: 0xE8E1D3),
                colorScheme: nil
            )
        case .midnight:
            return ThemeColors(
                background: Color(hex: 0x0E1220),
                cardBackground: Color(hex: 0x171C2E),
                cardBorder: Color(hex: 0x262C44),
                accent: Color(hex: 0x8B9BFF),
                secondaryAccent: Color(hex: 0x5ED6C6),
                textPrimary: Color(hex: 0xE6E8F0),
                textSecondary: Color(hex: 0x8A90A6),
                typingHighlight: Color(hex: 0x8B9BFF),
                progressTrack: Color(hex: 0x262C44),
                paper: Color(hex: 0x161A28),
                paperText: Color(hex: 0xDCDFEA),
                colorScheme: .dark
            )
        case .graphite:
            return ThemeColors(
                background: Color(light: 0xEDEDEF, dark: 0x1C1C1E),
                cardBackground: Color(light: 0xF8F8F9, dark: 0x2A2A2D),
                cardBorder: Color(light: 0xDCDCE0, dark: 0x3A3A3E),
                accent: Color(light: 0x5B6878, dark: 0xA3AEBC),
                secondaryAccent: Color(light: 0x8E8E93, dark: 0x8E8E93),
                textPrimary: Color(light: 0x1D1D1F, dark: 0xECECEE),
                textSecondary: Color(light: 0x6E6E73, dark: 0x98989D),
                typingHighlight: Color(light: 0x3A4654, dark: 0xC9D2DD),
                progressTrack: Color(light: 0xDCDCE0, dark: 0x3A3A3E),
                paper: Color(light: 0xF4F4F5, dark: 0x252527),
                paperText: Color(light: 0x1D1D1F, dark: 0xE5E5E7),
                colorScheme: nil
            )
        case .paper:
            return ThemeColors(
                background: Color(light: 0xF4EFE4, dark: 0x1D1A16),
                cardBackground: Color(light: 0xFBF8F1, dark: 0x27231E),
                cardBorder: Color(light: 0xE4DCCB, dark: 0x3A342C),
                accent: Color(light: 0xA65E2E, dark: 0xD9A066),
                secondaryAccent: Color(light: 0x6F7F5E, dark: 0xA3B48E),
                textPrimary: Color(light: 0x2B2620, dark: 0xEDE6D8),
                textSecondary: Color(light: 0x7A6F60, dark: 0xA89E8E),
                typingHighlight: Color(light: 0xA65E2E, dark: 0xE0AA70),
                progressTrack: Color(light: 0xE4DCCB, dark: 0x3A342C),
                paper: Color(light: 0xFDFBF5, dark: 0x25211C),
                paperText: Color(light: 0x2B2620, dark: 0xEDE6D8),
                colorScheme: nil
            )
        case .ocean:
            return ThemeColors(
                background: Color(light: 0xEDF4F7, dark: 0x0B1820),
                cardBackground: Color(light: 0xF8FBFC, dark: 0x12242D),
                cardBorder: Color(light: 0xD5E4EB, dark: 0x1E3743),
                accent: Color(light: 0x0E7490, dark: 0x38BDF8),
                secondaryAccent: Color(light: 0x2A9D8F, dark: 0x5EEAD4),
                textPrimary: Color(light: 0x0F2530, dark: 0xE2EEF3),
                textSecondary: Color(light: 0x557380, dark: 0x8AA6B3),
                typingHighlight: Color(light: 0x0E7490, dark: 0x5CCBFA),
                progressTrack: Color(light: 0xD5E4EB, dark: 0x1E3743),
                paper: Color(light: 0xFAFDFE, dark: 0x10212A),
                paperText: Color(light: 0x0F2530, dark: 0xE2EEF3),
                colorScheme: nil
            )
        case .forest:
            return ThemeColors(
                background: Color(light: 0xEFF3EC, dark: 0x0F1912),
                cardBackground: Color(light: 0xF8FAF6, dark: 0x18241B),
                cardBorder: Color(light: 0xD8E2D2, dark: 0x263829),
                accent: Color(light: 0x2F7D4F, dark: 0x6FCF97),
                secondaryAccent: Color(light: 0x8A6D3B, dark: 0xD4B483),
                textPrimary: Color(light: 0x1B2A1F, dark: 0xE3ECE4),
                textSecondary: Color(light: 0x5C6F5F, dark: 0x8FA593),
                typingHighlight: Color(light: 0x2F7D4F, dark: 0x7FD9A4),
                progressTrack: Color(light: 0xD8E2D2, dark: 0x263829),
                paper: Color(light: 0xFAFCF8, dark: 0x16211A),
                paperText: Color(light: 0x1B2A1F, dark: 0xE3ECE4),
                colorScheme: nil
            )
        case .warm:
            return ThemeColors(
                background: Color(light: 0xFAF2EA, dark: 0x1E1612),
                cardBackground: Color(light: 0xFFF9F3, dark: 0x2A1F19),
                cardBorder: Color(light: 0xEEDCCB, dark: 0x3D2D24),
                accent: Color(light: 0xD2602A, dark: 0xF2995E),
                secondaryAccent: Color(light: 0xB2456E, dark: 0xE88AAE),
                textPrimary: Color(light: 0x2E211A, dark: 0xF1E5DC),
                textSecondary: Color(light: 0x84705F, dark: 0xB09C8D),
                typingHighlight: Color(light: 0xD2602A, dark: 0xF5A672),
                progressTrack: Color(light: 0xEEDCCB, dark: 0x3D2D24),
                paper: Color(light: 0xFFFBF6, dark: 0x271D17),
                paperText: Color(light: 0x2E211A, dark: 0xF1E5DC),
                colorScheme: nil
            )
        }
    }
}

/// Volba accent barvy nezávisle na tématu.
enum AccentChoice: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case blue
    case purple
    case green
    case orange
    case pink
    case red

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: String(localized: "Automatic")
        case .blue: String(localized: "Blue")
        case .purple: String(localized: "Purple")
        case .green: String(localized: "Green")
        case .orange: String(localized: "Orange")
        case .pink: String(localized: "Pink")
        case .red: String(localized: "Red")
        }
    }

    /// `nil` = accent podle tématu.
    var color: Color? {
        switch self {
        case .automatic: nil
        case .blue: .blue
        case .purple: .purple
        case .green: .green
        case .orange: .orange
        case .pink: .pink
        case .red: .red
        }
    }
}

/// Vizuální varianta obrazovky psaní.
enum TypingStyle: String, CaseIterable, Identifiable, Sendable {
    case standard
    case focus
    case minimal
    case paper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: String(localized: "Default")
        case .focus: String(localized: "Focus")
        case .minimal: String(localized: "Minimal")
        case .paper: String(localized: "Paper")
        }
    }

    var subtitle: String {
        switch self {
        case .standard: String(localized: "Text, metriky, klávesnice a ruce")
        case .focus: String(localized: "Text, průběh, WPM a přesnost")
        case .minimal: String(localized: "Jen text, kurzor a čas")
        case .paper: String(localized: "Text na čistém papíře")
        }
    }

    var symbol: String {
        switch self {
        case .standard: "keyboard"
        case .focus: "eye"
        case .minimal: "text.cursor"
        case .paper: "doc.text"
        }
    }

    /// Zobrazuje se klávesnice a ruce (pokud je uživatel nevypnul).
    var showsKeyboard: Bool { self == .standard || self == .paper }
}
