import AppKit
import Observation
import SwiftUI

/// Centrální správa vzhledu. Výběr se ukládá a aplikuje okamžitě bez restartu.
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private enum Key {
        static let theme = "appearance.theme"
        static let accent = "appearance.accent"
        static let typingStyle = "appearance.typingStyle"
        static let cursorStyle = "appearance.cursorStyle"
        static let comboEffect = "appearance.comboEffect"
    }

    var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Key.theme)
            applyAppearance()
        }
    }

    var accent: AccentChoice {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: Key.accent) }
    }

    var typingStyle: TypingStyle {
        didSet { UserDefaults.standard.set(typingStyle.rawValue, forKey: Key.typingStyle) }
    }

    var cursorStyle: CursorStyle {
        didSet { UserDefaults.standard.set(cursorStyle.rawValue, forKey: Key.cursorStyle) }
    }

    var comboEffect: ComboEffect {
        didSet { UserDefaults.standard.set(comboEffect.rawValue, forKey: Key.comboEffect) }
    }

    private init() {
        let defaults = UserDefaults.standard
        theme = AppTheme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .system
        accent = AccentChoice(rawValue: defaults.string(forKey: Key.accent) ?? "") ?? .automatic
        cursorStyle = CursorStyle(rawValue: defaults.string(forKey: Key.cursorStyle) ?? "") ?? .underline
        comboEffect = ComboEffect(rawValue: defaults.string(forKey: Key.comboEffect) ?? "") ?? .classic
        // Původní přepínač Focus Mode se převede na novou variantu.
        if let raw = defaults.string(forKey: Key.typingStyle), let style = TypingStyle(rawValue: raw) {
            typingStyle = style
        } else {
            typingStyle = defaults.bool(forKey: SettingsKey.focusMode) ? .focus : .standard
        }
    }

    var colors: ThemeColors { theme.colors(accent: accent.color) }

    /// Vzhled oken řídí AppKit. `.preferredColorScheme(nil)` po tmavém tématu
    /// okna na macOS nevrací zpět do systémového režimu, proto `NSApp.appearance`.
    func applyAppearance() {
        guard let app = NSApp else { return }
        let appearance: NSAppearance? = switch colors.colorScheme {
        case .dark: NSAppearance(named: .darkAqua)
        case .light: NSAppearance(named: .aqua)
        default: nil
        }
        if app.appearance?.name != appearance?.name { app.appearance = appearance }
    }

    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    func select(_ theme: AppTheme) {
        withAnimation(Self.reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            self.theme = theme
        }
    }

    func select(_ accent: AccentChoice) {
        withAnimation(Self.reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            self.accent = accent
        }
    }
}

/// Aplikuje téma na celý strom views (okno aplikace i Nastavení).
struct ThemedRoot: ViewModifier {
    let manager: ThemeManager

    func body(content: Content) -> some View {
        let colors = manager.colors
        content
            .environment(\.theme, colors)
            .tint(colors.accent)
            .progressViewStyle(ThemedProgressStyle())
            .foregroundStyle(colors.textPrimary ?? Color.primary)
            .onAppear { manager.applyAppearance() }
    }
}

extension View {
    func themed(_ manager: ThemeManager) -> some View {
        modifier(ThemedRoot(manager: manager))
    }

    /// Pozadí podle tématu (u System zůstává nativní).
    @ViewBuilder
    func themeBackground(_ colors: ThemeColors) -> some View {
        if let background = colors.background {
            self.background(background.ignoresSafeArea())
        } else {
            self
        }
    }
}
