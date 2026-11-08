import Foundation

/// Souhrnná data, ze kterých se počítá postup u odznaků.
struct AchievementContext: Sendable {
    var totalSessions: Double = 0
    var totalCharacters: Double = 0
    var bestWPM: Double = 0
    var perfectSessions: Double = 0
    var longestStreak: Double = 0
    var bestCombo: Double = 0
    var learnedKeys: Double = 0
    var dailyChallengesCompleted: Double = 0
    var bestSurvival: Double = 0
}

/// Definice jednoho odznaku.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let target: Double
    let metric: KeyPath<AchievementContext, Double>

    func value(in context: AchievementContext) -> Double {
        context[keyPath: metric]
    }

    func progress(in context: AchievementContext) -> Double {
        guard target > 0 else { return 1 }
        return min(value(in: context) / target, 1)
    }

    func isUnlocked(in context: AchievementContext) -> Bool {
        value(in: context) >= target
    }

    func formattedProgress(in context: AchievementContext) -> String {
        let current = min(value(in: context), target)
        return "\(Format.number(current)) / \(Format.number(target))"
    }
}

/// Katalog odznaků. Nový odznak = nová položka v poli.
enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(id: "first-steps", title: String(localized: "First Steps"),
                    detail: String(localized: "Dokonči první cvičení."),
                    symbol: "shoeprints.fill", target: 1, metric: \.totalSessions),
        Achievement(id: "dedicated", title: String(localized: "Dedicated"),
                    detail: String(localized: "Dokonči 50 cvičení."),
                    symbol: "calendar", target: 50, metric: \.totalSessions),
        Achievement(id: "speedster", title: String(localized: "Speedster"),
                    detail: String(localized: "Dosáhni 50 WPM."),
                    symbol: "hare", target: 50, metric: \.bestWPM),
        Achievement(id: "lightning", title: String(localized: "Lightning"),
                    detail: String(localized: "Dosáhni 80 WPM."),
                    symbol: "bolt.fill", target: 80, metric: \.bestWPM),
        Achievement(id: "perfectionist", title: String(localized: "Perfectionist"),
                    detail: String(localized: "Dokonči cvičení se 100% přesností."),
                    symbol: "checkmark.seal", target: 1, metric: \.perfectSessions),
        Achievement(id: "marathon", title: String(localized: "Marathon"),
                    detail: String(localized: "Napiš celkem 10 000 znaků."),
                    symbol: "figure.run", target: 10_000, metric: \.totalCharacters),
        Achievement(id: "consistent", title: String(localized: "Consistent"),
                    detail: String(localized: "Udrž 7denní sérii."),
                    symbol: "flame", target: 7, metric: \.longestStreak),
        Achievement(id: "unstoppable", title: String(localized: "Unstoppable"),
                    detail: String(localized: "Udrž 30denní sérii."),
                    symbol: "flame.fill", target: 30, metric: \.longestStreak),
        Achievement(id: "combo-master", title: String(localized: "Combo Master"),
                    detail: String(localized: "Napiš 250 znaků v řadě bez chyby."),
                    symbol: "link", target: 250, metric: \.bestCombo),
        Achievement(id: "challenger", title: String(localized: "Challenger"),
                    detail: String(localized: "Splň 10 denních výzev."),
                    symbol: "star.circle", target: 10, metric: \.dailyChallengesCompleted),
        Achievement(id: "survivor", title: String(localized: "Survivor"),
                    detail: String(localized: "Získej 500 bodů v režimu Survival."),
                    symbol: "heart.circle", target: 500, metric: \.bestSurvival),
        Achievement(id: "keyboard-master", title: String(localized: "Keyboard Master"),
                    detail: String(localized: "Nauč se všechny klávesy."),
                    symbol: "keyboard.fill", target: Double(Curriculum.orderedKeys.count), metric: \.learnedKeys),
    ]

    static func achievement(id: String) -> Achievement? {
        all.first { $0.id == id }
    }
}
