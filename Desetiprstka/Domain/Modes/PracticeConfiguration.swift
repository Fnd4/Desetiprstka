import Foundation

/// Co si uživatel zvolil před spuštěním cvičení.
struct PracticeConfiguration: Equatable, Sendable {
    var mode: GameMode = .practice
    /// Aplikace sama zvolí nejlepší nastavení podle předchozích výsledků.
    var isAdaptive = true
    /// `nil` = úroveň podle pokroku.
    var textLevel: Int?
    /// `nil` = aktuální rychlostní obtížnost uživatele.
    var speed: SpeedDifficulty?
    var length: ExerciseLength?
    var duration: TimeAttackDuration = .seconds60
    var examDuration: ExamDuration = .minutes10
    var speedTestDuration: TimeAttackDuration = .seconds30
    /// Text pro režim Vlastní text.
    var customText: String?

    /// Okamžitý start bez nastavování.
    static let adaptive = PracticeConfiguration()

    static func quick(
        _ mode: GameMode,
        duration: TimeAttackDuration = .seconds60,
        examDuration: ExamDuration = .minutes10,
        speedTestDuration: TimeAttackDuration = .seconds30,
        customText: String? = nil
    ) -> PracticeConfiguration {
        PracticeConfiguration(
            mode: mode,
            isAdaptive: true,
            duration: duration,
            examDuration: examDuration,
            speedTestDuration: speedTestDuration,
            customText: customText
        )
    }
}

/// Konfigurace převedená na konkrétní hodnoty.
struct ResolvedPractice: Sendable {
    let mode: GameMode
    let difficulty: Difficulty
    let speed: SpeedSetting
    /// Délka prvního textu.
    let targetLength: Int
    let duration: TimeAttackDuration
    let examDuration: ExamDuration
    let speedTestDuration: TimeAttackDuration
    let customText: String?
    let maxErrors: Int
    let lives: Int
    /// Úroveň odpovídá pokroku → výsledek smí měnit obtížnost textu.
    let usesProfileLevel: Bool

    /// Časový limit (Time Attack, Zkouška).
    var timeLimit: TimeInterval? {
        switch mode {
        case .timeAttack: duration.seconds
        case .exam: examDuration.seconds
        case .speedTest: speedTestDuration.seconds
        default: nil
        }
    }

    var chunkLength: Int {
        mode == .survival ? ModeRules.survivalChunkLength : ModeRules.continuousChunkLength
    }
}

/// Převádí volbu uživatele (nebo Adaptive) na konkrétní plán cvičení.
struct PracticePlanner {
    func resolve(
        _ configuration: PracticeConfiguration,
        profileLevel: Int,
        speed: SpeedSetting,
        preferredLength: ExerciseLength,
        recentAccuracy: Double?
    ) -> ResolvedPractice {
        let mode = configuration.mode
        let level: Int
        let speedSetting: SpeedSetting
        let length: ExerciseLength

        if configuration.isAdaptive {
            level = profileLevel
            speedSetting = speed
            // Po slabší přesnosti volíme kratší text, ať se uživatel nevyčerpá.
            if let recentAccuracy, recentAccuracy < 0.9 {
                length = .short
            } else {
                length = preferredLength
            }
        } else {
            level = configuration.textLevel ?? profileLevel
            if let chosenSpeed = configuration.speed {
                speedSetting = SpeedSetting(mode: chosenSpeed, customWPM: speed.customWPM)
            } else {
                speedSetting = speed
            }
            length = configuration.length ?? preferredLength
        }

        let targetLength: Int
        switch mode {
        case .practice, .accuracyChallenge: targetLength = length.characterCount
        case .sprint: targetLength = ModeRules.sprintLength
        case .survival: targetLength = ModeRules.survivalChunkLength
        case .timeAttack, .endless, .exam, .speedTest: targetLength = ModeRules.continuousChunkLength
        case .customText: targetLength = configuration.customText?.count ?? 0
        }

        // Zkouška je vždy opis vět (z písmen, která uživatel zná).
        let resolvedLevel: Int
        switch mode {
        case .exam: resolvedLevel = max(level, Difficulty.firstSentenceLevel)
        // Test rychlosti = běžná slova bez interpunkce, stejné pro všechny.
        case .speedTest: resolvedLevel = Difficulty.speedTestLevel
        default: resolvedLevel = level
        }

        return ResolvedPractice(
            mode: mode,
            difficulty: Difficulty(level: resolvedLevel),
            speed: speedSetting,
            targetLength: targetLength,
            duration: configuration.duration,
            examDuration: configuration.examDuration,
            speedTestDuration: configuration.speedTestDuration,
            customText: configuration.customText,
            maxErrors: ModeRules.accuracyMaxErrors,
            lives: ModeRules.survivalLives,
            usesProfileLevel: level == profileLevel
        )
    }
}
