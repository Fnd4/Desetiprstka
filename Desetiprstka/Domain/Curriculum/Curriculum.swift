import Foundation

/// Jedna lekce osnovy – skupina kláves, které se učí společně.
struct Lesson: Identifiable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
    let keys: [String]
}

/// Osnova pro jeden jazyk a rozložení.
struct Course: Sendable {
    let lessons: [Lesson]
    let orderedKeys: [String]
    let allKeySet: Set<String>
    let allLetters: Set<String>

    init(lessons: [Lesson], layout: KeyboardLayout) {
        // Jen klávesy, které na daném rozložení jdou napsat.
        let typeable = lessons.compactMap { lesson -> Lesson? in
            let keys = lesson.keys.filter { layout.stroke(forLearnable: $0) != nil }
            guard !keys.isEmpty else { return nil }
            return Lesson(id: lesson.id, title: lesson.title, subtitle: lesson.subtitle, keys: keys)
        }
        self.lessons = typeable
        self.orderedKeys = typeable.flatMap(\.keys)
        self.allKeySet = Set(orderedKeys)
        self.allLetters = Set(orderedKeys.filter { $0.count == 1 && ($0.first?.isLetter ?? false) })
    }

    private static let courses: [String: Course] = {
        var result: [String: Course] = [:]
        for language in PracticeLanguage.allCases {
            for layout in language.layouts {
                result["\(language.rawValue)-\(layout.rawValue)"] =
                    Course(lessons: Curriculum.lessons(for: language, layout: layout), layout: layout.layout)
            }
        }
        return result
    }()

    static func course(for language: PracticeLanguage, layout: KeyboardLayoutKind) -> Course {
        courses["\(language.rawValue)-\(layout.rawValue)"]
            ?? Course(lessons: Curriculum.lessons(for: language, layout: layout), layout: layout.layout)
    }

    /// Osnova podle Nastavení (jazyk cvičení + klávesnice).
    static var current: Course { course(for: .current, layout: .current) }
}

/// Pořadí, ve kterém se klávesy učí. Jediný zdroj pravdy pro celou aplikaci.
/// Obsah se řídí jazykem cvičení a rozložením klávesnice v Nastavení.
enum Curriculum {
    /// Speciální klíč reprezentující Shift (velká písmena).
    static let shiftKey = "⇧"

    /// Minimální počet písmen, která musí uživatel znát.
    static let minimumLetters = 2

    static var lessons: [Lesson] { Course.current.lessons }
    /// Všechny klíče v pořadí výuky.
    static var orderedKeys: [String] { Course.current.orderedKeys }
    /// Všechna písmena osnovy – pro Test rychlosti (bez Shiftu a znaků).
    static var allLetters: Set<String> { Course.current.allLetters }
    static var allKeySet: Set<String> { Course.current.allKeySet }

