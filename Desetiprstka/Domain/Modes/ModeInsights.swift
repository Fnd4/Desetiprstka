import Foundation

/// Jedno odehrané cvičení – jen to, co potřebuje přehled režimů.
struct ModeSessionSummary: Sendable {
    let mode: GameMode
    let date: Date
    let wpm: Double
    let accuracy: Double
    let characters: Int
    let duration: TimeInterval
    let score: Int?
    let timeLimit: Int?
    let completed: Bool
}

/// Osobní rekord s datem.
struct RecordEntry: Sendable {
    let value: Double
    let date: Date
}

/// Konkrétní cíl režimu s postupem.
struct ModeGoal: Sendable {
    /// „450 znaků“
    let target: String
    /// 0–1, `nil` = zatím bez pokusu.
    let progress: Double?
    /// Popisek pod progress barem.
    let progressLabel: String
}

/// Stav, kterým se karta může pochlubit.
enum ModeBadge: Equatable, Sendable {
    case newRecord
    case bestToday(String)
    case notTried

    var title: String {
        switch self {
        case .newRecord: String(localized: "Nový rekord")
        case .bestToday(let value): String(localized: "Dnes \(value)")
        case .notTried: String(localized: "Nevyzkoušeno")
        }
    }

    var symbol: String {
        switch self {
        case .newRecord: "trophy.fill"
        case .bestToday: "sun.max.fill"
        case .notTried: "sparkles"
        }
    }
}

/// Vše, co karta režimu zobrazuje.
struct ModeInsight: Identifiable, Sendable {
    let mode: GameMode
    /// „PB“ nebo jiný popisek rekordu.
    let personalBestLabel: String
    let personalBest: String?
    let goal: ModeGoal
    /// Doplňující údaj (nejlepší čas, nejdelší session…).
    let detail: String?
    let badge: ModeBadge?
    let lastPlayed: Date?

    var id: GameMode { mode }
}

/// Doporučený režim pro hero panel.
struct ModeRecommendation: Sendable {
    let mode: GameMode
    let configuration: PracticeConfiguration
    let title: String
    let goal: String
    let reason: String
    /// Odhad XP za pokus (horní hranice při úspěchu).
    let reward: Int
}

/// Vstup pro výpočet – čistá data bez SwiftData.
struct ModeInsightsInput: Sendable {
    /// Nejnovější první.
    var sessions: [ModeSessionSummary]
    var records: [RecordKind: RecordEntry]
    var timeAttack: TimeAttackDuration
    var exam: ExamDuration = .minutes10
    var speedTest: TimeAttackDuration = .seconds30
    var difficulty: Difficulty
    var goodStreak: Int
    var speed: SpeedSetting
    var dailyChallenge: DailyChallenge?
    var dailyChallengeCompleted: Bool
    var now: Date = .now
}

/// Počítá osobní rekordy, cíle a doporučení pro obrazovku Režimy.
enum ModeInsightsBuilder {
    // MARK: - Karty

    static func insights(for input: ModeInsightsInput, calendar: Calendar = .current) -> [ModeInsight] {
        GameMode.allCases.map { insight(for: $0, input: input, calendar: calendar) }
    }

    static func insight(for mode: GameMode, input: ModeInsightsInput, calendar: Calendar = .current) -> ModeInsight {
        let sessions = input.sessions.filter { matches($0, mode: mode, input: input) }
        let last = sessions.first
        let badge = badge(for: mode, sessions: sessions, input: input, calendar: calendar)

        switch mode {
        case .practice:
            return practiceInsight(sessions: sessions, input: input, badge: badge)
        case .timeAttack:
            return timeAttackInsight(last: last, input: input, badge: badge)
        case .sprint:
            return sprintInsight(sessions: sessions, input: input, badge: badge)
        case .accuracyChallenge:
            return accuracyInsight(sessions: sessions, badge: badge)
        case .survival:
            return survivalInsight(last: last, input: input, badge: badge)
        case .endless:
            return endlessInsight(sessions: sessions, badge: badge)
        case .exam:
            return examInsight(sessions: sessions, input: input, badge: badge)
        case .customText:
            return customTextInsight(sessions: sessions, badge: badge)
        case .speedTest:
            return speedTestInsight(sessions: sessions, input: input, badge: badge)
        }
    }

