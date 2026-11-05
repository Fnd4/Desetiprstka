import Foundation

/// Profilový level 1–100 vypočtený z celkového XP.
/// Čistě gamifikace – nijak neovlivňuje výuku.
struct PlayerLevel: Equatable, Sendable {
    static let maxLevel = 100

    let totalXP: Int
    let level: Int
    let xpIntoLevel: Int
    let xpForNextLevel: Int

    init(totalXP: Int) {
        self.totalXP = max(totalXP, 0)
        var level = 1
        var remaining = self.totalXP
        while level < Self.maxLevel, remaining >= Self.xpRequired(toAdvanceFrom: level) {
            remaining -= Self.xpRequired(toAdvanceFrom: level)
            level += 1
        }
        self.level = level
        self.xpIntoLevel = remaining
        self.xpForNextLevel = level >= Self.maxLevel ? 0 : Self.xpRequired(toAdvanceFrom: level)
    }

    var isMax: Bool { level >= Self.maxLevel }

    var progress: Double {
        guard xpForNextLevel > 0 else { return 1 }
        return Double(xpIntoLevel) / Double(xpForNextLevel)
    }

    /// Kolik XP je potřeba z levelu `level` na další (level 12 → 1200 XP).
    static func xpRequired(toAdvanceFrom level: Int) -> Int {
        100 * max(level, 1)
    }
}

/// Rozpis získaného XP.
struct XPBreakdown: Equatable, Sendable {
    struct Item: Identifiable, Equatable, Sendable {
        let title: String
        let xp: Int
        var id: String { title }
    }

    var items: [Item] = []
    var total: Int { items.reduce(0) { $0 + $1.xp } }

    mutating func add(_ title: String, _ xp: Int) {
        guard xp > 0 else { return }
        items.append(Item(title: title, xp: xp))
    }
}

/// Pravidla pro udělování XP.
enum XPRules {
    static let recordBonus = 25
    static let achievementBonus = 20
    static let modeChallengeBonus = 30

    /// Základ za cvičení: dokončení + přesnost + combo.
    static func base(
        characters: Int,
        accuracy: Double,
        isFullExercise: Bool,
        maxCombo: Int
    ) -> XPBreakdown {
        var breakdown = XPBreakdown()
        if isFullExercise {
            breakdown.add("Dokončené cvičení", 10 + min(characters / 10, 40))
        } else {
            breakdown.add("Krátké cvičení", min(characters / 20, 5))
        }

        if characters >= 40 {
            if accuracy >= 1 {
                breakdown.add("Bezchybné psaní", 30)
            } else if accuracy >= 0.98 {
                breakdown.add("Přesnost nad 98 %", 20)
            } else if accuracy >= 0.95 {
                breakdown.add("Přesnost nad 95 %", 10)
            }
        }

        if maxCombo >= 25 {
            breakdown.add("Série \(maxCombo) znaků", min(maxCombo / 5, 40))
        }
        return breakdown
    }
}
