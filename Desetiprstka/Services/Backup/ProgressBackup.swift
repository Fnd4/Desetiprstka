import Foundation
import SwiftData
import CryptoKit
import UniformTypeIdentifiers

/// Záloha celého progresu do jednoho souboru `.desetiprstka`.
/// Obsahuje profil, historii, statistiky kláves, XP, rekordy, odznaky, denní výzvy a nastavení.
/// Soubor je zkomprimovaný a zašifrovaný (AES-GCM) – nejde přečíst ani upravit,
/// a jakákoli změna obsahu se při obnově pozná.
struct ProgressBackup: Codable {
    static let formatID = "desetiprstka-backup"
    static let currentVersion = 1

    var format: String = formatID
    var version: Int = currentVersion
    var appVersion: String
    var exportedAt: Date

    var profile: Profile?
    var player: Player?
    var sessions: [Session]
    var letterStats: [Letter]
    var records: [Record]
    var achievements: [Achievement]
    var dailyChallenges: [Challenge]
    var settings: [String: SettingValue]

    struct Profile: Codable {
        var knownKeys: [String]
        var introducedKeys: [String]
        var level: Int
        var goodStreak: Int
        var hasCompletedOnboarding: Bool
        var createdAt: Date
    }

    struct Player: Codable {
        var totalXP: Int
        var speedModeRaw: String
        var customTargetWPM: Double
        var currentStreak: Int
        var longestStreak: Int
        var lastActiveDay: Date?
        var totalSessions: Int
        var totalCharacters: Int
        var totalTypingTime: Double
        var perfectSessions: Int
        var dailyChallengesCompleted: Int
        var createdAt: Date
    }

    struct Session: Codable {
        var date: Date
        var duration: Double
        var wpm: Double
        var accuracy: Double
        var errorCount: Int
        var keystrokes: Int
        var characterCount: Int
        var level: Int
        var text: String
        var problemKeys: [String]
        var modeRaw: String?
        var maxCombo: Int?
        var xpEarned: Int?
        var score: Int?
        var targetWPM: Double?
        var timeLimit: Int?
        var completed: Bool?
        var rhythm: Double?
    }

    struct Letter: Codable {
        var key: String
        var attempts: Int
        var errors: Int
        var recentAttempts: Double
        var recentErrors: Double
        var lastPracticed: Date?
        var reactionTimeTotal: Double?
        var reactionSamples: Int?
    }

    struct Record: Codable {
        var kindRaw: String
        var value: Double
        var date: Date
    }

    struct Achievement: Codable {
        var achievementID: String
        var unlockedAt: Date
    }

    struct Challenge: Codable {
        var dayKey: String
        var kindRaw: String
        var target: Double
        var reward: Int
        var progress: Double
        var completedAt: Date?
    }

    /// Hodnota z UserDefaults, kterou umí JSON.
    enum SettingValue: Codable, Equatable {
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case strings([String])

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let v = try? c.decode(Bool.self) { self = .bool(v) }
            else if let v = try? c.decode(Int.self) { self = .int(v) }
            else if let v = try? c.decode(Double.self) { self = .double(v) }
            else if let v = try? c.decode(String.self) { self = .string(v) }
            else { self = .strings(try c.decode([String].self)) }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .bool(let v): try c.encode(v)
            case .int(let v): try c.encode(v)
            case .double(let v): try c.encode(v)
            case .string(let v): try c.encode(v)
            case .strings(let v): try c.encode(v)
            }
        }

        var plistValue: Any {
            switch self {
            case .bool(let v): v
            case .int(let v): v
            case .double(let v): v
            case .string(let v): v
            case .strings(let v): v
            }
        }
    }

    /// Krátké shrnutí pro potvrzovací dialog.
    var summary: String {
        let level = PlayerLevel(totalXP: player?.totalXP ?? 0).level
        let date = exportedAt.formatted(date: .long, time: .shortened)
        return String(localized: "Záloha z \(date): \(sessions.count) cvičení, level \(level), \(achievements.count) odznaků.")
    }
}

