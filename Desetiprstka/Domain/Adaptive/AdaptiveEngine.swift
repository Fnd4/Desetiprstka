import Foundation

/// Statistika jedné klávesy nezávislá na databázi.
struct LetterStatSnapshot: Hashable, Sendable {
    /// Předpokládaná chybovost klávesy, o které ještě nic nevíme.
    static let priorErrorRate = 0.1

    let key: String
    let attempts: Int
    let errors: Int
    /// Klouzavý průměr – starší výkony postupně ztrácí váhu.
    let recentAttempts: Double
    let recentErrors: Double
    /// Součet a počet měření reakční doby (čas mezi dvěma správnými znaky).
    var reactionTotal: Double = 0
    var reactionSamples: Int = 0

    /// Průměrná reakční doba v sekundách.
    var averageReaction: Double? {
        reactionSamples > 0 ? reactionTotal / Double(reactionSamples) : nil
    }

    var accuracy: Double { TypingMetrics.accuracy(keystrokes: attempts, errors: errors) }

    /// Vyhlazená chybovost (s malým „apriorním“ vzorkem, aby jedna chyba nerozhodovala).
    var recentErrorRate: Double { (recentErrors + 0.5) / (recentAttempts + 5) }
}

/// Rozhoduje o obtížnosti, vahách písmen a doporučení dalšího písmene.
struct AdaptiveEngine {
    enum Change: Equatable, Sendable {
        case levelUp
        case levelDown
        case stay
    }

    struct Evaluation: Sendable {
        let previous: Difficulty
        let next: Difficulty
        let goodStreak: Int
        let change: Change
        let message: String
    }

    var goodAccuracy = 0.94
    var excellentAccuracy = 0.97
    var poorAccuracy = 0.85
    var requiredGoodStreak = 2
    /// Klávesa se považuje za „novou“, dokud nemá tolik pokusů.
    var newKeyAttemptThreshold = 40

    // MARK: - Obtížnost

    /// Vyhodnotí obtížnost textu.
    ///
    /// - Parameter speedTarget: cílové WPM z rychlostní obtížnosti (`nil` = Relaxed,
    ///   tedy postup jen podle přesnosti). Obtížnost textu a rychlost jsou dvě nezávislé
    ///   hodnoty – rychlost jen určuje, jaké tempo je pro postup v textu potřeba.
    func evaluate(
        result: SessionResult,
        current: Difficulty,
        goodStreak: Int,
        speedTarget: Double?
    ) -> Evaluation {
        let target = (speedTarget ?? 0) * current.stage.speedFactor
        let accuracy = result.accuracy
        let wpm = result.wpm
        let isTop = current.level == Difficulty.maxLevel
        let isBottom = current.level == Difficulty.range.lowerBound

        // Výborný výkon → postup hned.
        if accuracy >= excellentAccuracy, wpm >= target * 1.25, wpm > 0, !isTop {
            return levelUp(from: current, reason: "Výborný výkon!")
        }

        // Dobrý výkon → sbíráme sérii.
        if accuracy >= goodAccuracy, wpm >= target {
            let streak = goodStreak + 1
            if streak >= requiredGoodStreak, !isTop {
                return levelUp(from: current, reason: "Skvělá série!")
            }
            let message = isTop
                ? "Jsi na nejvyšší úrovni. Pokračuj a zlepšuj rychlost."
                : "Dobrá práce. Ještě jedno takové cvičení a postoupíš."
            return Evaluation(previous: current, next: current, goodStreak: isTop ? 0 : streak,
                              change: .stay, message: message)
        }

        // Slabá přesnost → krok zpět.
        if accuracy < poorAccuracy, !isBottom {
            let next = current.lowered
            return Evaluation(
                previous: current, next: next, goodStreak: 0, change: .levelDown,
                message: "Přesnost klesla pod \(Int(poorAccuracy * 100)) %. Trochu zpomalíme – \(next.title): \(next.stage.title)."
            )
        }

        let message: String
        if accuracy < goodAccuracy {
            message = "Soustřeď se hlavně na přesnost. Pro postup potřebuješ alespoň \(Int(goodAccuracy * 100)) %."
        } else {
            message = "Přesnost je skvělá. Pro postup v textu zrychli na \(Int(target.rounded())) WPM."
        }
        return Evaluation(previous: current, next: current, goodStreak: 0, change: .stay, message: message)
    }

    private func levelUp(from current: Difficulty, reason: String) -> Evaluation {
        let next = current.raised
        let stageChanged = next.stage != current.stage
        let detail = stageChanged
            ? "Nový typ cvičení: \(next.stage.title)."
            : "Postupuješ na \(next.title.lowercased())."
        return Evaluation(previous: current, next: next, goodStreak: 0, change: .levelUp,
                          message: "\(reason) \(detail)")
    }

    // MARK: - Váhy písmen

    /// Čím víc chyb a čím méně zkušeností, tím vyšší váha.
    func practiceWeights(knownKeys: Set<String>, snapshots: [String: LetterStatSnapshot]) -> [String: Double] {
        var result: [String: Double] = [:]
        for key in knownKeys {
            let snapshot = snapshots[key]
            let errorRate = snapshot?.recentErrorRate ?? LetterStatSnapshot.priorErrorRate
            var weight = 1 + 10 * errorRate
            if (snapshot?.attempts ?? 0) < newKeyAttemptThreshold { weight += 1.5 }
            result[key] = weight
        }
        return result
    }

    // MARK: - Doporučení

    /// Doporučí další písmeno, když uživatel současná písmena zvládá.
    func recommendNewKey(
        knownKeys: Set<String>,
        snapshots: [String: LetterStatSnapshot],
        lastResult: SessionResult
    ) -> String? {
        recommendNewKey(knownKeys: knownKeys, snapshots: snapshots, recentAccuracy: lastResult.accuracy)
    }

    /// Varianta pro hlavní obrazovku – podle průměrné přesnosti posledních cvičení.
    func recommendNewKey(
        knownKeys: Set<String>,
        snapshots: [String: LetterStatSnapshot],
        recentAccuracy: Double
    ) -> String? {
        guard recentAccuracy >= 0.92, let next = Curriculum.nextKey(after: knownKeys) else { return nil }

        let practiced = knownKeys.compactMap { snapshots[$0] }.filter { $0.attempts >= 15 }
        guard Double(practiced.count) >= Double(knownKeys.count) * 0.8 else { return nil }
        guard practiced.allSatisfy({ $0.recentErrorRate <= 0.2 }) else { return nil }
        return next
    }

    /// Klávesy s nejvyšší chybovostí (pro statistiky a domovskou obrazovku).
    func weakestKeys(
        knownKeys: Set<String>,
        snapshots: [String: LetterStatSnapshot],
        limit: Int = 5
    ) -> [LetterStatSnapshot] {
        knownKeys
            .compactMap { snapshots[$0] }
            .filter { $0.attempts >= 10 && $0.recentErrorRate > 0.12 }
            .sorted { $0.recentErrorRate > $1.recentErrorRate }
            .prefix(limit)
            .map { $0 }
    }
}
