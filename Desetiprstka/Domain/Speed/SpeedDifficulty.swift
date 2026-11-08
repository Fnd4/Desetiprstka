import Foundation

/// Rychlostní obtížnost – nezávislá na obtížnosti textu (písmena + typ cvičení).
enum SpeedDifficulty: String, CaseIterable, Identifiable, Codable, Sendable {
    case relaxed
    case easy
    case normal
    case hard
    case expert
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed: String(localized: "Relaxed")
        case .easy: String(localized: "Easy")
        case .normal: String(localized: "Normal")
        case .hard: String(localized: "Hard")
        case .expert: String(localized: "Expert")
        case .custom: String(localized: "Custom")
        }
    }

    var subtitle: String {
        switch self {
        case .relaxed: String(localized: "Bez tlaku na rychlost – rozhoduje jen přesnost")
        case .easy: String(localized: "Klidné tempo pro začátečníky")
        case .normal: String(localized: "Plynulé psaní")
        case .hard: String(localized: "Rychlé psaní")
        case .expert: String(localized: "Profesionální tempo")
        case .custom: String(localized: "Vlastní cílové WPM")
        }
    }

    var symbol: String {
        switch self {
        case .relaxed: "leaf"
        case .easy: "tortoise"
        case .normal: "figure.walk"
        case .hard: "figure.run"
        case .expert: "hare"
        case .custom: "slider.horizontal.3"
        }
    }

    /// Pevné cílové WPM režimu. `nil` = bez cíle (Relaxed) nebo vlastní hodnota (Custom).
    var presetWPM: Double? {
        switch self {
        case .relaxed, .custom: nil
        case .easy: 12
        case .normal: 20
        case .hard: 35
        case .expert: 55
        }
    }

    /// Pořadí přednastavených režimů od nejlehčího.
    static let presets: [SpeedDifficulty] = [.relaxed, .easy, .normal, .hard, .expert]

    var harder: SpeedDifficulty? {
        guard let index = Self.presets.firstIndex(of: self), index + 1 < Self.presets.count else { return nil }
        return Self.presets[index + 1]
    }

    var easier: SpeedDifficulty? {
        guard let index = Self.presets.firstIndex(of: self), index > 0 else { return nil }
        return Self.presets[index - 1]
    }

    static let customRange: ClosedRange<Double> = 5...150
}

/// Konkrétní nastavení rychlosti (režim + případná vlastní hodnota).
struct SpeedSetting: Equatable, Hashable, Sendable {
    var mode: SpeedDifficulty
    var customWPM: Double

    /// Cílové WPM, nebo `nil` u Relaxed.
    var targetWPM: Double? {
        switch mode {
        case .relaxed: nil
        case .custom: min(max(customWPM, SpeedDifficulty.customRange.lowerBound), SpeedDifficulty.customRange.upperBound)
        default: mode.presetWPM
        }
    }

    var label: String {
        if let targetWPM { return "\(mode.title) · \(SpeedUnit.current.label(targetWPM))" }
        return mode.title
    }

    static let `default` = SpeedSetting(mode: .easy, customWPM: 25)
}

/// Návrh na změnu rychlostní obtížnosti.
struct SpeedRecommendation: Equatable, Sendable {
    enum Direction: Equatable, Sendable {
        case up
        case down
    }

    let direction: Direction
    let suggested: SpeedSetting
    let reason: String

    var actionTitle: String {
        String(localized: "Přepnout na \(suggested.label)")
    }
}

/// Výkon z jednoho cvičení pro vyhodnocení rychlosti.
struct SpeedSample: Sendable {
    let wpm: Double
    let accuracy: Double
}

/// Doporučuje zvýšení nebo snížení rychlostní obtížnosti podle posledních výsledků.
struct SpeedAdvisor {
    /// Kolik posledních cvičení se bere v úvahu.
    var window = 5
    /// Kolik z nich musí splnit podmínku.
    var requiredHits = 3

    func recommend(current: SpeedSetting, recent: [SpeedSample]) -> SpeedRecommendation? {
        let samples = Array(recent.prefix(window))
        guard samples.count >= requiredHits else { return nil }

        // Relaxed nemá cíl → porovnáme s režimem Easy.
        guard let target = current.targetWPM ?? SpeedDifficulty.easy.presetWPM else { return nil }

        let fastAndAccurate = samples.filter { $0.wpm >= target * 1.25 && $0.accuracy >= 0.95 }.count
        let tooSlow = samples.filter { $0.wpm < target * 0.7 }.count

        if current.mode == .relaxed {
            guard fastAndAccurate >= requiredHits else { return nil }
            return SpeedRecommendation(
                direction: .up,
                suggested: SpeedSetting(mode: .easy, customWPM: current.customWPM),
                reason: String(localized: "Píšeš přesně a svižně. Zkus mírný tlak na rychlost.")
            )
        }

        if fastAndAccurate >= requiredHits {
            let suggested: SpeedSetting
            if current.mode == .custom {
                suggested = SpeedSetting(mode: .custom, customWPM: min(target + 5, SpeedDifficulty.customRange.upperBound))
            } else if let harder = current.mode.harder {
                suggested = SpeedSetting(mode: harder, customWPM: current.customWPM)
            } else {
                return nil
            }
            guard suggested != current else { return nil }
            return SpeedRecommendation(
                direction: .up,
                suggested: suggested,
                reason: String(localized: "V posledních cvičeních jsi cíl \(Int(target)) WPM výrazně překonal při přesnosti nad 95 %.")
            )
        }

        if tooSlow >= requiredHits {
            let suggested: SpeedSetting
            if current.mode == .custom {
                suggested = SpeedSetting(mode: .custom, customWPM: max(target - 5, SpeedDifficulty.customRange.lowerBound))
            } else if let easier = current.mode.easier {
                suggested = SpeedSetting(mode: easier, customWPM: current.customWPM)
            } else {
                return nil
            }
            guard suggested != current else { return nil }
            return SpeedRecommendation(
                direction: .down,
                suggested: suggested,
                reason: String(localized: "Cíl \(Int(target)) WPM je teď příliš vysoko. Nižší tempo ti pomůže psát přesněji.")
            )
        }
        return nil
    }
}

extension ExerciseStage {
    /// Kombinace znaků se píšou přirozeně pomaleji než věty.
    /// Cílová rychlost pro postup v textu se proto podle typu cvičení mírně snižuje.
    var speedFactor: Double {
        switch self {
        case .combinations: 0.7
        case .shortWords: 0.85
        case .longWords: 0.95
        case .sentences: 1.0
        }
    }
}
