import Foundation

/// Herní režimy.
enum GameMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case practice
    case timeAttack
    case sprint
    case accuracyChallenge
    case survival
    case endless
    /// Opis na čas hodnocený jako ve škole (čisté úhozy, chybovost, známka).
    case exam
    /// Opis vlastního textu.
    case customText
    /// Klasický test rychlosti (jako Monkeytype) – výsledek ve všech jednotkách.
    case speedTest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .practice: "Practice"
        case .timeAttack: "Time Attack"
        case .sprint: "Sprint"
        case .accuracyChallenge: "Accuracy Challenge"
        case .survival: "Survival"
        case .endless: "Endless"
        case .exam: "Zkouška"
        case .customText: "Vlastní text"
        case .speedTest: "Test rychlosti"
        }
    }

    var subtitle: String {
        switch self {
        case .practice: "Klasické cvičení s adaptivní obtížností."
        case .timeAttack: "Napiš co nejvíc správných znaků za daný čas."
        case .sprint: "Krátký text – dokonči ho co nejrychleji."
        case .accuracyChallenge: "Dokonči text s nejvýše \(ModeRules.accuracyMaxErrors) chybami."
        case .survival: "\(ModeRules.survivalLives) životy. Každá vlna je těžší a rychlejší."
        case .endless: "Nekonečný text. Skončíš, až budeš chtít."
        case .exam: "Opis na čas. Čisté úhozy, chybovost a známka jako ve škole."
        case .customText: "Opiš libovolný text – článek, poznámky nebo úkol do školy."
        case .speedTest: "Běžná slova na čas. Výsledek ve WPM, CPM i úhozech – porovnatelný se světem."
        }
    }

    var symbol: String {
        switch self {
        case .practice: "keyboard"
        case .timeAttack: "timer"
        case .sprint: "flag.checkered"
        case .accuracyChallenge: "scope"
        case .survival: "heart"
        case .endless: "infinity"
        case .exam: "graduationcap"
        case .customText: "doc.on.clipboard"
        case .speedTest: "speedometer"
        }
    }

    /// Text se během psaní průběžně doplňuje.
    var usesContinuousText: Bool {
        switch self {
        case .timeAttack, .survival, .endless, .exam, .speedTest: true
        case .practice, .sprint, .accuracyChallenge, .customText: false
        }
    }

    /// Jen klasické cvičení mění úroveň obtížnosti textu.
    var affectsTextDifficulty: Bool { self == .practice }

    /// Esc cvičení uloží (místo zahození).
    var savesOnEscape: Bool { self == .endless }

    /// Uživatel si u režimu volí délku textu.
    var usesLengthSetting: Bool { self == .practice || self == .accuracyChallenge }

    /// Režim končí po uplynutí času.
    var isTimed: Bool { self == .timeAttack || self == .exam || self == .speedTest }

    /// Hodnotí se v úhozech jako ve škole.
    var showsExamEvaluation: Bool { self == .exam }
}

/// Délka Zkoušky (opisu).
enum ExamDuration: Int, CaseIterable, Identifiable, Codable, Sendable {
    case minutes1 = 1
    case minutes2 = 2
    case minutes5 = 5
    case minutes10 = 10

    var id: Int { rawValue }
    var title: String { "\(rawValue) min" }
    var seconds: TimeInterval { TimeInterval(rawValue * 60) }
}

/// Délka Time Attack.
enum TimeAttackDuration: Int, CaseIterable, Identifiable, Codable, Sendable {
    case seconds15 = 15
    case seconds30 = 30
    case seconds60 = 60
    case seconds120 = 120

    var id: Int { rawValue }
    var title: String { "\(rawValue) s" }
    var seconds: TimeInterval { TimeInterval(rawValue) }
}

/// Pevná pravidla režimů na jednom místě.
enum ModeRules {
    static let sprintLength = 70
    static let accuracyMaxErrors = 3
    static let survivalLives = 3
    /// Délka jedné vlny v Survival.
    static let survivalChunkLength = 60
    /// Délka doplňovaného bloku v Time Attack a Endless.
    static let continuousChunkLength = 120
    /// Kolik znaků musí být vždy „před“ kurzorem.
    /// Musí být delší než stránka textu (150 znaků), aby se stránka nikdy nedoplňovala za běhu.
    static let continuousLookahead = 220

    /// Minimální tempo vlny v Survival.
    static func survivalRequiredWPM(wave: Int, baseTarget: Double?) -> Double {
        let base = max(6, (baseTarget ?? 15) * 0.5)
        return base * (1 + 0.12 * Double(max(wave - 1, 0)))
    }
}