enum BackupError: LocalizedError {
    case notABackup
    case tampered
    case newerVersion(Int)

    var errorDescription: String? {
        switch self {
        case .notABackup:
            String(localized: "Tenhle soubor není záloha Desetiprstky.")
        case .tampered:
            String(localized: "Záloha je poškozená nebo byla upravena, proto ji nejde obnovit.")
        case .newerVersion(let v):
            String(localized: "Záloha pochází z novější verze Desetiprstky (formát \(v)). Aktualizuj aplikaci a zkus to znovu.")
        }
    }
}

/// Vytvoření a obnova zálohy.
@MainActor
enum BackupService {
    /// Předpony klíčů v UserDefaults, které patří k nastavení appky.
    static let settingPrefixes = ["settings.", "appearance.", "audio.", "modes.", "home."]

    // MARK: Export

    static func makeBackup(context: ModelContext, defaults: UserDefaults = .standard) throws -> ProgressBackup {
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        let player = try context.fetch(FetchDescriptor<PlayerProgress>(sortBy: [SortDescriptor(\.createdAt)])).first
        let sessions = try context.fetch(FetchDescriptor<PracticeSession>(sortBy: [SortDescriptor(\.date)]))
        let letters = try context.fetch(FetchDescriptor<LetterStat>(sortBy: [SortDescriptor(\.key)]))
        let records = try context.fetch(FetchDescriptor<PersonalRecord>())
        let achievements = try context.fetch(FetchDescriptor<AchievementRecord>())
        let challenges = try context.fetch(FetchDescriptor<DailyChallengeRecord>(sortBy: [SortDescriptor(\.dayKey)]))

        return ProgressBackup(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            exportedAt: Date(),
            profile: profile.map {
                .init(knownKeys: $0.knownKeys, introducedKeys: $0.introducedKeys, level: $0.level,
                      goodStreak: $0.goodStreak, hasCompletedOnboarding: $0.hasCompletedOnboarding, createdAt: $0.createdAt)
            },
            player: player.map {
                .init(totalXP: $0.totalXP, speedModeRaw: $0.speedModeRaw, customTargetWPM: $0.customTargetWPM,
                      currentStreak: $0.currentStreak, longestStreak: $0.longestStreak, lastActiveDay: $0.lastActiveDay,
                      totalSessions: $0.totalSessions, totalCharacters: $0.totalCharacters, totalTypingTime: $0.totalTypingTime,
                      perfectSessions: $0.perfectSessions, dailyChallengesCompleted: $0.dailyChallengesCompleted, createdAt: $0.createdAt)
            },
            sessions: sessions.map {
                .init(date: $0.date, duration: $0.duration, wpm: $0.wpm, accuracy: $0.accuracy, errorCount: $0.errorCount,
                      keystrokes: $0.keystrokes, characterCount: $0.characterCount, level: $0.level, text: $0.text,
                      problemKeys: $0.problemKeys, modeRaw: $0.modeRaw, maxCombo: $0.maxCombo, xpEarned: $0.xpEarned,
                      score: $0.score, targetWPM: $0.targetWPM, timeLimit: $0.timeLimit, completed: $0.completed, rhythm: $0.rhythm)
            },
            letterStats: letters.map {
                .init(key: $0.key, attempts: $0.attempts, errors: $0.errors, recentAttempts: $0.recentAttempts,
                      recentErrors: $0.recentErrors, lastPracticed: $0.lastPracticed,
                      reactionTimeTotal: $0.reactionTimeTotal, reactionSamples: $0.reactionSamples)
            },
            records: records.map { .init(kindRaw: $0.kindRaw, value: $0.value, date: $0.date) },
            achievements: achievements.map { .init(achievementID: $0.achievementID, unlockedAt: $0.unlockedAt) },
            dailyChallenges: challenges.map {
                .init(dayKey: $0.dayKey, kindRaw: $0.kindRaw, target: $0.target, reward: $0.reward,
                      progress: $0.progress, completedAt: $0.completedAt)
            },
            settings: exportSettings(from: defaults)
        )
    }

