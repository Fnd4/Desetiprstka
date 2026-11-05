import Foundation
import Observation

/// Řídí jedno cvičení: porovnává stisky s textem a měří výkon.
///
/// Pravidlo: při chybě kurzor nepostoupí – uživatel musí napsat správný znak.
/// Tím se trénuje přesnost a každá chyba se dá přiřadit konkrétní klávese.
@Observable
final class TypingEngine {
    enum CharacterState: Equatable {
        case pending
        case correct
        /// Napsáno správně, ale až po chybě.
        case corrected
    }

    enum Outcome: Equatable {
        case correct
        case incorrect
        case ignored
        case finished
    }

    /// Milníky combo, při kterých se ukáže jemná odezva.
    static let comboMilestones: Set<Int> = [10, 25, 50, 100, 250, 500, 1000]
    /// Delší pauzy se do reakční doby nepočítají.
    static let maxReactionSample: TimeInterval = 3

    private(set) var characters: [Character]
    private(set) var states: [CharacterState]
    private(set) var position = 0
    private(set) var keystrokes = 0
    private(set) var errors = 0
    private(set) var startedAt: Date?
    private(set) var finishedAt: Date?
    /// Aktuální znak už byl jednou napsán špatně.
    private(set) var currentHasError = false
    /// Zvyšuje se při každé chybě – hodí se pro animace.
    private(set) var errorPulse = 0
    private(set) var keyAttempts: [String: Int] = [:]
    private(set) var keyErrors: [String: Int] = [:]

    // Combo
    private(set) var combo = 0
    private(set) var maxCombo = 0
    /// Poslední dosažený milník a „puls“ pro animaci.
    private(set) var comboMilestone: Int?
    private(set) var milestonePulse = 0

    // Reakční doba
    private(set) var keyReactionTotals: [String: Double] = [:]
    private(set) var keyReactionCounts: [String: Int] = [:]
    @ObservationIgnored private var lastAdvanceAt: Date?
    /// Intervaly mezi správnými úhozy (rytmus). Pauzy nad 2 s se vynechají.
    @ObservationIgnored private(set) var intervals: [Double] = []
    /// Hrubé úhozy správně napsaného textu (živý ukazatel úhozů za minutu).
    private(set) var grossStrokes = 0

    init(text: String) {
        let initial = Array(text.precomposedStringWithCanonicalMapping)
        characters = initial
        states = Array(repeating: .pending, count: initial.count)
    }

    var text: String { String(characters) }
    var isStarted: Bool { startedAt != nil }
    var isFinished: Bool { position >= characters.count }
    /// Cvičení bylo ukončeno zvenku (čas vypršel, uživatel skončil).
    var isStopped: Bool { finishedAt != nil }
    var expected: Character? { isFinished ? nil : characters[position] }
    var progress: Double { characters.isEmpty ? 1 : Double(position) / Double(characters.count) }
    var remainingCharacters: Int { characters.count - position }

    func elapsed(at date: Date = .now) -> TimeInterval {
        guard let startedAt else { return 0 }
        return (finishedAt ?? date).timeIntervalSince(startedAt)
    }

    func wpm(at date: Date = .now) -> Double {
        TypingMetrics.wpm(characters: position, duration: elapsed(at: date))
    }

    var accuracy: Double { TypingMetrics.accuracy(keystrokes: keystrokes, errors: errors) }

    func strokesPerMinute(at date: Date = .now) -> Double {
        let seconds = elapsed(at: date)
        guard seconds >= 1 else { return 0 }
        return Double(grossStrokes) / (seconds / 60)
    }

    /// Průběžný rytmus 0–1 (`nil`, dokud není dost úhozů).
    var rhythm: Double? { TypingMetrics.rhythm(intervals: intervals) }

    /// Připojí další text (nekonečné režimy).
    func append(_ text: String) {
        let extra = Array((" " + text).precomposedStringWithCanonicalMapping)
        characters.append(contentsOf: extra)
        states.append(contentsOf: Array(repeating: CharacterState.pending, count: extra.count))
    }

