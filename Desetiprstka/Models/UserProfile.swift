import Foundation
import SwiftData

/// Profil uživatele – v databázi existuje vždy právě jeden.
@Model
final class UserProfile {
    /// Klávesy, které uživatel umí (písmena, interpunkce, „⇧“ pro Shift).
    var knownKeys: [String] = []
    /// Klávesy, ke kterým už viděl úvodní představení.
    var introducedKeys: [String] = []
    /// Úroveň obtížnosti 1–12.
    var level: Int = 1
    /// Počet po sobě jdoucích dobrých cvičení na aktuální úrovni.
    var goodStreak: Int = 0
    var hasCompletedOnboarding: Bool = false
    var createdAt: Date = Date()

    init(knownKeys: [String] = Curriculum.beginnerKeys) {
        self.knownKeys = knownKeys
        self.introducedKeys = []
        self.level = 1
        self.goodStreak = 0
        self.hasCompletedOnboarding = false
        self.createdAt = Date()
    }

    var knownKeySet: Set<String> { Set(knownKeys) }
    var difficulty: Difficulty { Difficulty(level: level) }
}
