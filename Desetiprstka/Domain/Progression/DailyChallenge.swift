import Foundation

/// Typ denní výzvy.
enum DailyChallengeKind: String, CaseIterable, Codable, Sendable {
    case reachWPM
    case typeCharacters
    case accuracy
    case maxErrors
    case practiceMinutes
    case combo

    var symbol: String {
        switch self {
        case .reachWPM: "speedometer"
        case .typeCharacters: "character.cursor.ibeam"
        case .accuracy: "target"
        case .maxErrors: "checkmark.shield"
        case .practiceMinutes: "clock"
        case .combo: "bolt"
        }
    }

    /// Hodnota se sčítá přes všechna cvičení dne.
    var isCumulative: Bool { self == .typeCharacters || self == .practiceMinutes }
}

/// Souhrn schopností uživatele – podle něj se nastavuje obtížnost výzvy.
struct AbilityProfile: Sendable {
    var averageWPM: Double?
    var averageAccuracy: Double?
    var averageDailyCharacters: Double?
    var averageDailyMinutes: Double?
    var bestCombo: Int?

    static let empty = AbilityProfile()
}

/// Jedna denní výzva.
struct DailyChallenge: Equatable, Sendable {
    let dayKey: String
    let kind: DailyChallengeKind
    let target: Double
    let reward: Int

    /// Minimální délka cvičení, které se počítá (u jednorázových výzev).
    static let minimumCharacters = 40
    static let maxErrorsMinimumCharacters = 100
    static let accuracyMinimumCharacters = 80

    var title: String {
        switch kind {
        case .reachWPM: "Dosáhni \(Int(target)) WPM"
        case .typeCharacters: "Napiš dnes \(Int(target)) znaků"
        case .accuracy: "Dokonči cvičení s přesností \(Int((target * 100).rounded())) %"
        case .maxErrors: "Cvičení s nejvýše \(Int(target)) chybami"
        case .practiceMinutes: "Piš dnes celkem \(Int(target)) minut"
        case .combo: "Napiš \(Int(target)) znaků v řadě bez chyby"
        }
    }

    var detail: String {
        switch kind {
        case .reachWPM: "V jednom cvičení (alespoň \(Self.minimumCharacters) znaků)."
        case .typeCharacters: "Počítají se všechna dnešní cvičení."
        case .accuracy: "Cvičení musí mít alespoň \(Self.accuracyMinimumCharacters) znaků."
        case .maxErrors: "Cvičení musí mít alespoň \(Self.maxErrorsMinimumCharacters) znaků."
        case .practiceMinutes: "Počítá se čas psaní ve všech režimech."
        case .combo: "Jakýkoliv režim – stačí jedna nepřerušená série."
        }
    }

    /// Nový stav postupu po cvičení.
    func updatedProgress(_ progress: Double, with result: SessionResult) -> Double {
        switch kind {
        case .typeCharacters:
            return progress + Double(result.characters)
        case .practiceMinutes:
            return progress + result.duration / 60
        case .reachWPM:
            guard result.characters >= Self.minimumCharacters else { return progress }
            return max(progress, result.wpm)
        case .accuracy:
            guard result.characters >= Self.accuracyMinimumCharacters else { return progress }
            return max(progress, result.accuracy)
        case .maxErrors:
            guard result.characters >= Self.maxErrorsMinimumCharacters,
                  result.errors <= Int(target), result.completed else { return progress }
            return 1
        case .combo:
            return max(progress, Double(result.maxCombo))
        }
    }

    func isComplete(_ progress: Double) -> Bool {
        kind == .maxErrors ? progress >= 1 : progress >= target - 0.000_1
    }

    /// 0–1 pro progress bar.
    func fraction(_ progress: Double) -> Double {
        if kind == .maxErrors { return progress >= 1 ? 1 : 0 }
        guard target > 0 else { return 0 }
        return min(max(progress / target, 0), 1)
    }

    func formattedProgress(_ progress: Double) -> String {
        switch kind {
        case .reachWPM: "\(Int(progress.rounded())) / \(Int(target)) WPM"
        case .typeCharacters: "\(Int(progress)) / \(Int(target)) znaků"
        case .accuracy: "\(Int((progress * 100).rounded())) / \(Int((target * 100).rounded())) %"
        case .maxErrors: progress >= 1 ? "Splněno" : "Zatím nesplněno"
        case .practiceMinutes: "\(Int(progress)) / \(Int(target)) min"
        case .combo: "\(Int(progress)) / \(Int(target))"
        }
    }
}

/// Vytváří výzvu dne – stejný den vždy stejný typ, cíl podle schopností.
enum DailyChallengeGenerator {
    static func make(for date: Date, ability: AbilityProfile, calendar: Calendar = .current) -> DailyChallenge {
        var rng = SeededRandomGenerator(seed: DayKey.number(for: date, calendar: calendar))
        let kinds = DailyChallengeKind.allCases
        let kind = kinds[Int.random(in: 0..<kinds.count, using: &rng)]
        let dayKey = DayKey.string(for: date, calendar: calendar)

        let target: Double
        let reward: Int
        switch kind {
        case .reachWPM:
            let average = ability.averageWPM ?? 10
            target = max(10, (average * 1.1).rounded(.up))
            reward = 60
        case .typeCharacters:
            let daily = ability.averageDailyCharacters ?? 300
            target = min(max((daily * 1.2 / 50).rounded() * 50, 300), 3000)
            reward = 50
        case .accuracy:
            let average = ability.averageAccuracy ?? 0.9
            target = average >= 0.96 ? 0.98 : (average >= 0.92 ? 0.96 : 0.94)
            reward = 60
        case .maxErrors:
            let average = ability.averageAccuracy ?? 0.9
            target = average >= 0.95 ? 2 : 4
            reward = 60
        case .practiceMinutes:
            let minutes = ability.averageDailyMinutes ?? 4
            target = min(max((minutes * 1.2).rounded(), 3), 20)
            reward = 50
        case .combo:
            let best = Double(ability.bestCombo ?? 20)
            target = max(15, (best * 0.7 / 5).rounded() * 5)
            reward = 70
        }
        return DailyChallenge(dayKey: dayKey, kind: kind, target: target, reward: reward)
    }
}
