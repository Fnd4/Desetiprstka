import CoreGraphics

/// Podporovaná rozložení klávesnice.
enum KeyboardLayoutKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case czechQWERTZ
    case czechQWERTY
    case usQWERTY
    case ukQWERTY

    var id: String { rawValue }

    var title: String {
        switch self {
        case .czechQWERTZ: String(localized: "Česká – QWERTZ")
        case .czechQWERTY: String(localized: "Česká – QWERTY")
        case .usQWERTY: String(localized: "Anglická (USA) – QWERTY")
        case .ukQWERTY: String(localized: "Anglická (Británie) – QWERTY")
        }
    }

    var isCzech: Bool { self == .czechQWERTZ || self == .czechQWERTY }

    var layout: KeyboardLayout {
        switch self {
        case .czechQWERTZ: KeyboardLayout.czechQWERTZ
        case .czechQWERTY: KeyboardLayout.czechQWERTY
        case .usQWERTY: KeyboardLayout.usQWERTY
        case .ukQWERTY: KeyboardLayout.ukQWERTY
        }
    }

    /// Rozložení zvolené v Nastavení (platné pro aktuální jazyk cvičení).
    static var current: KeyboardLayoutKind {
        let language = PracticeLanguage.current
        if let raw = UserDefaults.standard.string(forKey: SettingsKey.keyboardLayout),
           let kind = KeyboardLayoutKind(rawValue: raw), language.layouts.contains(kind) {
            return kind
        }
        return language.defaultLayout
    }
}

/// Jedna fyzická klávesa.
struct KeyboardKey: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case character
        case space
        case leftShift
        case rightShift
        case decoration
    }

    let id: String
    let kind: Kind
    /// Znak, který klávesa napíše bez modifikátorů.
    let character: Character?
    /// Malý popisek v rohu (znak na Shiftu).
    let secondary: String?
    let label: String
    let finger: Finger
    /// Šířka v jednotkách (1 = běžná klávesa).
    let width: CGFloat

    /// Klíč z osnovy, který klávesa reprezentuje (pokud se dá učit).
    var learnableKey: String? {
        switch kind {
        case .leftShift, .rightShift:
            return Curriculum.shiftKey
        case .character:
            guard let character else { return nil }
            let key = String(character)
            if Curriculum.allKeySet.contains(key) { return key }
            // Klávesa, jejíž znak na Shiftu je v osnově (číslice, „?“…).
            if let secondary, Curriculum.allKeySet.contains(secondary) { return secondary }
            return nil
        case .space, .decoration:
            return nil
        }
    }

    var isHomingKey: Bool { character == "f" || character == "j" }
}

/// Klávesy, které je potřeba zmáčknout pro jeden znak (např. Shift + A).
struct KeyStroke: Equatable, Sendable {
    let keys: [KeyboardKey]

    var keyIDs: Set<String> { Set(keys.map(\.id)) }
    var fingers: Set<Finger> { Set(keys.map(\.finger)) }
    var primary: KeyboardKey { keys[0] }
    var usesShift: Bool { keys.contains { $0.kind == .leftShift || $0.kind == .rightShift } }
}

/// Model klávesnice Macu – české a britské rozložení jsou ISO, americké ANSI.
struct KeyboardLayout: Sendable {
    static let rowUnits: CGFloat = 15
    static let czechQWERTZ = KeyboardLayout(kind: .czechQWERTZ)
    static let czechQWERTY = KeyboardLayout(kind: .czechQWERTY)
    static let usQWERTY = KeyboardLayout(kind: .usQWERTY)
    static let ukQWERTY = KeyboardLayout(kind: .ukQWERTY)

    let kind: KeyboardLayoutKind
    let rows: [[KeyboardKey]]
    let leftShift: KeyboardKey
    let rightShift: KeyboardKey
    let space: KeyboardKey
    private let characterMap: [Character: KeyboardKey]
    /// Znaky na Shiftu (číslice, ?, !, …) → klávesa.
    private let shiftedMap: [Character: KeyboardKey]

    init(kind: KeyboardLayoutKind) {
        self.kind = kind
        let rows = Self.buildRows(for: kind)
        self.rows = rows

        var map: [Character: KeyboardKey] = [:]
        var shifted: [Character: KeyboardKey] = [:]
        var foundLeftShift: KeyboardKey?
        var foundRightShift: KeyboardKey?
        var foundSpace: KeyboardKey?
        for key in rows.joined() {
            switch key.kind {
            case .character:
                if let character = key.character { map[character] = key }
                if let secondary = key.secondary, secondary.count == 1, let character = secondary.first {
                    shifted[character] = key
                }
            case .space: foundSpace = key
            case .leftShift: foundLeftShift = key
            case .rightShift: foundRightShift = key
            case .decoration: break
            }
        }
        guard let left = foundLeftShift, let right = foundRightShift, let spaceKey = foundSpace else {
            preconditionFailure("Rozložení musí obsahovat oba Shifty a mezerník.")
        }
        self.characterMap = map
        self.shiftedMap = shifted
        self.leftShift = left
        self.rightShift = right
        self.space = spaceKey
    }

