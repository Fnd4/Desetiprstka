import Foundation
import SwiftData

/// Jedno dokončené cvičení v historii.
@Model
final class PracticeSession {
    var date: Date = Date()
    var duration: Double = 0
    var wpm: Double = 0
    /// Přesnost 0–1.
    var accuracy: Double = 1
    var errorCount: Int = 0
    var keystrokes: Int = 0
    var characterCount: Int = 0
    var level: Int = 1
    var text: String = ""
    /// Klávesy s největším počtem chyb (seřazené).
    var problemKeys: [String] = []

    // v2 – volitelné, aby lehká migrace starých dat proběhla bez zásahu.
    var modeRaw: String?
    var maxCombo: Int?
    var xpEarned: Int?
    var score: Int?
    var targetWPM: Double?
    var timeLimit: Int?
    var completed: Bool?
    // v3 – rytmus 0–1.
    var rhythm: Double?

    /// Prázdný záznam – pro obnovu ze zálohy.
    init() {}

    init(result: SessionResult) {
        self.date = result.finishedAt
        self.duration = result.duration
        self.wpm = result.wpm
        self.accuracy = result.accuracy
        self.errorCount = result.errors
        self.keystrokes = result.keystrokes
        self.characterCount = result.characters
        self.level = result.difficulty.level
        self.text = result.text
        self.problemKeys = result.problemKeys.prefix(5).map(\.key)
        self.modeRaw = result.mode.rawValue
        self.maxCombo = result.maxCombo
        self.score = result.score
        self.targetWPM = result.targetWPM
        self.timeLimit = result.timeLimit
        self.completed = result.completed
        self.rhythm = result.rhythm
    }

    var difficulty: Difficulty { Difficulty(level: level) }
    var stage: ExerciseStage { difficulty.stage }

    /// Starší záznamy (před v2) jsou klasická cvičení.
    var mode: GameMode { modeRaw.flatMap(GameMode.init(rawValue:)) ?? .practice }
    var combo: Int { maxCombo ?? 0 }
    var xp: Int { xpEarned ?? 0 }
    var isFullExercise: Bool { TypingMetrics.isFullExercise(characters: characterCount, duration: duration) }

    /// Popis typu cvičení do historie.
    var kindTitle: String {
        switch mode {
        case .practice: stage.title
        case .timeAttack: String(localized: "Time Attack \(timeLimit ?? 0) s")
        case .exam: String(localized: "Zkouška \((timeLimit ?? 600) / 60) min")
        case .speedTest: String(localized: "Test rychlosti \(timeLimit ?? 30) s")
        default: mode.title
        }
    }

    /// Hrubé úhozy za minutu (spočítané z napsaného textu).
    var strokesPerMinute: Double {
        Double(TypingMetrics.strokes(in: text)) / (max(duration, 1) / 60)
    }

    var kindSymbol: String { mode == .practice ? stage.symbol : mode.symbol }
}
