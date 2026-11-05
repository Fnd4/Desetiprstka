import AppKit
import SwiftUI

/// Barvy jednoho tématu. Views je čtou z prostředí přes `@Environment(\.theme)`.
struct ThemeColors: Equatable {
    /// `nil` = nativní pozadí okna macOS.
    var background: Color?
    var cardBackground: Color
    var cardBorder: Color
    var accent: Color
    var secondaryAccent: Color
    /// `nil` = systémová barva textu.
    var textPrimary: Color?
    var textSecondary: Color
    /// Aktuální znak při psaní.
    var typingHighlight: Color
    var progressTrack: Color
    /// Papírová varianta obrazovky psaní.
    var paper: Color
    var paperText: Color
    /// `nil` = podle systému.
    var colorScheme: ColorScheme?
}

// MARK: - Pomocníci pro barvy

extension Color {
    /// Barva ze 24bitového hex čísla, např. `0x0E1220`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(nsColor: NSColor(hex: hex, alpha: opacity))
    }

    /// Barva, která se sama přepne mezi světlým a tmavým vzhledem.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}

// MARK: - Prostředí

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = AppTheme.system.colors(accent: nil)
}

extension EnvironmentValues {
    var theme: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}
