import Foundation

/// Připraví vložený text k opisu: sjednotí typografické znaky na ty,
/// které jdou napsat na klávesnici, a odstraní řádkování a nepsatelné znaky.
enum CustomTextNormalizer {
    static let maxLength = 6000
    static let minLength = 10

    private static let replacements: [(String, String)] = [
        ("\r\n", " "), ("\n", " "), ("\r", " "), ("\t", " "),
        ("\u{00A0}", " "), ("\u{202F}", " "), ("\u{2009}", " "),
        ("„", "\""), ("“", "\""), ("”", "\""), ("«", "\""), ("»", "\""),
        ("‚", "'"), ("‘", "'"), ("’", "'"),
        ("–", "-"), ("—", "-"), ("−", "-"),
        ("…", "..."), ("•", "-"),
    ]

    static func normalize(_ input: String) -> String {
        var text = input.precomposedStringWithCanonicalMapping
        for (from, to) in replacements {
            text = text.replacingOccurrences(of: from, with: to)
        }
        // Jen znaky, které jde napsat (písmena, čísla, interpunkce, symboly, mezera).
        text = String(text.filter { character in
            character == " " || character.isLetter || character.isNumber
                || character.isPunctuation || character.isSymbol
        }.filter { !$0.unicodeScalars.contains { $0.properties.isEmojiPresentation } })
        // Více mezer za sebou → jedna.
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }
        text = text.trimmingCharacters(in: .whitespaces)
        if text.count > maxLength {
            let cut = text.prefix(maxLength)
            // Neutínat uprostřed slova.
            if let space = cut.lastIndex(of: " ") {
                text = String(cut[..<space])
            } else {
                text = String(cut)
            }
        }
        return text
    }

    /// Znaky, které na české klávesnici Macu nejdou napsat přímo (velká písmena s diakritikou).
    static func hardCharacters(in text: String) -> Set<Character> {
        Set(text.filter { character in
            character.isUppercase && !character.isASCII && character.isLetter
        })
    }
}