    private static func speedTestInsight(sessions: [ModeSessionSummary], input: ModeInsightsInput, badge: ModeBadge?) -> ModeInsight {
        let best = sessions.map(\.wpm).max()
        let average = sessions.prefix(5).map(\.wpm)
        let target = ((best ?? input.speed.targetWPM ?? 20) + 3).rounded(.up)
        let last = sessions.first
        return ModeInsight(
            mode: .speedTest,
            personalBestLabel: String(localized: "PB"),
            personalBest: best.map { SpeedUnit.current.label($0) },
            goal: ModeGoal(
                target: SpeedUnit.current.label(target),
                progress: last.map { min($0.wpm / target, 1) },
                progressLabel: last.map { String(localized: "Poslední \(SpeedUnit.current.label($0.wpm)) · \(Format.percent($0.accuracy))") }
                    ?? String(localized: "Zatím bez pokusu")
            ),
            detail: average.isEmpty ? nil : String(localized: "Průměr posledních \(average.count): \(SpeedUnit.current.label(average.reduce(0, +) / Double(average.count)))"),
            badge: badge,
            lastPlayed: last?.date
        )
    }

    private static func examInsight(sessions: [ModeSessionSummary], input: ModeInsightsInput, badge: ModeBadge?) -> ModeInsight {
        let best = sessions.compactMap(\.score).max()
        // Cíl = práh nejbližší lepší známky.
        let grades = ExamEvaluation.Grade.allCases.compactMap { grade in grade.requirement.map { (grade, $0.net) } }
        let next = grades.reversed().first { Double(best ?? 0) < $0.1 } ?? grades[0]
        let last = sessions.first?.score
        return ModeInsight(
            mode: .exam,
            personalBestLabel: String(localized: "PB"),
            personalBest: best.map { String(localized: "\(Format.number($0)) čistých") },
            goal: ModeGoal(
                target: String(localized: "\(Format.number(next.1)) úh./min"),
                progress: last.map { min(Double($0) / next.1, 1) },
                progressLabel: last.map { String(localized: "Poslední \(Format.number($0)) čistých úh./min") } ?? String(localized: "Zatím bez pokusu")
            ),
            detail: String(localized: "Na známku \(next.0.rawValue) · \(input.exam.title)"),
            badge: badge,
            lastPlayed: sessions.first?.date
        )
    }

    private static func customTextInsight(sessions: [ModeSessionSummary], badge: ModeBadge?) -> ModeInsight {
        let finished = sessions.filter(\.completed)
        let best = finished.map(\.wpm).max()
        let last = finished.first
        let target = ((best ?? 20) + 2).rounded(.up)
        return ModeInsight(
            mode: .customText,
            personalBestLabel: String(localized: "PB"),
            personalBest: best.map { SpeedUnit.current.label($0) },
            goal: ModeGoal(
                target: SpeedUnit.current.label(target),
                progress: last.map { min($0.wpm / target, 1) },
                progressLabel: last.map { String(localized: "Poslední \(SpeedUnit.current.label($0.wpm)) · \(Format.percent($0.accuracy))") }
                    ?? String(localized: "Vlož text a začni")
            ),
            detail: sessions.isEmpty ? nil : String(localized: "Opsáno \(sessions.count)×"),
            badge: badge,
            lastPlayed: sessions.first?.date
        )
    }

    private static func practiceInsight(sessions: [ModeSessionSummary], input: ModeInsightsInput, badge: ModeBadge?) -> ModeInsight {
        let best = input.records[.bestWPM]?.value
        let goal: ModeGoal
        if input.difficulty.level < Difficulty.maxLevel {
            let next = input.difficulty.raised
            let streak = min(input.goodStreak, 2)
            goal = ModeGoal(
                target: String(localized: "úroveň \(next.level)"),
                progress: Double(streak) / 2,
                progressLabel: String(localized: "Série k postupu \(streak)/2")
            )
        } else {
            let target = ((best ?? 20) + 2).rounded(.up)
            let lastWPM = sessions.first?.wpm
            goal = ModeGoal(
                target: SpeedUnit.current.label(target),
                progress: lastWPM.map { min($0 / target, 1) },
                progressLabel: lastWPM.map { String(localized: "Poslední \(SpeedUnit.current.label($0))") } ?? String(localized: "Zatím bez pokusu")
            )
        }
        return ModeInsight(
            mode: .practice,
            personalBestLabel: String(localized: "PB"),
            personalBest: best.map { "\(SpeedUnit.current.label($0))" },
            goal: goal,
            detail: "\(input.difficulty.title) · \(input.difficulty.stage.title)",
            badge: badge,
            lastPlayed: sessions.first?.date
        )
    }

