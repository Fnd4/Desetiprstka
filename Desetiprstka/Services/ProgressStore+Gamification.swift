import Foundation
import SwiftData

/// Co přineslo jedno cvičení (pro obrazovku výsledků).
struct SessionOutcome {
    var xp = XPBreakdown()
    var levelBefore = PlayerLevel(totalXP: 0)
    var levelAfter = PlayerLevel(totalXP: 0)
    /// Rekordy, které byly překonány (první hodnoty se neohlašují).
    var newRecords: [RecordKind] = []
    var recordValues: [RecordKind: Double] = [:]
    var unlockedAchievements: [Achievement] = []
    var completedChallenge: DailyChallenge?
    var streak = 0
    var streakExtended = false
    var speedRecommendation: SpeedRecommendation?

    var leveledUp: Bool { levelAfter.level > levelBefore.level }
}

/// Gamifikace, rychlostní obtížnost a souhrnná data.
extension ProgressStore {
    // MARK: - Player progress

    /// Vrátí gamifikační profil. Při prvním spuštění v2 ho vytvoří
    /// a dopočítá XP, streak a rekordy ze stávající historie.
    @discardableResult
    func playerProgress() -> PlayerProgress {
        let descriptor = FetchDescriptor<PlayerProgress>(sortBy: [SortDescriptor(\.createdAt)])
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let progress = PlayerProgress()
        context.insert(progress)
        backfill(progress)
        save()
        return progress
    }

    func setSpeed(_ setting: SpeedSetting) {
        playerProgress().speedSetting = setting
        save()
    }

    private func backfill(_ progress: PlayerProgress) {
        let sessions = (try? context.fetch(FetchDescriptor<PracticeSession>(sortBy: [SortDescriptor(\.date)]))) ?? []
        guard !sessions.isEmpty else { return }

        var xp = 0
        var best: [RecordKind: Double] = [:]
        for session in sessions {
            progress.totalCharacters += session.characterCount
            progress.totalTypingTime += session.duration
            if session.isFullExercise {
                progress.totalSessions += 1
                if session.accuracy >= 1, session.characterCount >= 50 { progress.perfectSessions += 1 }
            }
            xp += XPRules.base(
                characters: session.characterCount,
                accuracy: session.accuracy,
                isFullExercise: session.isFullExercise,
                maxCombo: session.combo
            ).total

            if session.characterCount >= RecordEvaluator.minimumCharactersForWPM {
                best[.bestWPM] = max(best[.bestWPM] ?? 0, session.wpm)
            }
            if session.characterCount >= RecordEvaluator.minimumCharactersForAccuracy {
                best[.bestAccuracy] = max(best[.bestAccuracy] ?? 0, session.accuracy)
            }
            best[.mostCharacters] = max(best[.mostCharacters] ?? 0, Double(session.characterCount))
        }
        progress.totalXP = xp
        progress.streakState = StreakTracker.rebuild(from: sessions.filter { $0.isFullExercise }.map(\.date))

        let existingRecords = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        guard existingRecords.isEmpty else { return }
        let lastDate = sessions.last?.date ?? .now
        for (kind, value) in best where value > 0 {
            context.insert(PersonalRecord(kind: kind, value: value, date: lastDate))
        }
    }

    // MARK: - Rekordy

    func recordValues() -> [RecordKind: Double] {
        let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        var values: [RecordKind: Double] = [:]
        for record in records {
            if let kind = record.kind { values[kind] = record.value }
        }
        return values
    }

    /// Aktualizuje rekordy. Vrací překonané rekordy a aktuální hodnoty všech rekordů.
    func updateRecords(with result: SessionResult, at date: Date) -> (announced: [RecordKind], values: [RecordKind: Double]) {
        let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        var existing: [String: PersonalRecord] = [:]
        var values: [RecordKind: Double] = [:]
        for record in records {
            existing[record.kindRaw] = record
            if let kind = record.kind { values[kind] = record.value }
        }

        var announced: [RecordKind] = []
        for (kind, value) in RecordEvaluator.candidates(for: result) {
            if let record = existing[kind.rawValue] {
                if RecordEvaluator.isImprovement(value, over: record.value, kind: kind) {
                    record.value = value
                    record.date = date
                    values[kind] = value
                    announced.append(kind)
                }
            } else if value > 0 {
                // První hodnota se uloží potichu – „rekord“ z prvního pokusu nic neznamená.
                context.insert(PersonalRecord(kind: kind, value: value, date: date))
                values[kind] = value
            }
        }

        let order = RecordKind.allCases
        announced.sort { (order.firstIndex(of: $0) ?? 0) < (order.firstIndex(of: $1) ?? 0) }
        return (announced, values)
    }

    // MARK: - Odznaky

