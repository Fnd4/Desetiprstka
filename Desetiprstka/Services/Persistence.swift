import Foundation
import SwiftData

/// Vytvoření lokální databáze (SwiftData).
///
/// Migrace v2: nové entity (`PlayerProgress`, `PersonalRecord`, `AchievementRecord`,
/// `DailyChallengeRecord`) a pouze volitelné nové atributy u stávajících entit.
/// To je lehká migrace, kterou SwiftData provede automaticky a stávající data zachová.
/// Pro jistotu se před prvním otevřením v2 vytvoří záloha databáze.
enum Persistence {
    static let schema = Schema([
        UserProfile.self,
        PracticeSession.self,
        LetterStat.self,
        PlayerProgress.self,
        PersonalRecord.self,
        AchievementRecord.self,
        DailyChallengeRecord.self,
    ])

    /// Označení zálohy pořízené před migrací na v2.
    private static let backupSuffix = "backup-v1"

    /// Databáze uložená v ~/Library/Application Support (v sandboxu aplikace).
    static func makeContainer() -> ModelContainer {
        do {
            let url = try storeURL()
            backUpStoreIfNeeded(at: url)
            let configuration = ModelConfiguration(schema: schema, url: url)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Nepodařilo se otevřít databázi: \(error)")
        }
    }

    /// Databáze jen v paměti – pro náhledy v Xcode.
    static func makePreviewContainer() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Nepodařilo se vytvořit náhledovou databázi: \(error)")
        }
    }

    private static func storeURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("Desetiprstka", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Desetiprstka.store")
    }

    /// Jednorázová kopie databáze (včetně -wal a -shm) před migrací.
    private static func backUpStoreIfNeeded(at url: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return }

        let directory = url.deletingLastPathComponent()
        let marker = directory.appendingPathComponent("\(url.lastPathComponent).\(backupSuffix)")
        guard !fileManager.fileExists(atPath: marker.path) else { return }

        for suffix in ["", "-wal", "-shm"] {
            let source = directory.appendingPathComponent(url.lastPathComponent + suffix)
            let destination = directory.appendingPathComponent("\(url.lastPathComponent).\(backupSuffix)\(suffix)")
            guard fileManager.fileExists(atPath: source.path) else { continue }
            do {
                try fileManager.copyItem(at: source, to: destination)
            } catch {
                print("Záloha databáze se nepodařila: \(error)")
            }
        }
    }
}
