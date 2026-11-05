import Foundation

/// Akce, kterou doporučený krok nabízí.
enum NextStepAction: Equatable, Sendable {
    case startPractice(PracticeConfiguration)
    case addKey(String)
    case changeSpeed(SpeedSetting)
}

/// Doporučený další krok na hlavní obrazovce.
struct NextStep: Equatable, Sendable {
    let title: String
    let detail: String
    let symbol: String
    let actionTitle: String
    let action: NextStepAction
}

/// Vybere jeden nejdůležitější krok – nikdy ne seznam úkolů.
enum NextStepAdvisor {
    struct Input: Sendable {
        var hasSessions: Bool
        var streak: Int
        var streakAtRisk: Bool
        var recommendedKey: String?
        var speedRecommendation: SpeedRecommendation?
        var weakKeys: [String]
        var dailyChallengeDone: Bool
    }

    static func advise(_ input: Input) -> NextStep {
        if !input.hasSessions {
            return NextStep(
                title: "Začni prvním cvičením",
                detail: "Pár minut stačí. Aplikace se ti hned začne přizpůsobovat.",
                symbol: "play.circle",
                actionTitle: "Začít",
                action: .startPractice(.adaptive)
            )
        }

        if input.streakAtRisk {
            return NextStep(
                title: "Udrž si \(input.streak)denní sérii",
                detail: "Dnes ještě nemáš žádné cvičení. Jedno krátké stačí.",
                symbol: "flame",
                actionTitle: "Krátké cvičení",
                action: .startPractice(PracticeConfiguration(mode: .practice, isAdaptive: false, length: .short))
            )
        }

        if let key = input.recommendedKey {
            return NextStep(
                title: "Jsi připraven na \(Curriculum.displayName(for: key))",
                detail: "Současná písmena ti jdou dobře. Přidej další klávesu z osnovy.",
                symbol: "plus.circle",
                actionTitle: "Přidat \(Curriculum.displayName(for: key))",
                action: .addKey(key)
            )
        }

        if let speed = input.speedRecommendation {
            return NextStep(
                title: speed.direction == .up ? "Zkus vyšší tempo" : "Zkus klidnější tempo",
                detail: speed.reason,
                symbol: speed.direction == .up ? "arrow.up.forward.circle" : "arrow.down.forward.circle",
                actionTitle: speed.actionTitle,
                action: .changeSpeed(speed.suggested)
            )
        }

        if !input.weakKeys.isEmpty {
            let names = input.weakKeys.prefix(3).map { Curriculum.displayName(for: $0) }.joined(separator: ", ")
            return NextStep(
                title: "Procvič slabší klávesy",
                detail: "Nejvíc chybuješ u \(names). Cvičení je bude zařazovat častěji.",
                symbol: "scope",
                actionTitle: "Procvičit",
                action: .startPractice(.adaptive)
            )
        }

        if !input.dailyChallengeDone {
            return NextStep(
                title: "Splň dnešní výzvu",
                detail: "Za splnění získáš bonusové XP.",
                symbol: "star.circle",
                actionTitle: "Začít",
                action: .startPractice(.adaptive)
            )
        }

        return NextStep(
            title: "Vyzkoušej Time Attack",
            detail: "Kolik správných znaků napíšeš za 60 sekund?",
            symbol: "timer",
            actionTitle: "Spustit",
            action: .startPractice(.quick(.timeAttack))
        )
    }
}
