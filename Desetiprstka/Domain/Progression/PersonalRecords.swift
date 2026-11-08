import Foundation

/// Druhy osobních rekordů.
enum RecordKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case bestWPM
    case bestAccuracy
    case longestCombo
    case timeAttack15
    case timeAttack30
    case timeAttack60
    case timeAttack120
    case sprint
    case survival
    case mostCharacters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bestWPM: String(localized: "Nejvyšší rychlost")
        case .bestAccuracy: String(localized: "Nejlepší přesnost")
        case .longestCombo: String(localized: "Nejdelší combo")
        case .timeAttack15: String(localized: "Time Attack 15 s")
        case .timeAttack30: String(localized: "Time Attack 30 s")
        case .timeAttack60: String(localized: "Time Attack 60 s")
        case .timeAttack120: String(localized: "Time Attack 120 s")
        case .sprint: String(localized: "Nejlepší Sprint")
        case .survival: String(localized: "Nejlepší Survival")
        case .mostCharacters: String(localized: "Nejvíc znaků v jednom cvičení")
        }
    }

    var symbol: String {
        switch self {
        case .bestWPM: "speedometer"
        case .bestAccuracy: "target"
        case .longestCombo: "bolt"
        case .timeAttack15, .timeAttack30, .timeAttack60, .timeAttack120: "timer"
        case .sprint: "flag.checkered"
        case .survival: "heart"
        case .mostCharacters: "text.alignleft"
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .bestWPM, .sprint: SpeedUnit.current.label(value)
        case .bestAccuracy: Format.percent(value)
        case .longestCombo: String(localized: "\(Int(value)) znaků")
        case .timeAttack15, .timeAttack30, .timeAttack60, .timeAttack120, .mostCharacters: String(localized: "\(Int(value)) znaků")
        case .survival: String(localized: "\(Int(value)) bodů")
        }
    }

    static func timeAttack(_ duration: Int) -> RecordKind? {
        switch duration {
        case 15: .timeAttack15
        case 30: .timeAttack30
        case 60: .timeAttack60
        case 120: .timeAttack120
        default: nil
        }
    }
}

enum RecordEvaluator {
    static let minimumCharactersForWPM = 40
    static let minimumCharactersForAccuracy = 100

    /// Hodnoty z cvičení, které mohou být rekordem.
    static func candidates(for result: SessionResult) -> [RecordKind: Double] {
        var values: [RecordKind: Double] = [:]
        if result.characters >= minimumCharactersForWPM {
            values[.bestWPM] = result.wpm
        }
        if result.characters >= minimumCharactersForAccuracy {
            values[.bestAccuracy] = result.accuracy
        }
        if result.maxCombo > 0 {
            values[.longestCombo] = Double(result.maxCombo)
        }
        if result.characters > 0 {
            values[.mostCharacters] = Double(result.characters)
        }

        switch result.mode {
        case .timeAttack:
            if let limit = result.timeLimit, let kind = RecordKind.timeAttack(limit) {
                values[kind] = Double(result.displayScore)
            }
        case .sprint:
            if result.completed { values[.sprint] = result.wpm }
        case .survival:
            values[.survival] = Double(result.displayScore)
        case .practice, .accuracyChallenge, .endless, .exam, .customText, .speedTest:
            break
        }
        return values
    }

    /// Je nová hodnota lepší než dosavadní rekord?
    static func isImprovement(_ value: Double, over existing: Double, kind: RecordKind) -> Bool {
        switch kind {
        case .bestAccuracy: value > existing + 0.000_1
        case .bestWPM, .sprint: value >= existing + 0.5
        default: value > existing
        }
    }
}