    private static func timeAttackInsight(last: ModeSessionSummary?, input: ModeInsightsInput, badge: ModeBadge?) -> ModeInsight {
        let seconds = input.timeAttack.rawValue
        let best = RecordKind.timeAttack(seconds).flatMap { input.records[$0]?.value }
        let target: Double
        if let best, best > 0 {
            target = roundUp(best * 1.1, to: 5)
        } else {
            let wpm = input.speed.targetWPM ?? 15
            target = roundUp(max(wpm * 5 * Double(seconds) / 60, 10), to: 5)
        }
        let lastScore = last.map { Double($0.score ?? $0.characters) }
        return ModeInsight(
            mode: .timeAttack,
            personalBestLabel: String(localized: "PB"),
            personalBest: best.map { String(localized: "\(Format.number($0)) znaků") },
            goal: ModeGoal(
                target: String(localized: "\(Format.number(target)) znaků"),
                progress: (lastScore ?? best).map { min($0 / target, 1) },
                progressLabel: lastScore.map { String(localized: "Poslední \(Format.number($0)) znaků") }
                    ?? (best != nil ? String(localized: "Rekord vůči cíli") : String(localized: "Zatím bez pokusu"))
            ),
            detail: String(localized: "Délka \(input.timeAttack.title)"),
            badge: badge,
            lastPlayed: last?.date
        )
    }

    private static func sprintInsight(sessions: [ModeSessionSummary], input: ModeInsightsInput, badge: ModeBadge?) -> ModeInsight {
        let finished = sessions.filter(\.completed)
        let best = input.records[.sprint]?.value ?? finished.map(\.wpm).max()
        let bestTime = finished.map(\.duration).min()
        let target: Double
        if let best, best > 0 {
            target = (best + max(2, best * 0.05)).rounded(.up)
        } else {
            target = (input.speed.targetWPM ?? 15).rounded(.up)
        }
        let lastWPM = finished.first?.wpm
        return ModeInsight(
            mode: .sprint,
            personalBestLabel: String(localized: "PB"),
            personalBest: best.map { "\(SpeedUnit.current.label($0))" },
            goal: ModeGoal(
                target: SpeedUnit.current.label(target),
                progress: lastWPM.map { min($0 / target, 1) },
                progressLabel: lastWPM.map { String(localized: "Poslední \(SpeedUnit.current.label($0))") } ?? String(localized: "Zatím bez pokusu")
            ),
            detail: bestTime.map { String(localized: "Nejlepší čas \(Format.duration($0))") },
            badge: badge,
            lastPlayed: sessions.first?.date
        )
    }

    private static func accuracyInsight(sessions: [ModeSessionSummary], badge: ModeBadge?) -> ModeInsight {
        let finished = sessions.filter(\.completed)
        let best = finished.map(\.accuracy).max()
        let target: Double
        switch best ?? 0 {
        case ..<0.97: target = 0.97
        case ..<0.99: target = 0.99
        default: target = 1
        }
        let last = sessions.first
        let successes = finished.count
        return ModeInsight(
            mode: .accuracyChallenge,
            personalBestLabel: String(localized: "PB"),
            personalBest: best.map { Format.percent($0) },
            goal: ModeGoal(
                target: target >= 1 ? String(localized: "bez chyby") : Format.percent(target),
                progress: last.map { min(($0.completed ? $0.accuracy : 0) / target, 1) },
                progressLabel: last.map { $0.completed ? String(localized: "Poslední \(Format.percent($0.accuracy))") : String(localized: "Poslední pokus nesplněn") }
                    ?? String(localized: "Zatím bez pokusu")
            ),
            detail: sessions.isEmpty ? nil : String(localized: "Splněno \(successes)× z \(sessions.count)"),
            badge: badge,
            lastPlayed: last?.date
        )
    }

