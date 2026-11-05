import Foundation
import SwiftData

/// Jak rychle starší výkony ztrácí váhu (0–1, méně = rychleji).
private let letterStatDecay = 0.7

/// Dlouhodobá statistika jedné klávesy.
@Model
final class LetterStat {
    @Attribute(.unique) var key: String = ""
    var attempts: Int = 0
    var errors: Int = 0
    /// Klouzavé hodnoty – po každém cvičení se staré výsledky „zředí“.
    var recentAttempts: Double = 0
    var recentErrors: Double = 0
    var lastPracticed: Date?

    // v2 – volitelné, aby lehká migrace starých dat proběhla bez zásahu.
    /// Součet reakčních dob v sekundách.
    var reactionTimeTotal: Double?
    /// Počet měření reakční doby.
    var reactionSamples: Int?

    init(key: String) {
        self.key = key
    }

    func register(
        attempts newAttempts: Int,
        errors newErrors: Int,
        reactionTotal: Double = 0,
        reactionCount: Int = 0,
        at date: Date
    ) {
        attempts += newAttempts
        errors += newErrors
        recentAttempts = recentAttempts * letterStatDecay + Double(newAttempts)
        recentErrors = recentErrors * letterStatDecay + Double(newErrors)
        if reactionCount > 0 {
            reactionTimeTotal = (reactionTimeTotal ?? 0) + reactionTotal
            reactionSamples = (reactionSamples ?? 0) + reactionCount
        }
        lastPracticed = date
    }

    var snapshot: LetterStatSnapshot {
        LetterStatSnapshot(
            key: key,
            attempts: attempts,
            errors: errors,
            recentAttempts: recentAttempts,
            recentErrors: recentErrors,
            reactionTotal: reactionTimeTotal ?? 0,
            reactionSamples: reactionSamples ?? 0
        )
    }
}
