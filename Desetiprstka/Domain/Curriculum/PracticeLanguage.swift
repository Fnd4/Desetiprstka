import Foundation

/// Jazyk textů, ve kterém se cvičí. Nezávisí na jazyku rozhraní –
/// Čech může trénovat angličtinu a naopak.
enum PracticeLanguage: String, CaseIterable, Identifiable, Sendable {
    case czech = "cs"
    case english = "en"

    var id: String { rawValue }

    /// Název jazyka v něm samotném – stejný v každém jazyce rozhraní.
    var nativeName: String {
        switch self {
        case .czech: "Čeština"
        case .english: "English"
        }
    }

    var flag: String {
        switch self {
        case .czech: "🇨🇿"
        case .english: "🇬🇧"
        }
    }

    /// Rozložení, na kterých jde tímhle jazykem psát.
    /// Česká diakritika na anglické klávesnici není, angličtina jde psát na obou.
    var layouts: [KeyboardLayoutKind] {
        switch self {
        case .czech: [.czechQWERTZ, .czechQWERTY]
        case .english: [.usQWERTY, .ukQWERTY, .czechQWERTZ, .czechQWERTY]
        }
    }

    var defaultLayout: KeyboardLayoutKind {
        switch self {
        case .czech:
            return .czechQWERTZ
        case .english:
            let region = Locale.current.region?.identifier
            return region == "GB" || region == "IE" ? .ukQWERTY : .usQWERTY
        }
    }

    var wordBank: WordBank {
        switch self {
        case .czech: .czech
        case .english: .english
        }
    }

    /// Jazyk cvičení zvolený v Nastavení.
    static var current: PracticeLanguage {
        UserDefaults.standard.string(forKey: SettingsKey.practiceLanguage).flatMap(PracticeLanguage.init) ?? systemDefault
    }

    /// Výchozí jazyk podle macOS: čeština a slovenština → čeština, jinak angličtina.
    static var systemDefault: PracticeLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("cs") || preferred.hasPrefix("sk") ? .czech : .english
    }

    /// Při prvním spuštění nastaví jazyk cvičení a klávesnici podle systému.
    /// Uložená volba uživatele má vždy přednost.
    static func registerDefaults(in defaults: UserDefaults = .standard) {
        // Kdo používal verzi před angličtinou, cvičil česky – nechme mu to.
        let usedBefore = defaults.dictionaryRepresentation().keys.contains {
            $0.hasPrefix("settings.") || $0.hasPrefix("appearance.") || $0.hasPrefix("home.") || $0.hasPrefix("modes.")
        }
        if defaults.object(forKey: SettingsKey.practiceLanguage) == nil, usedBefore {
            defaults.set(PracticeLanguage.czech.rawValue, forKey: SettingsKey.practiceLanguage)
        }
        defaults.register(defaults: [SettingsKey.practiceLanguage: systemDefault.rawValue])
        // Rozložení musí patřit k jazyku cvičení, jinak by ho Nastavení neukázalo.
        let language = PracticeLanguage.current
        defaults.register(defaults: [SettingsKey.keyboardLayout: language.defaultLayout.rawValue])
        if let raw = defaults.string(forKey: SettingsKey.keyboardLayout),
           let kind = KeyboardLayoutKind(rawValue: raw), !language.layouts.contains(kind) {
            defaults.set(language.defaultLayout.rawValue, forKey: SettingsKey.keyboardLayout)
        }
    }
}
