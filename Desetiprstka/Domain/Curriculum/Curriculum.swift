import Foundation

/// Jedna lekce osnovy – skupina kláves, které se učí společně.
struct Lesson: Identifiable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
    let keys: [String]
}

/// Pořadí, ve kterém se klávesy učí. Jediný zdroj pravdy pro celou aplikaci.
enum Curriculum {
    /// Speciální klíč reprezentující Shift (velká písmena).
    static let shiftKey = "⇧"

    /// Minimální počet písmen, která musí uživatel znát.
    static let minimumLetters = 2

    static let lessons: [Lesson] = [
        Lesson(id: 1, title: "Základní řada",
               subtitle: "Výchozí poloha prstů. Tady všechno začíná.",
               keys: ["f", "j", "d", "k", "s", "l", "a", "g", "h"]),
        Lesson(id: 2, title: "Nejčastější písmena",
               subtitle: "S nimi už napíšeš spoustu slov.",
               keys: ["e", "i", "o", "n"]),
        Lesson(id: 3, title: "Horní řada",
               subtitle: "Prsty sahají nahoru a hned se vrací.",
               keys: ["r", "t", "u", "p"]),
        Lesson(id: 4, title: "Dolní řada",
               subtitle: "Prsty sahají dolů pod základní řadu.",
               keys: ["v", "c", "m", "b"]),
        Lesson(id: 5, title: "Zbývající písmena",
               subtitle: "Méně častá písmena abecedy.",
               keys: ["z", "y", "x", "w", "q"]),
        Lesson(id: 6, title: "Interpunkce",
               subtitle: "Tečka, čárka a pomlčka.",
               keys: [".", ",", "-"]),
        Lesson(id: 7, title: "Čárky a háčky I",
               subtitle: "Číselná řada – nejčastější diakritika.",
               keys: ["ě", "á", "í", "é", "ý"]),
        Lesson(id: 8, title: "Čárky a háčky II",
               subtitle: "Zbytek české diakritiky.",
               keys: ["š", "č", "ř", "ž", "ů", "ú"]),
        Lesson(id: 9, title: "Velká písmena",
               subtitle: "Shift mačkej malíčkem opačné ruky.",
               keys: [shiftKey]),
        Lesson(id: 10, title: "Číslice",
               subtitle: "Na české klávesnici se píšou se Shiftem v horní řadě.",
               keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
        Lesson(id: 11, title: "Další znaky",
               subtitle: "Otazník, vykřičník, dvojtečka, závorky, uvozovky a lomítko.",
               keys: ["?", "!", ":", "(", ")", "\"", "/"]),
    ]

    /// Znaky, které se na české klávesnici píšou se Shiftem.
    static let shiftedSymbols: Set<String> = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "?", "!", ":", "(", "\"", "/"]

    /// Všechny klíče v pořadí výuky.
    static let orderedKeys: [String] = lessons.flatMap(\.keys)
    /// Všechna písmena osnovy – pro Test rychlosti (bez Shiftu a znaků).
    static let allLetters: Set<String> = Set(orderedKeys.filter { $0.count == 1 && ($0.first?.isLetter ?? false) })
    static let allKeySet: Set<String> = Set(orderedKeys)

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
        switch key {
        case "f", "j":
            return "Na klávesách F a J jsou hmatové výstupky. Podle nich najdeš základní polohu bez dívání."
        case shiftKey:
            return "Shift drž malíčkem ruky, která právě nepíše písmeno. Pro velké A tedy pravý Shift."
        case "1", "2", "3", "4", "5", "6", "7", "8", "9", "0":
            return "Číslice jsou v horní řadě nad písmeny. Drž Shift malíčkem druhé ruky a \(finger.kindName.lowercased()) natáhni nahoru – pak se hned vrať na základní řadu."
        case "?", "!", ":", "(", "\"", "/":
            return "Tenhle znak je na Shiftu. Shift drž malíčkem druhé ruky, znak napiš prstem \(finger.kindName.lowercased())."
        default:
            if lessons[0].keys.contains(key) {
                return "Klávesa leží na základní řadě. Prst \(finger.kindName.lowercased()) na ní rovnou odpočívá nebo se k ní jen posune."
            }
            return "Prst začíná na klávese \(finger.homeKeyLabel). Natáhni ho, zmáčkni a hned se vrať zpět."
        }
    }
}