    /// Které klávesy a prsty jsou potřeba pro napsání znaku.
    func stroke(for character: Character) -> KeyStroke? {
        if character == " " { return KeyStroke(keys: [space]) }
        if let key = characterMap[character] { return KeyStroke(keys: [key]) }

        // Číslice a symboly na Shiftu (česká klávesnice: číslice jsou nahoře se Shiftem).
        if let key = shiftedMap[character] {
            let shift = key.finger.hand == .left ? rightShift : leftShift
            return KeyStroke(keys: [key, shift])
        }

        // Velké písmeno → písmeno + Shift opačné ruky.
        if let lower = character.lowercased().first, lower != character, let key = characterMap[lower] {
            let shift = key.finger.hand == .left ? rightShift : leftShift
            return KeyStroke(keys: [key, shift])
        }
        return nil
    }

    /// Stisk pro položku z osnovy (písmeno, interpunkce nebo Shift).
    func stroke(forLearnable key: String) -> KeyStroke? {
        if key == Curriculum.shiftKey { return KeyStroke(keys: [leftShift, rightShift]) }
        guard key.count == 1, let character = key.first else { return nil }
        return stroke(for: character)
    }

    // MARK: - Definice řad

    private static func buildRows(for kind: KeyboardLayoutKind) -> [[KeyboardKey]] {
        switch kind {
        case .czechQWERTZ, .czechQWERTY: czechRows(for: kind)
        case .usQWERTY, .ukQWERTY: englishRows(iso: kind == .ukQWERTY)
        }
    }

    /// Anglické rozložení Macu. US = ANSI, UK = ISO (klávesa § vlevo nahoře, ` u levého Shiftu).
    private static func englishRows(iso: Bool) -> [[KeyboardKey]] {
        let numberRow: [KeyboardKey] = [
            iso ? decoration("section", "§", width: 1) : key("`", .leftPinky, secondary: "~"),
            key("1", .leftPinky, secondary: "!"),
            key("2", .leftRing, secondary: "@"),
            key("3", .leftMiddle, secondary: iso ? "£" : "#"),
            key("4", .leftIndex, secondary: "$"),
            key("5", .leftIndex, secondary: "%"),
            key("6", .rightIndex, secondary: "^"),
            key("7", .rightIndex, secondary: "&"),
            key("8", .rightMiddle, secondary: "*"),
            key("9", .rightRing, secondary: "("),
            key("0", .rightPinky, secondary: ")"),
            key("-", .rightPinky, secondary: "_"),
            key("=", .rightPinky, secondary: "+"),
            decoration("delete", "⌫", width: 2),
        ]

        var topRow: [KeyboardKey] = [
            decoration("tab", "⇥", width: 1.5),
            key("q", .leftPinky),
            key("w", .leftRing),
            key("e", .leftMiddle),
            key("r", .leftIndex),
            key("t", .leftIndex),
            key("y", .rightIndex),
            key("u", .rightIndex),
            key("i", .rightMiddle),
            key("o", .rightRing),
            key("p", .rightPinky),
            key("[", .rightPinky, secondary: "{"),
            key("]", .rightPinky, secondary: "}"),
        ]
        topRow.append(iso ? decoration("return-top", "", width: 1.5) : key("\\", .rightPinky, secondary: "|", width: 1.5))

        var homeRow: [KeyboardKey] = [
            decoration("caps", "⇪", width: 1.75),
            key("a", .leftPinky),
            key("s", .leftRing),
            key("d", .leftMiddle),
            key("f", .leftIndex),
            key("g", .leftIndex),
            key("h", .rightIndex),
            key("j", .rightIndex),
            key("k", .rightMiddle),
            key("l", .rightRing),
            key(";", .rightPinky, secondary: ":"),
            key("'", .rightPinky, secondary: "\""),
        ]
        if iso { homeRow.append(key("\\", .rightPinky, secondary: "|")) }
        homeRow.append(decoration("return", "↩", width: iso ? 1.25 : 2.25))

        var bottomRow: [KeyboardKey] = [
            KeyboardKey(id: "shift-left", kind: .leftShift, character: nil, secondary: nil,
                        label: "⇧", finger: .leftPinky, width: iso ? 1.25 : 2.25),
        ]
        if iso { bottomRow.append(key("`", .leftPinky, secondary: "~")) }
        bottomRow += [
            key("z", .leftPinky),
            key("x", .leftRing),
            key("c", .leftMiddle),
            key("v", .leftIndex),
            key("b", .leftIndex),
            key("n", .rightIndex),
            key("m", .rightIndex),
            key(",", .rightMiddle, secondary: "<"),
            key(".", .rightRing, secondary: ">"),
            key("/", .rightPinky, secondary: "?"),
            KeyboardKey(id: "shift-right", kind: .rightShift, character: nil, secondary: nil,
                        label: "⇧", finger: .rightPinky, width: 2.75),
        ]

        return [numberRow, topRow, homeRow, bottomRow, spaceRow()]
    }

