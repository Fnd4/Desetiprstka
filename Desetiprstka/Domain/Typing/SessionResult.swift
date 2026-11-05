import Foundation

/// Počet chyb u jedné klávesy.
struct KeyErrorCount: Identifiable, Hashable, Sendable {
    let key: String
    let errors: Int
    var id: String { key }
}

/// Výsledek dokončeného cvičení – čistá data bez vazby na databázi.
struct SessionResult: Sendable {
    let text: String
    let difficulty: Difficulty
    let startedAt: Date
    let finishedAt: Date
    /// Počet správně napsaných znaků.
    let characters: Int
    /// Všechny stisky kláves (správné i chybné).
    let keystrokes: Int
    let errors: Int
    let keyAttempts: [String: Int]
    let keyErrors: [String: Int]

    // MARK: Rozšíření (režimy, combo, reakční doba)

    var mode: GameMode = .practice
    /// Cílové WPM podle rychlostní obtížnosti (`nil` = Relaxed).
    var targetWPM: Double?
    var maxCombo: Int = 0
    var keyReactionTotals: [String: Double] = [:]
    var keyReactionCounts: [String: Int] = [:]
    /// `false` = výzva nesplněna (např. příliš mnoho chyb v Accuracy Challenge).
    var completed: Bool = true
    /// Skóre režimu (Time Attack, Survival, Endless = počet správných znaků).
    var score: Int?
    /// Délka Time Attack v sekundách.
    var timeLimit: Int?
    /// Dosažená vlna v Survival.
    var wave: Int?

    var duration: TimeInterval { max(finishedAt.timeIntervalSince(startedAt), 1) }

    /// Slova za minutu – standardně 5 znaků = 1 slovo.
    var wpm: Double { TypingMetrics.wpm(characters: characters, duration: duration) }

    /// Přesnost 0–1.
    var accuracy: Double { TypingMetrics.accuracy(keystrokes: keystrokes, errors: errors) }

    /// Plnohodnotné cvičení – počítá se do streaku a denních statistik.
    var isFullExercise: Bool { TypingMetrics.isFullExercise(characters: characters, duration: duration) }

    var displayScore: Int { score ?? characters }

    /// Hrubé úhozy (české školní počítání – Shift se počítá jako úhoz).
    var grossStrokes: Int { TypingMetrics.strokes(in: text) }

    /// Znaky za minutu (jen správně napsané).
    var cpm: Double { Double(characters) / (duration / 60) }

    /// Raw WPM – všechny stisky včetně chybných (jako „raw“ na Monkeytype).
    var rawWPM: Double { TypingMetrics.wpm(characters: keystrokes, duration: duration) }

    /// Hrubé úhozy za minutu.
    var strokesPerMinute: Double { Double(grossStrokes) / (duration / 60) }

    /// Rytmus 0–1 (1 = úplně pravidelné tempo), `nil` = málo dat.
    var rhythm: Double?

    /// Hodnocení opisu jako ve škole (počítá se u Zkoušky, ukázat jde u čehokoliv).
    var exam: ExamEvaluation {
        ExamEvaluation(grossStrokes: grossStrokes, errors: errors, duration: duration)
    }

    /// Klávesy s chybami, nejhorší první.
    var problemKeys: [KeyErrorCount] {
        keyErrors
            .filter { $0.value > 0 }
            .map { KeyErrorCount(key: $0.key, errors: $0.value) }
            .sorted { ($0.errors, $1.key) > ($1.errors, $0.key) }
    }
}

/// Výpočty metrik na jednom místě.
enum TypingMetrics {
    static func wpm(characters: Int, duration: TimeInterval) -> Double {
        guard duration >= 1 else { return 0 }
        return Double(characters) / 5 / (duration / 60)
    }

    static func accuracy(keystrokes: Int, errors: Int) -> Double {
        guard keystrokes > 0 else { return 1 }
        return Double(max(keystrokes - errors, 0)) / Double(keystrokes)
    }

    /// Počet úhozů pro znak na české klávesnici Macu (QWERTZ i QWERTY).
    /// Velká písmena, číslice a znaky na Shiftu = 2, mrtvé klávesy (ó, ď, ť, ň) = 2–3.
    static func strokeCost(_ character: Character) -> Int {
        if character == " " { return 1 }
        if let cost = deadKeyCosts[character] { return cost }
        if let lower = character.lowercased().first, lower != character, let cost = deadKeyCosts[lower] {
            return cost + 1
        }
        if character.isNumber || shiftedSymbols.contains(character) { return 2 }
        if character.isUppercase { return 2 }
        return 1
    }

    static func strokes(in text: String) -> Int {
        text.reduce(0) { $0 + strokeCost($1) }
    }

    private static let shiftedSymbols: Set<Character> = ["%", "ˇ", "/", "(", "\"", "!", "?", ":", "_", "°", "'"]
    /// ´ + písmeno = 2, ˇ (Shift + ´) + písmeno = 3.
    private static let deadKeyCosts: [Character: Int] = [
        "ó": 2, "ä": 2, "ö": 2, "ü": 2, "ĺ": 2, "ŕ": 2,
        "ď": 3, "ť": 3, "ň": 3, "ľ": 3,
    ]

    /// Pravidelnost tempa 0–1 z intervalů mezi úhozy (1 − variační koeficient).
    /// Okrajových 10 % (zaváhání, výjimečně rychlé dvojice) se nepočítá.
    static func rhythm(intervals: [Double]) -> Double? {
        guard intervals.count >= 20 else { return nil }
        let sorted = intervals.sorted()
        let trim = sorted.count / 10
        let core = Array(sorted[trim..<(sorted.count - trim)])
        let mean = core.reduce(0, +) / Double(core.count)
        guard mean > 0 else { return nil }
        let variance = core.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(core.count)
        let cv = variance.squareRoot() / mean
        return min(max(1 - cv, 0), 1)
    }

    /// Minimum pro „plnohodnotné“ cvičení (streak, denní výzvy).
    static func isFullExercise(characters: Int, duration: TimeInterval) -> Bool {
        characters >= 40 && duration >= 10
    }
}