    static func lessons(for language: PracticeLanguage, layout: KeyboardLayoutKind) -> [Lesson] {
        let digitsNeedShift = layout.isCzech
        let digitsSubtitle = digitsNeedShift
            ? String(localized: "Na české klávesnici se píšou se Shiftem v horní řadě.")
            : String(localized: "Číselná řada nad písmeny – bez Shiftu.")
        switch language {
        case .czech:
            return [
                Lesson(id: 1, title: String(localized: "Základní řada"),
                       subtitle: String(localized: "Výchozí poloha prstů. Tady všechno začíná."),
                       keys: ["f", "j", "d", "k", "s", "l", "a", "g", "h"]),
                Lesson(id: 2, title: String(localized: "Nejčastější písmena"),
                       subtitle: String(localized: "S nimi už napíšeš spoustu slov."),
                       keys: ["e", "i", "o", "n"]),
                Lesson(id: 3, title: String(localized: "Horní řada"),
                       subtitle: String(localized: "Prsty sahají nahoru a hned se vrací."),
                       keys: ["r", "t", "u", "p"]),
                Lesson(id: 4, title: String(localized: "Dolní řada"),
                       subtitle: String(localized: "Prsty sahají dolů pod základní řadu."),
                       keys: ["v", "c", "m", "b"]),
                Lesson(id: 5, title: String(localized: "Zbývající písmena"),
                       subtitle: String(localized: "Méně častá písmena abecedy."),
                       keys: ["z", "y", "x", "w", "q"]),
                Lesson(id: 6, title: String(localized: "Interpunkce"),
                       subtitle: String(localized: "Tečka, čárka a pomlčka."),
                       keys: [".", ",", "-"]),
                Lesson(id: 7, title: String(localized: "Čárky a háčky I"),
                       subtitle: String(localized: "Číselná řada – nejčastější diakritika."),
                       keys: ["ě", "á", "í", "é", "ý"]),
                Lesson(id: 8, title: String(localized: "Čárky a háčky II"),
                       subtitle: String(localized: "Zbytek české diakritiky."),
                       keys: ["š", "č", "ř", "ž", "ů", "ú"]),
                Lesson(id: 9, title: String(localized: "Velká písmena"),
                       subtitle: String(localized: "Shift mačkej malíčkem opačné ruky."),
                       keys: [shiftKey]),
                Lesson(id: 10, title: String(localized: "Číslice"),
                       subtitle: digitsSubtitle,
                       keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
                Lesson(id: 11, title: String(localized: "Další znaky"),
                       subtitle: String(localized: "Otazník, vykřičník, dvojtečka, závorky, uvozovky a lomítko."),
                       keys: ["?", "!", ":", "(", ")", "\"", "/"]),
            ]
        case .english:
            return [
                Lesson(id: 1, title: String(localized: "Základní řada"),
                       subtitle: String(localized: "Výchozí poloha prstů. Tady všechno začíná."),
                       keys: ["f", "j", "d", "k", "s", "l", "a", "g", "h"]),
                Lesson(id: 2, title: String(localized: "Nejčastější písmena"),
                       subtitle: String(localized: "S nimi už napíšeš spoustu slov."),
                       keys: ["e", "t", "i", "o", "n"]),
                Lesson(id: 3, title: String(localized: "Horní řada"),
                       subtitle: String(localized: "Prsty sahají nahoru a hned se vrací."),
                       keys: ["r", "u", "w", "y", "p"]),
                Lesson(id: 4, title: String(localized: "Dolní řada"),
                       subtitle: String(localized: "Prsty sahají dolů pod základní řadu."),
                       keys: ["c", "m", "b", "v"]),
                Lesson(id: 5, title: String(localized: "Zbývající písmena"),
                       subtitle: String(localized: "Méně častá písmena abecedy."),
                       keys: ["x", "z", "q"]),
                Lesson(id: 6, title: String(localized: "Interpunkce"),
                       subtitle: String(localized: "Tečka, čárka, apostrof a pomlčka."),
                       keys: [".", ",", "'", "-"]),
                Lesson(id: 7, title: String(localized: "Velká písmena"),
                       subtitle: String(localized: "Shift mačkej malíčkem opačné ruky."),
                       keys: [shiftKey]),
                Lesson(id: 8, title: String(localized: "Číslice"),
                       subtitle: digitsSubtitle,
                       keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
                Lesson(id: 9, title: String(localized: "Další znaky"),
                       subtitle: String(localized: "Otazník, vykřičník, dvojtečka, středník, závorky, uvozovky a lomítko."),
                       keys: ["?", "!", ":", ";", "(", ")", "\"", "/"]),
            ]
        }
    }

    /// Úplný začátečník začíná těmito klávesami.
    static let beginnerKeys: [String] = ["f", "j", "d", "k"]
    static var homeRowKeys: [String] { lessons[0].keys }

    /// Další klávesa, kterou se vyplatí naučit.
    static func nextKey(after known: Set<String>) -> String? {
        orderedKeys.first { !known.contains($0) }
    }

    /// Seřadí klíče podle osnovy.
    static func sorted(_ keys: some Sequence<String>) -> [String] {
        let order = Dictionary(uniqueKeysWithValues: orderedKeys.enumerated().map { ($0.element, $0.offset) })
        return Array(Set(keys)).sorted { (order[$0] ?? .max, $0) < (order[$1] ?? .max, $1) }
    }

    static func letterCount(in keys: Set<String>) -> Int {
        keys.filter { $0.count == 1 && ($0.first?.isLetter ?? false) }.count
    }

    static func lesson(containing key: String) -> Lesson? {
        lessons.first { $0.keys.contains(key) }
    }

    /// Text pro zobrazení klíče v UI.
    static func displayName(for key: String) -> String {
        switch key {
        case shiftKey: "Shift"
        case " ": "Mezerník"
        default: key.uppercased()
        }
    }

    /// Krátká rada k nové klávese.
    static func tip(for key: String, finger: Finger) -> String {
        let usesShift = key != shiftKey && (KeyboardLayoutKind.current.layout.stroke(forLearnable: key)?.usesShift ?? false)
        switch key {
        case "f", "j":
            return "Na klávesách F a J jsou hmatové výstupky. Podle nich najdeš základní polohu bez dívání."
        case shiftKey:
            return "Shift drž malíčkem ruky, která právě nepíše písmeno. Pro velké A tedy pravý Shift."
        case "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" where usesShift:
            return String(localized: "Číslice jsou v horní řadě nad písmeny. Drž Shift malíčkem druhé ruky a \(finger.kindName.lowercased()) natáhni nahoru – pak se hned vrať na základní řadu.")
        case "1", "2", "3", "4", "5", "6", "7", "8", "9", "0":
            return String(localized: "Číslice jsou v horní řadě nad písmeny. \(finger.kindName) natáhni nahoru, zmáčkni a hned se vrať na základní řadu.")
        case _ where usesShift:
            return String(localized: "Tenhle znak je na Shiftu. Shift drž malíčkem druhé ruky, znak napiš prstem \(finger.kindName.lowercased()).")
        default:
            if lessons[0].keys.contains(key) {
                return "Klávesa leží na základní řadě. Prst \(finger.kindName.lowercased()) na ní rovnou odpočívá nebo se k ní jen posune."
            }
            return "Prst začíná na klávese \(finger.homeKeyLabel). Natáhni ho, zmáčkni a hned se vrať zpět."
        }
    }
}