    private static func survivalInsight(last: ModeSessionSummary?, input: ModeInsightsInput, badge: ModeBadge?) -> ModeInsight {
        let best = input.records[.survival]?.value
        let target: Double = (best ?? 0) > 0 ? roundUp(best! * 1.2, to: 10) : 100
        let lastScore = last.map { Double($0.score ?? $0.characters) }
        return ModeInsight(
            mode: .survival,
            personalBestLabel: String(localized: "PB"),
            personalBest: best.map { String(localized: "\(Format.number($0)) bodů") },
            goal: ModeGoal(
                target: String(localized: "\(Format.number(target)) bodů"),
                progress: lastScore.map { min($0 / target, 1) },
                progressLabel: lastScore.map { String(localized: "Poslední \(Format.number($0)) bodů") } ?? String(localized: "Zatím bez pokusu")
            ),
            detail: nil,
            badge: badge,
            lastPlayed: last?.date
        )
    }

    private static func endlessInsight(sessions: [ModeSessionSummary], badge: ModeBadge?) -> ModeInsight {
        let longest = sessions.max { $0.characters < $1.characters }
        let target: Double = longest.map { roundUp(Double($0.characters) * 1.25, to: 50) } ?? 300
        let last = sessions.first
        return ModeInsight(
            mode: .endless,
            personalBestLabel: String(localized: "Nejdelší"),
            personalBest: longest.map { String(localized: "\(Format.number($0.characters)) znaků") },
            goal: ModeGoal(
                target: String(localized: "\(Format.number(target)) znaků"),
                progress: last.map { min(Double($0.characters) / target, 1) },
                progressLabel: last.map { String(localized: "Poslední \(Format.number($0.characters)) znaků") } ?? String(localized: "Zatím bez pokusu")
            ),
            detail: longest.map { String(localized: "Nejdelší session \(Format.duration($0.duration))") },
            badge: badge,
            lastPlayed: last?.date
        )
    }

    // MARK: - Odznaky „Nový rekord“ / „Dnes“

    private static func badge(
        for mode: GameMode,
        sessions: [ModeSessionSummary],
        input: ModeInsightsInput,
        calendar: Calendar
    ) -> ModeBadge? {
        guard !sessions.isEmpty else { return .notTried }

        let today = sessions.filter { calendar.isDate($0.date, inSameDayAs: input.now) }
        let earlier = sessions.filter { !calendar.isDate($0.date, inSameDayAs: input.now) }
        guard let bestToday = today.map({ metric($0) }).max(), bestToday > 0 else { return nil }

        if let bestBefore = earlier.map({ metric($0) }).max(), bestBefore > 0, bestToday > bestBefore {
            return .newRecord
        }
        return .bestToday(formatMetric(bestToday, mode: mode))
    }

    /// Hodnota, podle které se v režimu porovnává výkon.
    private static func metric(_ session: ModeSessionSummary) -> Double {
        switch session.mode {
        case .practice, .sprint, .customText: session.completed ? session.wpm : 0
        case .speedTest: session.wpm
        case .timeAttack, .survival: Double(session.score ?? session.characters)
        case .exam: Double(session.score ?? 0)
        case .accuracyChallenge: session.completed ? session.accuracy : 0
        case .endless: Double(session.characters)
        }
    }

    private static func formatMetric(_ value: Double, mode: GameMode) -> String {
        switch mode {
        case .practice, .sprint: "\(SpeedUnit.current.label(value))"
        case .timeAttack, .endless: String(localized: "\(Format.number(value)) znaků")
        case .survival: String(localized: "\(Format.number(value)) bodů")
        case .accuracyChallenge: Format.percent(value)
        case .exam: String(localized: "\(Format.number(value)) čistých")
        case .customText, .speedTest: SpeedUnit.current.label(value)
        }
    }

    /// Time Attack se porovnává jen se stejnou délkou.
    private static func matches(_ session: ModeSessionSummary, mode: GameMode, input: ModeInsightsInput) -> Bool {
        guard session.mode == mode else { return false }
        if mode == .timeAttack { return session.timeLimit == input.timeAttack.rawValue }
        if mode == .exam { return session.timeLimit == Int(input.exam.seconds) }
        if mode == .speedTest { return session.timeLimit == input.speedTest.rawValue }
        return true
    }

