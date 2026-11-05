import Foundation
import SwiftData

/// Gamifikace a rychlostní obtížnost. Samostatná entita (v2) – nezasahuje do výuky
/// a díky tomu se stávající data při migraci vůbec nemění.
@Model
final class PlayerProgress {
    var totalXP: Int = 0
    var speedModeRaw: String = "easy"
    var customTargetWPM: Double = 25

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDay: Date?

    var totalSessions: Int = 0
    var totalCharacters: Int = 0
    var totalTypingTime: Double = 0
    var perfectSessions: Int = 0
    var dailyChallengesCompleted: Int = 0
    var createdAt: Date = Date()

    init() {
        self.createdAt = Date()
    }

    var speedMode: SpeedDifficulty {
        get { SpeedDifficulty(rawValue: speedModeRaw) ?? .easy }
        set { speedModeRaw = newValue.rawValue }
    }

    var speedSetting: SpeedSetting {
        get { SpeedSetting(mode: speedMode, customWPM: customTargetWPM) }
        set {
            speedMode = newValue.mode
            customTargetWPM = newValue.customWPM
        }
    }

    var streakState: StreakState {
        get { StreakState(current: currentStreak, longest: longestStreak, lastActiveDay: lastActiveDay) }
        set {
            currentStreak = newValue.current
            longestStreak = newValue.longest
            lastActiveDay = newValue.lastActiveDay
        }
    }

    var playerLevel: PlayerLevel { PlayerLevel(totalXP: totalXP) }
    var displayedStreak: Int { StreakTracker.displayedStreak(streakState) }
}

/// Osobní rekord jednoho druhu.
@Model
final class PersonalRecord {
    @Attribute(.unique) var kindRaw: String = ""
    var value: Double = 0
    var date: Date = Date()

    init(kind: RecordKind, value: Double, date: Date) {
        self.kindRaw = kind.rawValue
        self.value = value
        self.date = date
    }

    var kind: RecordKind? { RecordKind(rawValue: kindRaw) }
}

/// Odemčený odznak.
@Model
final class AchievementRecord {
    @Attribute(.unique) var achievementID: String = ""
    var unlockedAt: Date = Date()

    init(achievementID: String, unlockedAt: Date) {
        self.achievementID = achievementID
        self.unlockedAt = unlockedAt
    }
}

/// Denní výzva a její postup.
@Model
final class DailyChallengeRecord {
    @Attribute(.unique) var dayKey: String = ""
    var kindRaw: String = ""
    var target: Double = 0
    var reward: Int = 0
    var progress: Double = 0
    var completedAt: Date?

    init(challenge: DailyChallenge) {
        self.dayKey = challenge.dayKey
        self.kindRaw = challenge.kind.rawValue
        self.target = challenge.target
        self.reward = challenge.reward
    }

    var challenge: DailyChallenge? {
        guard let kind = DailyChallengeKind(rawValue: kindRaw) else { return nil }
        return DailyChallenge(dayKey: dayKey, kind: kind, target: target, reward: reward)
    }

    var isCompleted: Bool { completedAt != nil }
}