    /// Ukončí měření (Time Attack, Endless, Survival).
    func stop(at date: Date = .now) {
        guard finishedAt == nil, let startedAt else { return }
        finishedAt = max(date, startedAt)
    }

    /// Zpracuje text vzniklý stiskem klávesy.
    @discardableResult
    func type(_ input: String) -> Outcome {
        guard !isStopped, let expected else { return .ignored }
        let normalized = input.precomposedStringWithCanonicalMapping
        guard normalized.count == 1, let typed = normalized.first, Self.isTypeable(typed) else {
            return .ignored
        }

        let now = Date.now
        if startedAt == nil { startedAt = now }
        keystrokes += 1

        let statKey = Self.statKey(for: expected)
        let needsShift = expected.isUppercase
        if let statKey { keyAttempts[statKey, default: 0] += 1 }
        if needsShift { keyAttempts[Curriculum.shiftKey, default: 0] += 1 }

        if typed == expected {
            states[position] = currentHasError ? .corrected : .correct
            grossStrokes += TypingMetrics.strokeCost(expected)
            position += 1
            currentHasError = false
            registerReaction(for: statKey, at: now)
            registerCombo()
            if isFinished {
                finishedAt = now
                return .finished
            }
            return .correct
        }

        errors += 1
        errorPulse += 1
        currentHasError = true
        combo = 0

        // Správné písmeno, ale bez Shiftu → chyba patří Shiftu.
        if needsShift, typed.lowercased() == expected.lowercased() {
            keyErrors[Curriculum.shiftKey, default: 0] += 1
        } else if let statKey {
            keyErrors[statKey, default: 0] += 1
        }
        return .incorrect
    }

    func makeResult(
        difficulty: Difficulty,
        mode: GameMode = .practice,
        targetWPM: Double? = nil,
        completed: Bool = true,
        score: Int? = nil,
        timeLimit: Int? = nil,
        wave: Int? = nil
    ) -> SessionResult? {
        guard let startedAt else { return nil }
        var result = SessionResult(
            text: String(characters.prefix(max(position, 0))),
            difficulty: difficulty,
            startedAt: startedAt,
            finishedAt: finishedAt ?? .now,
            characters: position,
            keystrokes: keystrokes,
            errors: errors,
            keyAttempts: keyAttempts,
            keyErrors: keyErrors,
            mode: mode,
            targetWPM: targetWPM,
            maxCombo: maxCombo,
            keyReactionTotals: keyReactionTotals,
            keyReactionCounts: keyReactionCounts,
            completed: completed,
            score: score,
            timeLimit: timeLimit,
            wave: wave
        )
        result.rhythm = rhythm
        return result
    }

    // MARK: - Pomocné

    private func registerCombo() {
        combo += 1
        maxCombo = max(maxCombo, combo)
        if Self.comboMilestones.contains(combo) {
            comboMilestone = combo
            milestonePulse += 1
        }
    }

    private func registerReaction(for key: String?, at date: Date) {
        defer { lastAdvanceAt = date }
        guard let last = lastAdvanceAt else { return }
        let interval = date.timeIntervalSince(last)
        if interval > 0, interval <= 2 { intervals.append(interval) }
        guard let key else { return }
        guard interval > 0, interval <= Self.maxReactionSample else { return }
        keyReactionTotals[key, default: 0] += interval
        keyReactionCounts[key, default: 0] += 1
    }

    /// Klíč pro statistiky – malé písmeno, mezery se nesledují.
    static func statKey(for character: Character) -> String? {
        guard character != " " else { return nil }
        return character.lowercased()
    }

    private static func isTypeable(_ character: Character) -> Bool {
        character == " " || character.isLetter || character.isNumber
            || character.isPunctuation || character.isSymbol
    }
}
