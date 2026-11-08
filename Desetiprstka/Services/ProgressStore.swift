import Foundation
import SwiftData

/// Jediné místo, které zapisuje do databáze.
/// Views čtou data přes `@Query`, změny dělají přes tuto službu.
@MainActor
struct ProgressStore {
    let context: ModelContext

    // MARK: - Profil

    /// Vrátí profil, případně ho při prvním spuštění vytvoří.
    @discardableResult
    func profile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        save()
        return profile
    }

    func completeOnboarding(knownKeys: Set<String>, markAsIntroduced: Bool) {
        let profile = self.profile()
        profile.knownKeys = Curriculum.sorted(knownKeys)
        if markAsIntroduced {
            profile.introducedKeys = Curriculum.sorted(Set(profile.introducedKeys).union(knownKeys))
        }
        profile.hasCompletedOnboarding = true
        save()
    }

    // MARK: - Známé klávesy

    /// Přepne klávesu. Vrací `false`, pokud by zůstalo příliš málo písmen.
    @discardableResult
    func toggleKey(_ key: String) -> Bool {
        var keys = profile().knownKeySet
        if keys.contains(key) {
            keys.remove(key)
        } else {
            keys.insert(key)
        }
        return setKnownKeys(keys)
    }

    /// Přidá nebo odebere celou skupinu kláves (např. lekci).
    @discardableResult
    func setKeys(_ group: [String], known: Bool) -> Bool {
        var keys = profile().knownKeySet
        if known {
            keys.formUnion(group)
        } else {
            keys.subtract(group)
        }
        return setKnownKeys(keys)
    }

    func addKnownKey(_ key: String) {
        var keys = profile().knownKeySet
        keys.insert(key)
        setKnownKeys(keys)
    }

    @discardableResult
    func setKnownKeys(_ keys: Set<String>) -> Bool {
        guard Curriculum.letterCount(in: keys) >= Curriculum.minimumLetters else { return false }
        profile().knownKeys = Curriculum.sorted(keys)
        save()
        return true
    }

    func markIntroduced(_ keys: [String]) {
        let profile = self.profile()
        profile.introducedKeys = Curriculum.sorted(Set(profile.introducedKeys).union(keys))
        save()
    }

    // MARK: - Statistiky

    func snapshots() -> [String: LetterStatSnapshot] {
        let stats = (try? context.fetch(FetchDescriptor<LetterStat>())) ?? []
        return Dictionary(stats.map { ($0.key, $0.snapshot) }, uniquingKeysWith: { first, _ in first })
    }

    /// Uloží výsledek cvičení: historie, statistiky kláves, úroveň textu
    /// (jen u klasického cvičení) a gamifikace (XP, streak, rekordy, výzvy, odznaky).
    @discardableResult
    func record(_ result: SessionResult, evaluation: AdaptiveEngine.Evaluation?) -> SessionOutcome {
        let profile = self.profile()
        let progress = playerProgress()
        let now = result.finishedAt
        let previousSamples = recentSpeedSamples(limit: 4)

        var outcome = SessionOutcome()
        outcome.levelBefore = progress.playerLevel

        // Bez jediného správného znaku není co ukládat (např. hned prohraná výzva).
        guard result.characters > 0 else {
            outcome.levelAfter = progress.playerLevel
            outcome.streak = progress.displayedStreak
            outcome.recordValues = recordValues()
            return outcome
        }

        let session = PracticeSession(result: result)
        context.insert(session)
        updateLetterStats(with: result)

        // Výuka – obtížnost textu (nezávislá na gamifikaci).
        if let evaluation {
            profile.level = evaluation.next.level
            profile.goodStreak = evaluation.goodStreak
        }

        // Souhrny a denní série.
        progress.totalCharacters += result.characters
        progress.totalTypingTime += result.duration
        if result.isFullExercise {
            progress.totalSessions += 1
            if result.accuracy >= 1, result.characters >= 50 { progress.perfectSessions += 1 }
            let before = progress.streakState
            let after = StreakTracker.register(activityOn: now, state: before)
            outcome.streakExtended = after.current != before.current
            progress.streakState = after
        }
        outcome.streak = progress.displayedStreak

        // Rekordy.
        let records = updateRecords(with: result, at: now)
        outcome.newRecords = records.announced
        outcome.recordValues = records.values

        // Denní výzva.
        let challengeRecord = todaysChallengeRecord(now: now)
        if let challenge = challengeRecord.challenge, !challengeRecord.isCompleted {
            challengeRecord.progress = challenge.updatedProgress(challengeRecord.progress, with: result)
            if challenge.isComplete(challengeRecord.progress) {
                challengeRecord.completedAt = now
                progress.dailyChallengesCompleted += 1
                outcome.completedChallenge = challenge
            }
        }

        // Odznaky.
        outcome.unlockedAchievements = unlockAchievements(
            progress: progress, profile: profile, records: records.values, at: now
        )

        // XP.
        var xp = XPRules.base(
            characters: result.characters,
            accuracy: result.accuracy,
            isFullExercise: result.isFullExercise,
            maxCombo: result.maxCombo
        )
        if !outcome.newRecords.isEmpty {
            xp.add(String(localized: "Osobní rekord"), outcome.newRecords.count * XPRules.recordBonus)
        }
        if result.mode == .accuracyChallenge, result.completed {
            xp.add(String(localized: "Accuracy Challenge splněna"), XPRules.modeChallengeBonus)
        }
        if let challenge = outcome.completedChallenge {
            xp.add(String(localized: "Denní výzva"), challenge.reward)
        }
        if !outcome.unlockedAchievements.isEmpty {
            xp.add(String(localized: "Nové odznaky"), outcome.unlockedAchievements.count * XPRules.achievementBonus)
        }
        progress.totalXP += xp.total
        session.xpEarned = xp.total
        outcome.xp = xp
        outcome.levelAfter = progress.playerLevel

        // Doporučení rychlosti.
        var samples = previousSamples
        if result.isFullExercise {
            samples.insert(SpeedSample(wpm: result.wpm, accuracy: result.accuracy), at: 0)
        }
        outcome.speedRecommendation = SpeedAdvisor().recommend(current: progress.speedSetting, recent: samples)

        save()
        return outcome
    }

    private func updateLetterStats(with result: SessionResult) {
        let stats = (try? context.fetch(FetchDescriptor<LetterStat>())) ?? []
        var existing = Dictionary(stats.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })

        let keys = Set(result.keyAttempts.keys).union(result.keyErrors.keys)
        for key in keys {
            let stat: LetterStat
            if let found = existing[key] {
                stat = found
            } else {
                stat = LetterStat(key: key)
                context.insert(stat)
                existing[key] = stat
            }
            stat.register(
                attempts: result.keyAttempts[key] ?? 0,
                errors: result.keyErrors[key] ?? 0,
                reactionTotal: result.keyReactionTotals[key] ?? 0,
                reactionCount: result.keyReactionCounts[key] ?? 0,
                at: result.finishedAt
            )
        }
    }

    func deleteSessions(_ sessions: [PracticeSession]) {
        sessions.forEach { context.delete($0) }
        save()
    }

    /// Smaže historii, statistiky a gamifikaci, vrátí úroveň na začátek.
    /// Známá písmena a nastavení rychlosti zůstávají.
    func resetAllProgress() {
        deleteAll(PracticeSession.self)
        deleteAll(LetterStat.self)
        deleteAll(PersonalRecord.self)
        deleteAll(AchievementRecord.self)
        deleteAll(DailyChallengeRecord.self)

        let profile = self.profile()
        profile.level = 1
        profile.goodStreak = 0

        let progress = playerProgress()
        let speed = progress.speedSetting
        context.delete(progress)
        let fresh = PlayerProgress()
        fresh.speedSetting = speed
        context.insert(fresh)
        save()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let items = (try? context.fetch(FetchDescriptor<T>())) ?? []
        items.forEach { context.delete($0) }
    }

    // MARK: -

    func save() {
        do {
            try context.save()
        } catch {
            print("Uložení selhalo: \(error)")
        }
    }
}