    // MARK: - Doporučení

    static func recommendation(for input: ModeInsightsInput, insights: [ModeInsight]) -> ModeRecommendation {
        let byMode = Dictionary(uniqueKeysWithValues: insights.map { ($0.mode, $0) })
        let playable: [GameMode] = [.timeAttack, .sprint, .accuracyChallenge, .survival, .endless]

        // 1) Režim, který pomůže splnit výzvu dne.
        if let challenge = input.dailyChallenge, !input.dailyChallengeCompleted {
            let mode = mode(for: challenge.kind)
            return make(mode, insight: byMode[mode], input: input,
                        reason: String(localized: "Pomůže ti splnit dnešní výzvu."), bonus: challenge.reward)
        }

        // 2) Režim, který uživatel ještě nezkusil.
        if let fresh = playable.first(where: { byMode[$0]?.lastPlayed == nil }) {
            return make(fresh, insight: byMode[fresh], input: input,
                        reason: String(localized: "Tenhle režim jsi ještě nezkusil."), bonus: 0)
        }

        // 3) Režim, který nejdéle odpočívá.
        let oldest = playable.min {
            (byMode[$0]?.lastPlayed ?? .distantPast) < (byMode[$1]?.lastPlayed ?? .distantPast)
        } ?? .timeAttack
        return make(oldest, insight: byMode[oldest], input: input,
                    reason: String(localized: "Na tenhle režim jsi už chvíli nesáhl. Zkus překonat svůj rekord."), bonus: 0)
    }

    /// Režim, který nejlépe pomůže splnit daný typ výzvy.
    static func mode(for kind: DailyChallengeKind) -> GameMode {
        switch kind {
        case .reachWPM: .sprint
        case .accuracy, .maxErrors, .combo: .accuracyChallenge
        case .typeCharacters, .practiceMinutes: .endless
        }
    }

    private static func make(
        _ mode: GameMode,
        insight: ModeInsight?,
        input: ModeInsightsInput,
        reason: String,
        bonus: Int
    ) -> ModeRecommendation {
        let title = mode == .timeAttack ? String(localized: "Zkus \(mode.title) \(input.timeAttack.title)") : String(localized: "Zkus \(mode.title)")
        let goal: String
        if let insight, insight.personalBest != nil {
            goal = String(localized: "Cíl: překonat \(insight.personalBest ?? "") → \(insight.goal.target)")
        } else {
            goal = String(localized: "Cíl: \(insight?.goal.target ?? String(localized: "dokončit"))")
        }
        return ModeRecommendation(
            mode: mode,
            configuration: .quick(mode, duration: input.timeAttack),
            title: title,
            goal: goal,
            reason: reason,
            reward: estimatedXP(for: mode, input: input) + bonus
        )
    }

    /// Odhad XP: dokončení + přesnost + rekord (stejná pravidla jako `XPRules`).
    static func estimatedXP(for mode: GameMode, input: ModeInsightsInput) -> Int {
        let wpm = input.speed.targetWPM ?? 15
        let characters: Int
        switch mode {
        case .practice: characters = ExerciseLength.medium.characterCount
        case .timeAttack: characters = Int(wpm * 5 * input.timeAttack.seconds / 60)
        case .sprint: characters = ModeRules.sprintLength
        case .accuracyChallenge: characters = ExerciseLength.medium.characterCount
        case .survival: characters = 150
        case .endless: characters = 300
        case .exam: characters = Int(wpm * 5 * input.exam.seconds / 60)
        case .customText: characters = 300
        case .speedTest: characters = Int(wpm * 5 * input.speedTest.seconds / 60)
        }
        var xp = XPRules.base(characters: characters, accuracy: 0.98, isFullExercise: true, maxCombo: 25).total
        xp += XPRules.recordBonus
        if mode == .accuracyChallenge { xp += XPRules.modeChallengeBonus }
        return xp
    }

    private static func roundUp(_ value: Double, to step: Double) -> Double {
        (value / step).rounded(.up) * step
    }
}