    func achievementContext(progress: PlayerProgress, profile: UserProfile, records: [RecordKind: Double]) -> AchievementContext {
        AchievementContext(
            totalSessions: Double(progress.totalSessions),
            totalCharacters: Double(progress.totalCharacters),
            bestWPM: records[.bestWPM] ?? 0,
            perfectSessions: Double(progress.perfectSessions),
            longestStreak: Double(progress.longestStreak),
            bestCombo: records[.longestCombo] ?? 0,
            learnedKeys: Double(profile.knownKeySet.intersection(Curriculum.allKeySet).count),
            dailyChallengesCompleted: Double(progress.dailyChallengesCompleted),
            bestSurvival: records[.survival] ?? 0
        )
    }

    func unlockedAchievementIDs() -> Set<String> {
        let records = (try? context.fetch(FetchDescriptor<AchievementRecord>())) ?? []
        return Set(records.map(\.achievementID))
    }

    /// Odemkne splněné odznaky a vrátí ty nové.
    func unlockAchievements(
        progress: PlayerProgress,
        profile: UserProfile,
        records: [RecordKind: Double],
        at date: Date
    ) -> [Achievement] {
        let unlocked = unlockedAchievementIDs()
        let snapshot = achievementContext(progress: progress, profile: profile, records: records)
        var newlyUnlocked: [Achievement] = []
        for achievement in AchievementCatalog.all
        where !unlocked.contains(achievement.id) && achievement.isUnlocked(in: snapshot) {
            context.insert(AchievementRecord(achievementID: achievement.id, unlockedAt: date))
            newlyUnlocked.append(achievement)
        }
        return newlyUnlocked
    }

    /// Kontrola mimo cvičení (např. po přidání písmen → Keyboard Master).
    @discardableResult
    func refreshAchievements() -> [Achievement] {
        let progress = playerProgress()
        let unlocked = unlockAchievements(
            progress: progress,
            profile: profile(),
            records: recordValues(),
            at: .now
        )
        if !unlocked.isEmpty {
            progress.totalXP += unlocked.count * XPRules.achievementBonus
            save()
        }
        return unlocked
    }

    // MARK: - Denní výzva

    /// Výzva pro daný den – při prvním dotazu se vygeneruje.
    @discardableResult
    func todaysChallengeRecord(now: Date = .now) -> DailyChallengeRecord {
        let key = DayKey.string(for: now)
        var descriptor = FetchDescriptor<DailyChallengeRecord>(predicate: #Predicate { $0.dayKey == key })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let challenge = DailyChallengeGenerator.make(for: now, ability: abilityProfile(now: now))
        let record = DailyChallengeRecord(challenge: challenge)
        context.insert(record)
        save()
        return record
    }

    /// Schopnosti uživatele z posledních dvou týdnů.
    func abilityProfile(now: Date = .now) -> AbilityProfile {
        let calendar = Calendar.current
        let since = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let descriptor = FetchDescriptor<PracticeSession>(
            predicate: #Predicate { $0.date >= since },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = ((try? context.fetch(descriptor)) ?? []).filter { $0.isFullExercise }

        var ability = AbilityProfile()
        let records = recordValues()
        if let combo = records[.longestCombo] { ability.bestCombo = Int(combo) }
        guard !sessions.isEmpty else { return ability }

        let latest = sessions.prefix(10)
        ability.averageWPM = latest.map(\.wpm).reduce(0, +) / Double(latest.count)
        ability.averageAccuracy = latest.map(\.accuracy).reduce(0, +) / Double(latest.count)

        let activeDays = Set(sessions.map { calendar.startOfDay(for: $0.date) }).count
        if activeDays > 0 {
            ability.averageDailyCharacters = Double(sessions.map(\.characterCount).reduce(0, +)) / Double(activeDays)
            ability.averageDailyMinutes = sessions.map(\.duration).reduce(0, +) / 60 / Double(activeDays)
        }
        return ability
    }

    // MARK: - Souhrny pro obrazovky

    /// Výkony posledních plnohodnotných cvičení (nejnovější první).
    func recentSpeedSamples(limit: Int) -> [SpeedSample] {
        var descriptor = FetchDescriptor<PracticeSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 30
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions
            .filter { $0.isFullExercise }
            .prefix(limit)
            .map { SpeedSample(wpm: $0.wpm, accuracy: $0.accuracy) }
    }

    /// Průměrná přesnost posledních cvičení (nebo `nil` bez historie).
    func recentAccuracy(limit: Int = 3) -> Double? {
        let samples = recentSpeedSamples(limit: limit)
        guard !samples.isEmpty else { return nil }
        return samples.map(\.accuracy).reduce(0, +) / Double(samples.count)
    }

    /// Doporučení rychlosti mimo výsledky (hlavní obrazovka).
    func currentSpeedRecommendation() -> SpeedRecommendation? {
        SpeedAdvisor().recommend(current: playerProgress().speedSetting, recent: recentSpeedSamples(limit: 5))
    }
}
