import Foundation

/// Jednotka rychlosti v celé aplikaci.
///
/// - `wpm` = slova za minutu (5 znaků = 1 slovo) – USA, UK a většina světa
/// - `cpm` = znaky za minutu – Německo, Polsko, Rusko, Asie
/// - `strokes` = úhozy za minutu (KPM), jak se počítá v českých a slovenských školách
///   (velké písmeno a znak na Shiftu = 2 úhozy)
enum SpeedUnit: String, CaseIterable, Identifiable, Sendable {
    case wpm
    case cpm
    case strokes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wpm: String(localized: "Slova za minutu (WPM)")
        case .cpm: String(localized: "Znaky za minutu (CPM)")
        case .strokes: String(localized: "Úhozy za minutu (KPM)")
        }
    }

    /// Kde se jednotka používá.
    var region: String {
        switch self {
        case .wpm: String(localized: "Mezinárodní standard – USA, UK, Monkeytype, 10FastFingers")
        case .cpm: String(localized: "Německo, Polsko, Rusko, Asie")
        case .strokes: String(localized: "České a slovenské školy, ZAV, státní zkoušky")
        }
    }

    /// Krátký popisek za číslem.
    var symbol: String {
        switch self {
        case .wpm: String(localized: "WPM")
        case .cpm: String(localized: "CPM")
        case .strokes: String(localized: "úh./min")
        }
    }

    /// Převod z WPM tam, kde nemáme přesný počet úhozů (cíle, průměry).
    /// 1 WPM = 5 znaků za minutu; úhozy navíc za Shift jsou v běžném textu zanedbatelné.
    func value(fromWPM wpm: Double) -> Double {
        switch self {
        case .wpm: wpm
        case .cpm, .strokes: wpm * 5
        }
    }

    /// Hodnota v jednotce. Pro úhozy se použije přesná hodnota, pokud je k dispozici.
    func value(wpm: Double, strokesPerMinute: Double?) -> Double {
        switch self {
        case .wpm: wpm
        case .cpm: wpm * 5
        case .strokes: strokesPerMinute ?? wpm * 5
        }
    }

    func format(_ wpm: Double, strokesPerMinute: Double? = nil) -> String {
        Format.wpm(value(wpm: wpm, strokesPerMinute: strokesPerMinute))
    }

    /// „35 WPM“ / „175 úh./min“
    func label(_ wpm: Double, strokesPerMinute: Double? = nil) -> String {
        "\(format(wpm, strokesPerMinute: strokesPerMinute)) \(symbol)"
    }

    /// Aktuální volba z Nastavení (pro místa mimo SwiftUI).
    static var current: SpeedUnit {
        SpeedUnit(rawValue: UserDefaults.standard.string(forKey: SettingsKey.speedUnit) ?? "") ?? .wpm
    }
}
