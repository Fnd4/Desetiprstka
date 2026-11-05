import Foundation

// Levely za XP mají smysl: dávají hodnost a odemykají vzhled.
// Výuka ani režimy se nezamykají – odemyká se jen kosmetika.

/// Hodnost podle profilového levelu.
enum PlayerRank: Int, CaseIterable, Identifiable, Sendable {
    case novice = 1
    case apprentice = 3
    case scribe = 6
    case skilled = 10
    case swift = 15
    case virtuoso = 25
    case master = 40
    case legend = 60
    case grandmaster = 80
    case tenFingers = 100

    var id: Int { rawValue }
    var requiredLevel: Int { rawValue }

    var title: String {
        switch self {
        case .novice: "Nováček"
        case .apprentice: "Učeň"
        case .scribe: "Písař"
        case .skilled: "Zručný písař"
        case .swift: "Rychlopísař"
        case .virtuoso: "Virtuos"
        case .master: "Mistr klávesnice"
        case .legend: "Legenda"
        case .grandmaster: "Velmistr"
        case .tenFingers: "Desetiprstý"
        }
    }

    var symbol: String {
        switch self {
        case .novice: "leaf.fill"
        case .apprentice: "book.fill"
        case .scribe: "pencil"
        case .skilled: "hand.raised.fingers.spread.fill"
        case .swift: "hare.fill"
        case .virtuoso: "music.note"
        case .master: "keyboard.fill"
        case .legend: "star.circle.fill"
        case .grandmaster: "crown.fill"
        case .tenFingers: "trophy.fill"
        }
    }

    static func rank(for level: Int) -> PlayerRank {
        allCases.last { $0.requiredLevel <= level } ?? .novice
    }

    var next: PlayerRank? {
        PlayerRank.allCases.first { $0.rawValue > rawValue }
    }
}

/// Styl kurzoru v textu. Žádný nemění šířku znaků – text se nikdy nepřelámá jinak.
enum CursorStyle: String, CaseIterable, Identifiable, Sendable {
    case underline
    case highlight
    case block
    case dotted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .underline: "Podtržení"
        case .highlight: "Zvýraznění"
        case .block: "Blok"
        case .dotted: "Tečkovaný"
        }
    }

    var symbol: String {
        switch self {
        case .underline: "underline"
        case .highlight: "highlighter"
        case .block: "rectangle.fill"
        case .dotted: "ellipsis"
        }
    }
}

/// Efekt při milníku combo.
enum ComboEffect: String, CaseIterable, Identifiable, Sendable {
    case classic
    case sparks
    case flame

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Klasický"
        case .sparks: "Jiskry"
        case .flame: "Plamen"
        }
    }

    var symbol: String {
        switch self {
        case .classic: "bolt.fill"
        case .sparks: "sparkles"
        case .flame: "flame.fill"
        }
    }
}

/// Cokoliv, co se odemyká levelem.
protocol LevelUnlockable {
    var requiredLevel: Int { get }
    var unlockTitle: String { get }
}

extension LevelUnlockable {
    func isUnlocked(at level: Int) -> Bool { level >= requiredLevel }
}

extension AppTheme: LevelUnlockable {
    var requiredLevel: Int {
        switch self {
        case .system, .paper: 1
        case .graphite: 2
        case .ocean: 4
        case .forest: 6
        case .warm: 9
        case .midnight: 12
        }
    }
    var unlockTitle: String { "Téma \(title)" }
}

extension AccentChoice: LevelUnlockable {
    var requiredLevel: Int {
        switch self {
        case .automatic, .blue: 1
        case .green: 2
        case .purple: 3
        case .orange: 5
        case .pink: 7
        case .red: 10
        }
    }
    var unlockTitle: String { "Barva \(title)" }
}

extension SoundPack: LevelUnlockable {
    var requiredLevel: Int {
        switch self {
        case .silent, .soft: 1
        case .mechanical: 3
        case .typewriter: 6
        case .clicky: 8
        }
    }
    var unlockTitle: String { "Zvuky \(title)" }
}

extension CursorStyle: LevelUnlockable {
    var requiredLevel: Int {
        switch self {
        case .underline: 1
        case .highlight: 4
        case .block: 7
        case .dotted: 15
        }
    }
    var unlockTitle: String { "Kurzor \(title)" }
}

extension ComboEffect: LevelUnlockable {
    var requiredLevel: Int {
        switch self {
        case .classic: 1
        case .sparks: 11
        case .flame: 20
        }
    }
    var unlockTitle: String { "Combo efekt \(title)" }
}

/// Přehled všeho odemykatelného.
enum UnlockCatalog {
    struct Item: Identifiable, Sendable {
        let title: String
        let level: Int
        let symbol: String
        var id: String { title }
    }

    static var all: [Item] {
        var items: [Item] = []
        items += AppTheme.allCases.map { Item(title: $0.unlockTitle, level: $0.requiredLevel, symbol: "paintpalette") }
        items += AccentChoice.allCases.map { Item(title: $0.unlockTitle, level: $0.requiredLevel, symbol: "circle.fill") }
        items += SoundPack.allCases.map { Item(title: $0.unlockTitle, level: $0.requiredLevel, symbol: $0.symbol) }
        items += CursorStyle.allCases.map { Item(title: $0.unlockTitle, level: $0.requiredLevel, symbol: $0.symbol) }
        items += ComboEffect.allCases.map { Item(title: $0.unlockTitle, level: $0.requiredLevel, symbol: $0.symbol) }
        return items.filter { $0.level > 1 }.sorted { ($0.level, $0.title) < ($1.level, $1.title) }
    }

    /// Co se odemklo při přechodu z levelu `before` na `after`.
    static func unlocked(from before: Int, to after: Int) -> [Item] {
        guard after > before else { return [] }
        return all.filter { $0.level > before && $0.level <= after }
    }

    /// Nejbližší další odměna.
    static func next(after level: Int) -> Item? {
        all.first { $0.level > level }
    }
}