    static func exportSettings(from defaults: UserDefaults) -> [String: ProgressBackup.SettingValue] {
        var result: [String: ProgressBackup.SettingValue] = [:]
        for (key, value) in defaults.dictionaryRepresentation()
        where settingPrefixes.contains(where: { key.hasPrefix($0) }) {
            if let number = value as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() { result[key] = .bool(number.boolValue) }
                else if CFNumberIsFloatType(number) { result[key] = .double(number.doubleValue) }
                else { result[key] = .int(number.intValue) }
            } else if let string = value as? String {
                result[key] = .string(string)
            } else if let strings = value as? [String] {
                result[key] = .strings(strings)
            }
        }
        return result
    }

    /// Typ souboru zálohy (přípona .desetiprstka).
    nonisolated static let fileType = UTType(filenameExtension: "desetiprstka", conformingTo: .data) ?? .data

    /// Hlavička souboru – zároveň autentizovaná data šifry.
    private static let magic = Data("DPZ1".utf8)

    /// JSON → zlib → AES-GCM. Výsledek nejde číst ani upravit bez klíče.
    static func encode(_ backup: ProgressBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(backup)
        let compressed = try (json as NSData).compressed(using: .zlib) as Data
        let box = try AES.GCM.seal(compressed, using: BackupKey.key, authenticating: magic)
        guard let combined = box.combined else { throw BackupError.notABackup }
        return magic + combined
    }

    static func decode(_ sealed: Data) throws -> ProgressBackup {
        guard sealed.count > magic.count + 28, sealed.prefix(magic.count) == magic else {
            throw BackupError.notABackup
        }
        let data: Data
        do {
            let box = try AES.GCM.SealedBox(combined: sealed.dropFirst(magic.count))
            let compressed = try AES.GCM.open(box, using: BackupKey.key, authenticating: magic)
            data = try (compressed as NSData).decompressed(using: .zlib) as Data
        } catch {
            throw BackupError.tampered
        }
        struct Header: Decodable { var format: String?; var version: Int? }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let header = try? decoder.decode(Header.self, from: data),
              header.format == ProgressBackup.formatID else { throw BackupError.notABackup }
        if let version = header.version, version > ProgressBackup.currentVersion {
            throw BackupError.newerVersion(version)
        }
        do { return try decoder.decode(ProgressBackup.self, from: data) }
        catch { throw BackupError.notABackup }
    }

    static func suggestedFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return String(localized: "Desetiprstka záloha \(formatter.string(from: date))")
    }

    // MARK: Obnova

    /// Pojistka: aktuální stav se před obnovou uloží do Application Support/Desetiprstka/Zálohy.
    @discardableResult
    static func writeSafetyBackup(context: ModelContext) throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let folder = base.appendingPathComponent("Desetiprstka/Zálohy", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("před obnovou \(stamp).desetiprstka")
        try encode(try makeBackup(context: context)).write(to: url, options: .atomic)
        return url
    }

    /// Nahradí veškerý progres obsahem zálohy.
    static func restore(_ backup: ProgressBackup, context: ModelContext, defaults: UserDefaults = .standard) throws {
        try writeSafetyBackup(context: context)

        try deleteAll(UserProfile.self, in: context)
        try deleteAll(PlayerProgress.self, in: context)
        try deleteAll(PracticeSession.self, in: context)
        try deleteAll(LetterStat.self, in: context)
        try deleteAll(PersonalRecord.self, in: context)
        try deleteAll(AchievementRecord.self, in: context)
        try deleteAll(DailyChallengeRecord.self, in: context)
        try context.save()

        if let p = backup.profile {
            let profile = UserProfile(knownKeys: p.knownKeys)
            profile.introducedKeys = p.introducedKeys
            profile.level = p.level
            profile.goodStreak = p.goodStreak
            profile.hasCompletedOnboarding = p.hasCompletedOnboarding
            profile.createdAt = p.createdAt
            context.insert(profile)
        }

        if let p = backup.player {
            let player = PlayerProgress()
            player.totalXP = p.totalXP
            player.speedModeRaw = p.speedModeRaw
            player.customTargetWPM = p.customTargetWPM
            player.currentStreak = p.currentStreak
            player.longestStreak = p.longestStreak
            player.lastActiveDay = p.lastActiveDay
            player.totalSessions = p.totalSessions
            player.totalCharacters = p.totalCharacters
            player.totalTypingTime = p.totalTypingTime
            player.perfectSessions = p.perfectSessions
            player.dailyChallengesCompleted = p.dailyChallengesCompleted
            player.createdAt = p.createdAt
            context.insert(player)
        }

        for s in backup.sessions {
            let session = PracticeSession()
            session.date = s.date
            session.duration = s.duration
            session.wpm = s.wpm
            session.accuracy = s.accuracy
            session.errorCount = s.errorCount
            session.keystrokes = s.keystrokes
            session.characterCount = s.characterCount
            session.level = s.level
            session.text = s.text
            session.problemKeys = s.problemKeys
            session.modeRaw = s.modeRaw
            session.maxCombo = s.maxCombo
            session.xpEarned = s.xpEarned
            session.score = s.score
            session.targetWPM = s.targetWPM
            session.timeLimit = s.timeLimit
            session.completed = s.completed
            session.rhythm = s.rhythm
            context.insert(session)
        }

        for l in backup.letterStats {
            let stat = LetterStat(key: l.key)
            stat.attempts = l.attempts
            stat.errors = l.errors
            stat.recentAttempts = l.recentAttempts
            stat.recentErrors = l.recentErrors
            stat.lastPracticed = l.lastPracticed
            stat.reactionTimeTotal = l.reactionTimeTotal
            stat.reactionSamples = l.reactionSamples
            context.insert(stat)
        }

        for r in backup.records {
            guard let kind = RecordKind(rawValue: r.kindRaw) else { continue }
            context.insert(PersonalRecord(kind: kind, value: r.value, date: r.date))
        }

        for a in backup.achievements {
            context.insert(AchievementRecord(achievementID: a.achievementID, unlockedAt: a.unlockedAt))
        }

        for c in backup.dailyChallenges {
            guard let kind = DailyChallengeKind(rawValue: c.kindRaw) else { continue }
            let record = DailyChallengeRecord(challenge: DailyChallenge(dayKey: c.dayKey, kind: kind, target: c.target, reward: c.reward))
            record.progress = c.progress
            record.completedAt = c.completedAt
            context.insert(record)
        }

        try context.save()

        for (key, value) in backup.settings where settingPrefixes.contains(where: { key.hasPrefix($0) }) {
            defaults.set(value.plistValue, forKey: key)
        }
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<T>()) {
            context.delete(item)
        }
    }
}

/// Klíč pro šifrování záloh.
/// Oficiální build má vlastní tajný klíč v `Resources/backupkey.dat` (není v gitu).
/// Build ze zdrojáků bez něj použije vývojový klíč – jeho zálohy jsou s oficiální appkou nekompatibilní.
enum BackupKey {
    static let key: SymmetricKey = {
        if let url = Bundle.main.url(forResource: "backupkey", withExtension: "dat"),
           let data = try? Data(contentsOf: url), data.count == 32 {
            return SymmetricKey(data: data)
        }
        return SymmetricKey(data: SHA256.hash(data: Data("desetiprstka-dev-backup-key".utf8)))
    }()
}
