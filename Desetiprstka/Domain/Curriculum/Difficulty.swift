import Foundation

/// Typ cvičení – postupně od kombinací znaků po celé věty.
enum ExerciseStage: Int, CaseIterable, Identifiable, Codable, Comparable, Sendable {
    case combinations
    case shortWords
    case longWords
    case sentences

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .combinations: "Kombinace znaků"
        case .shortWords: "Krátká slova"
        case .longWords: "Dlouhá slova"
        case .sentences: "Věty"
        }
    }

    var shortTitle: String {
        switch self {
        case .combinations: "Znaky"
        case .shortWords: "Krátká"
        case .longWords: "Dlouhá"
        case .sentences: "Věty"
        }
    }

    var symbol: String {
        switch self {
        case .combinations: "square.grid.2x2"
        case .shortWords: "textformat.abc"
        case .longWords: "textformat"
        case .sentences: "text.alignleft"
        }
    }

    /// Cílová rychlost pro postup na nejnižším podstupni.
    var baseTargetWPM: Double {
        switch self {
        case .combinations: 8
        case .shortWords: 12
        case .longWords: 15
        case .sentences: 18
        }
    }

    static func < (lhs: ExerciseStage, rhs: ExerciseStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Obtížnost 1–12. Každý stupeň cvičení má 3 podúrovně.
struct Difficulty: Hashable, Codable, Sendable {
    static let levelsPerStage = 3
    static let maxLevel = ExerciseStage.allCases.count * levelsPerStage
    static let range = 1...maxLevel
    /// První úroveň stupně Věty.
    static let firstSentenceLevel = ExerciseStage.sentences.rawValue * levelsPerStage + 1
    /// Krátká a středně dlouhá slova (3–5 písmen) – jako testy na Monkeytype.
    static let speedTestLevel = ExerciseStage.shortWords.rawValue * levelsPerStage + 3

    let level: Int

    init(level: Int) {
        self.level = min(max(level, Self.range.lowerBound), Self.range.upperBound)
    }

    var stage: ExerciseStage {
        ExerciseStage(rawValue: (level - 1) / Self.levelsPerStage) ?? .combinations
    }

    /// 0, 1 nebo 2 – jemnější krok uvnitř stupně.
    var subLevel: Int { (level - 1) % Self.levelsPerStage }

    var targetWPM: Double { stage.baseTargetWPM + Double(subLevel) * 2 }

    var title: String { "Úroveň \(level)" }

    var raised: Difficulty { Difficulty(level: level + 1) }
    var lowered: Difficulty { Difficulty(level: level - 1) }
}