    private static func spaceRow() -> [KeyboardKey] {
        [
            decoration("fn", "fn", width: 1),
            decoration("control", "⌃", width: 1),
            decoration("option-left", "⌥", width: 1),
            decoration("command-left", "⌘", width: 1.25),
            KeyboardKey(id: "space", kind: .space, character: " ", secondary: nil,
                        label: "", finger: .thumbs, width: 5.5),
            decoration("command-right", "⌘", width: 1.25),
            decoration("option-right", "⌥", width: 1),
            decoration("arrows", "", width: 3),
        ]
    }

    private static func czechRows(for kind: KeyboardLayoutKind) -> [[KeyboardKey]] {
        let topRowZ: Character = kind == .czechQWERTZ ? "z" : "y"
        let bottomRowY: Character = kind == .czechQWERTZ ? "y" : "z"

        let numberRow: [KeyboardKey] = [
            decoration("tilde", "°", width: 1),
            key("+", .leftPinky, secondary: "1"),
            key("ě", .leftRing, secondary: "2"),
            key("š", .leftMiddle, secondary: "3"),
            key("č", .leftIndex, secondary: "4"),
            key("ř", .leftIndex, secondary: "5"),
            key("ž", .rightIndex, secondary: "6"),
            key("ý", .rightIndex, secondary: "7"),
            key("á", .rightMiddle, secondary: "8"),
            key("í", .rightRing, secondary: "9"),
            key("é", .rightPinky, secondary: "0"),
            key("=", .rightPinky, secondary: "%"),
            key("´", .rightPinky, secondary: "ˇ"),
            decoration("delete", "⌫", width: 2),
        ]

        let topRow: [KeyboardKey] = [
            decoration("tab", "⇥", width: 1.5),
            key("q", .leftPinky),
            key("w", .leftRing),
            key("e", .leftMiddle),
            key("r", .leftIndex),
            key("t", .leftIndex),
            key(topRowZ, .rightIndex),
            key("u", .rightIndex),
            key("i", .rightMiddle),
            key("o", .rightRing),
            key("p", .rightPinky),
            key("ú", .rightPinky, secondary: "/"),
            key(")", .rightPinky, secondary: "("),
            decoration("return-top", "", width: 1.5),
        ]

        let homeRow: [KeyboardKey] = [
            decoration("caps", "⇪", width: 1.75),
            key("a", .leftPinky),
            key("s", .leftRing),
            key("d", .leftMiddle),
            key("f", .leftIndex),
            key("g", .leftIndex),
            key("h", .rightIndex),
            key("j", .rightIndex),
            key("k", .rightMiddle),
            key("l", .rightRing),
            key("ů", .rightPinky, secondary: "\""),
            key("§", .rightPinky, secondary: "!"),
            decoration("return", "↩", width: 2.25),
        ]

        let bottomRow: [KeyboardKey] = [
            KeyboardKey(id: "shift-left", kind: .leftShift, character: nil, secondary: nil,
                        label: "⇧", finger: .leftPinky, width: 1.25),
            decoration("iso", "<", width: 1),
            key(bottomRowY, .leftPinky),
            key("x", .leftRing),
            key("c", .leftMiddle),
            key("v", .leftIndex),
            key("b", .leftIndex),
            key("n", .rightIndex),
            key("m", .rightIndex),
            key(",", .rightMiddle, secondary: "?"),
            key(".", .rightRing, secondary: ":"),
            key("-", .rightPinky, secondary: "_"),
            KeyboardKey(id: "shift-right", kind: .rightShift, character: nil, secondary: nil,
                        label: "⇧", finger: .rightPinky, width: 2.75),
        ]

        return [numberRow, topRow, homeRow, bottomRow, spaceRow()]
    }

    private static func key(_ character: Character, _ finger: Finger, secondary: String? = nil, width: CGFloat = 1) -> KeyboardKey {
        KeyboardKey(
            id: "key-\(character)",
            kind: .character,
            character: character,
            secondary: secondary,
            label: String(character).uppercased(),
            finger: finger,
            width: width
        )
    }

    private static func decoration(_ id: String, _ label: String, width: CGFloat) -> KeyboardKey {
        KeyboardKey(
            id: "deco-\(id)",
            kind: .decoration,
            character: nil,
            secondary: nil,
            label: label,
            finger: .thumbs,
            width: width
        )
    }
}
