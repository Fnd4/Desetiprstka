import Foundation

/// Vytváří texty cvičení výhradně ze známých kláves.
///
/// Slabá písmena mají vyšší váhu, takže se v textu objevují častěji.
/// Pokud slovník nemá dost skutečných slov, generátor doplní
/// vyslovitelná „pseudo-slova“ ze známých písmen.
struct ExerciseGenerator {
    var wordBank: WordBank = .current

    func makeExercise(
        knownKeys: Set<String>,
        difficulty: Difficulty,
        weights: [String: Double],
        targetLength: Int
    ) -> Exercise {
        var rng = SystemRandomNumberGenerator()
        return makeExercise(
            knownKeys: knownKeys,
            difficulty: difficulty,
            weights: weights,
            targetLength: targetLength,
            using: &rng
        )
    }

    func makeExercise<G: RandomNumberGenerator>(
        knownKeys: Set<String>,
        difficulty: Difficulty,
        weights: [String: Double],
        targetLength: Int,
        using rng: inout G
    ) -> Exercise {
        let context = GenerationContext(knownKeys: knownKeys, weights: weights)
        let target = max(targetLength, 20)
        let sub = min(max(difficulty.subLevel, 0), 2)

        let text: String
        switch difficulty.stage {
        case .combinations:
            text = makeCombinations(context, subLevel: sub, target: target, rng: &rng)
        case .shortWords:
            let lengths: [ClosedRange<Int>] = [2...3, 2...4, 3...5]
            text = makeWords(context, lengths: lengths[sub], target: target, rng: &rng)
        case .longWords:
            let lengths: [ClosedRange<Int>] = [5...6, 5...8, 6...12]
            text = makeWords(context, lengths: lengths[sub], target: target, rng: &rng)
        case .sentences:
            text = makeSentences(context, subLevel: sub, target: target, rng: &rng)
        }

        return Exercise(text: text, difficulty: difficulty, focusKeys: context.focusKeys)
    }

    // MARK: - Kombinace znaků

    private func makeCombinations<G: RandomNumberGenerator>(
        _ ctx: GenerationContext,
        subLevel: Int,
        target: Int,
        rng: inout G
    ) -> String {
        let lengths: [ClosedRange<Int>] = [2...3, 3...4, 3...5]
        let lengthRange = lengths[subLevel]
        var groups: [String] = []
        var total = 0

        while total < target {
            let roll = Double.random(in: 0..<1, using: &rng)
            let count = Int.random(in: lengthRange, using: &rng)
            let first = ctx.pickLetter(using: &rng)
            var group: String

            if roll < 0.25 {
                // „fff“
                group = String(repeating: String(first), count: count)
            } else if roll < 0.5, ctx.letters.count > 1 {
                // „fjfj“
                let second = ctx.pickLetter(using: &rng, excluding: first)
                var chars: [Character] = []
                for index in 0..<count { chars.append(index.isMultiple(of: 2) ? first : second) }
                group = String(chars)
            } else {
                // „fdjk“
                var chars: [Character] = [first]
                while chars.count < count { chars.append(ctx.pickLetter(using: &rng)) }
                group = String(chars)
            }

            if !ctx.digits.isEmpty, Double.random(in: 0..<1, using: &rng) < 0.15 {
                group = ctx.makeNumber(using: &rng) ?? group
            }
            if let mark = ctx.pickPunctuation(chance: 0.12, using: &rng) {
                group = mark == "-" ? "-" : group + String(mark)
            } else if ctx.canParenthesize, Double.random(in: 0..<1, using: &rng) < 0.05 {
                group = "(" + group + ")"
            }

            groups.append(group)
            total += group.count + 1
        }
        return groups.joined(separator: " ")
    }

    // MARK: - Slova

    private func makeWords<G: RandomNumberGenerator>(
        _ ctx: GenerationContext,
        lengths: ClosedRange<Int>,
        target: Int,
        rng: inout G
    ) -> String {
        var pool = wordBank.words.filter { lengths.contains($0.count) && ctx.canType($0) }
        if pool.count < 4 {
            // Rozšíříme rozsah délek, ať nejsou jen pseudo-slova.
            let wider = wordBank.words.filter { $0.count >= 2 && ctx.canType($0) }
            if wider.count > pool.count { pool = wider }
        }
        let poolWeights = pool.map { ctx.wordWeight($0) }

        let pseudoRatio: Double
        switch pool.count {
        case 0: pseudoRatio = 1
        case 1..<10: pseudoRatio = 0.45
        case 10..<25: pseudoRatio = 0.15
        default: pseudoRatio = 0
        }

        var words: [String] = []
        var total = 0
        var previous: String?

        while total < target {
            let base: String
            if Double.random(in: 0..<1, using: &rng) < pseudoRatio {
                base = makePseudoWord(ctx, length: Int.random(in: lengths, using: &rng), rng: &rng)
            } else {
                base = pickWord(from: pool, weights: poolWeights, avoiding: previous, rng: &rng)
            }
            previous = base

            let word = decorate(base, ctx: ctx, rng: &rng)
            words.append(word)
            total += word.count + 1

            if ctx.punctuation.contains("-"), Double.random(in: 0..<1, using: &rng) < 0.05 {
                words.append("-")
                total += 2
            }
            if Double.random(in: 0..<1, using: &rng) < 0.07, let number = ctx.makeNumber(using: &rng) {
                words.append(number)
                total += number.count + 1
            }
        }
        return words.joined(separator: " ")
    }

    private func pickWord<G: RandomNumberGenerator>(
        from pool: [String],
        weights: [Double],
        avoiding previous: String?,
        rng: inout G
    ) -> String {
        for _ in 0..<4 {
            if let word = WeightedPicker.pick(pool, weights: weights, using: &rng), word != previous {
                return word
            }
        }
        return pool.randomElement(using: &rng) ?? "fj"
    }

    /// Občas přidá velké písmeno nebo interpunkci – jen pokud je uživatel zná.
    private func decorate<G: RandomNumberGenerator>(
        _ word: String,
        ctx: GenerationContext,
        rng: inout G
    ) -> String {
        var result = word
        if ctx.canCapitalize, Double.random(in: 0..<1, using: &rng) < 0.15 {
            result = ctx.capitalized(result)
        }
        let roll = Double.random(in: 0..<1, using: &rng)
        if ctx.canParenthesize, roll < 0.04 {
            result = "(" + result + ")"
        } else if ctx.canQuote, roll < 0.08 {
            result = "\"" + result + "\""
        }
        if ctx.punctuation.contains(","), Double.random(in: 0..<1, using: &rng) < 0.1 {
            result += ","
        } else if ctx.punctuation.contains("."), Double.random(in: 0..<1, using: &rng) < 0.08 {
            result += "."
        } else if let mark = Array("?!:").filter({ ctx.punctuation.contains($0) }).randomElement(using: &rng),
                  Double.random(in: 0..<1, using: &rng) < 0.05 {
            result.append(mark)
        }
        if ctx.symbols.contains("/"), Double.random(in: 0..<1, using: &rng) < 0.02 {
            result += "/"
        }
        return result
    }

    /// Vyslovitelné slovo střídající samohlásky a souhlásky.
    private func makePseudoWord<G: RandomNumberGenerator>(
        _ ctx: GenerationContext,
        length: Int,
        rng: inout G
    ) -> String {
        let vowels = ctx.letters.filter { GenerationContext.vowels.contains($0) }
        let consonants = ctx.letters.filter { !GenerationContext.vowels.contains($0) }
        var chars: [Character] = []

        guard !vowels.isEmpty, !consonants.isEmpty else {
            while chars.count < max(length, 1) { chars.append(ctx.pickLetter(using: &rng)) }
            return String(chars)
        }

        var useVowel = Bool.random(using: &rng)
        while chars.count < max(length, 1) {
            let pool = useVowel ? vowels : consonants
            let letter = WeightedPicker.pick(pool, using: &rng) { ctx.weight(of: $0) } ?? pool[0]
            chars.append(letter)
            useVowel.toggle()
            if Double.random(in: 0..<1, using: &rng) < 0.2 { useVowel.toggle() }
        }
        return String(chars)
    }

    // MARK: - Věty

    private func makeSentences<G: RandomNumberGenerator>(
        _ ctx: GenerationContext,
        subLevel: Int,
        target: Int,
        rng: inout G
    ) -> String {
        var curated = wordBank.sentences
            .compactMap { adapt($0, to: ctx) }
            .filter { ctx.canType($0) }
            .shuffled(using: &rng)

        let pool = wordBank.words.filter { ctx.canType($0) }
        let poolWeights = pool.map { ctx.wordWeight($0) }

        var sentences: [String] = []
        var total = 0

        while total < target {
            let sentence: String
            if !curated.isEmpty, Double.random(in: 0..<1, using: &rng) < 0.6 {
                sentence = curated.removeLast()
            } else {
                let wordCount = Int.random(in: (4 + subLevel)...(6 + subLevel), using: &rng)
                sentence = synthesizeSentence(ctx, wordCount: wordCount, pool: pool, weights: poolWeights, rng: &rng)
            }
            sentences.append(sentence)
            total += sentence.count + 1
        }
        return sentences.joined(separator: " ")
    }

    /// Upraví hotovou větu podle toho, co uživatel umí (velká písmena, interpunkce).
    private func adapt(_ sentence: String, to ctx: GenerationContext) -> String? {
        var result = sentence
        if !ctx.canCapitalize { result = result.lowercased() }
        // Neznámé koncové znaky nahradíme tečkou, dvojtečku čárkou.
        for mark in ["?", "!"] where !ctx.punctuation.contains(Character(mark)) {
            result = result.replacingOccurrences(of: mark, with: ctx.punctuation.contains(".") ? "." : "")
        }
        if !ctx.punctuation.contains(":") {
            result = result.replacingOccurrences(of: ":", with: ctx.punctuation.contains(",") ? "," : "")
        }
        if !ctx.punctuation.contains(",") { result = result.replacingOccurrences(of: ",", with: "") }
        if !ctx.punctuation.contains(".") { result = result.replacingOccurrences(of: ".", with: "") }
        if !ctx.punctuation.contains("-"), result.contains("-") { return nil }
        return result
    }

    private func synthesizeSentence<G: RandomNumberGenerator>(
        _ ctx: GenerationContext,
        wordCount: Int,
        pool: [String],
        weights: [Double],
        rng: inout G
    ) -> String {
        var words: [String] = []
        var previous: String?
        for _ in 0..<max(wordCount, 2) {
            let word: String
            if pool.count >= 6 {
                word = pickWord(from: pool, weights: weights, avoiding: previous, rng: &rng)
            } else {
                word = makePseudoWord(ctx, length: Int.random(in: 2...6, using: &rng), rng: &rng)
            }
            words.append(word)
            previous = word
        }

        if ctx.punctuation.contains(","), words.count > 3, Double.random(in: 0..<1, using: &rng) < 0.5 {
            let index = Int.random(in: 1..<(words.count - 1), using: &rng)
            words[index] += ","
        }

        if Double.random(in: 0..<1, using: &rng) < 0.25, let number = ctx.makeNumber(using: &rng) {
            words.insert(number, at: Int.random(in: 1...words.count, using: &rng))
        }
        if ctx.canQuote, words.count > 3, Double.random(in: 0..<1, using: &rng) < 0.1 {
            let index = Int.random(in: 1..<words.count, using: &rng)
            words[index] = "\"" + words[index] + "\""
        } else if ctx.canParenthesize, words.count > 3, Double.random(in: 0..<1, using: &rng) < 0.1 {
            let index = Int.random(in: 1..<words.count, using: &rng)
            words[index] = "(" + words[index] + ")"
        }

        var sentence = words.joined(separator: " ")
        if ctx.canCapitalize { sentence = ctx.capitalized(sentence) }
        let ending = Double.random(in: 0..<1, using: &rng)
        if ctx.punctuation.contains("?"), ending < 0.12 {
            sentence += "?"
        } else if ctx.punctuation.contains("!"), ending < 0.2 {
            sentence += "!"
        } else if ctx.punctuation.contains(".") {
            sentence += "."
        }
        return sentence
    }
}

// MARK: - Kontext generování

/// Co uživatel umí napsat a jak moc které písmeno potřebuje procvičit.
struct GenerationContext {
    /// Interpunkce, která se přidává za slova a věty.
    static let punctuationSet: Set<Character> = [".", ",", "-", "?", "!", ":"]
    static let digitSet: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    /// Další znaky (závorky, uvozovky, lomítko).
    static let symbolSet: Set<Character> = ["(", ")", "\"", "/"]
    static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y", "á", "é", "ě", "í", "ó", "ú", "ů", "ý"]
    static let fallbackLetters: [Character] = ["f", "j"]

    let letters: [Character]
    let punctuation: Set<Character>
    let digits: [Character]
    let symbols: Set<Character>
    let allowed: Set<Character>
    let canCapitalize: Bool
    private let weights: [Character: Double]

    init(knownKeys: Set<String>, weights: [String: Double]) {
        var letters: [Character] = []
        var punctuation = Set<Character>()
        var digits: [Character] = []
        var symbols = Set<Character>()
        for key in knownKeys where key.count == 1 {
            guard let character = key.first else { continue }
            if character.isLetter {
                letters.append(character)
            } else if Self.punctuationSet.contains(character) {
                punctuation.insert(character)
            } else if Self.digitSet.contains(character) {
                digits.append(character)
            } else if Self.symbolSet.contains(character) {
                symbols.insert(character)
            }
        }
        if letters.isEmpty { letters = Self.fallbackLetters }
        letters.sort()
        digits.sort()

        let allowed = Set(letters).union(punctuation).union(digits).union(symbols)
        self.letters = letters
        self.punctuation = punctuation
        self.digits = digits
        self.symbols = symbols
        self.allowed = allowed
        self.canCapitalize = knownKeys.contains(Curriculum.shiftKey)

        var characterWeights: [Character: Double] = [:]
        for character in allowed {
            characterWeights[character] = max(weights[String(character)] ?? 1, 0.1)
        }
        self.weights = characterWeights
    }

    func weight(of character: Character) -> Double {
        let lower = character.lowercased().first ?? character
        return weights[lower] ?? 1
    }

    /// Váha slova: rozhoduje hlavně nejslabší písmeno, které obsahuje.
    func wordWeight(_ word: String) -> Double {
        let values = word.map { weight(of: $0) }
        guard let maximum = values.max() else { return 1 }
        let mean = values.reduce(0, +) / Double(values.count)
        let score = maximum * 0.7 + mean * 0.3
        return score * score
    }

    func canType(_ character: Character) -> Bool {
        if character == " " || allowed.contains(character) { return true }
        // Velké písmeno jde napsat jen se Shiftem a bez diakritiky.
        if canCapitalize, character.isUppercase, character.isASCII, let lower = character.lowercased().first {
            return allowed.contains(lower)
        }
        return false
    }

    func canType(_ text: String) -> Bool {
        text.allSatisfy { canType($0) }
    }

    /// Velké první písmeno – jen pro písmena bez diakritiky (ta jdou napsat Shiftem).
    func capitalized(_ text: String) -> String {
        guard let first = text.first, first.isASCII, first.isLetter else { return text }
        return first.uppercased() + String(text.dropFirst())
    }

    func pickLetter<G: RandomNumberGenerator>(using rng: inout G, excluding excluded: Character? = nil) -> Character {
        var pool = letters
        if let excluded, letters.count > 1 { pool.removeAll { $0 == excluded } }
        return WeightedPicker.pick(pool, using: &rng) { weight(of: $0) } ?? pool[0]
    }

    func pickPunctuation<G: RandomNumberGenerator>(chance: Double, using rng: inout G) -> Character? {
        guard !punctuation.isEmpty || !symbols.isEmpty, Double.random(in: 0..<1, using: &rng) < chance else { return nil }
        let marks = punctuation.union(symbols.subtracting(["(", ")"])).sorted()
        return WeightedPicker.pick(marks, using: &rng) { weight(of: $0) }
    }

    var canParenthesize: Bool { symbols.contains("(") && symbols.contains(")") }
    var canQuote: Bool { symbols.contains("\"") }

    /// Číslo ze známých číslic (rok, počet, čas…).
    func makeNumber<G: RandomNumberGenerator>(using rng: inout G) -> String? {
        guard !digits.isEmpty else { return nil }
        let length = Int.random(in: 1...4, using: &rng)
        var chars: [Character] = []
        for index in 0..<length {
            var pool = digits
            // Číslo nezačíná nulou (kromě samotné nuly).
            if index == 0, length > 1, pool.count > 1 { pool.removeAll { $0 == "0" } }
            chars.append(WeightedPicker.pick(pool, using: &rng) { weight(of: $0) } ?? pool[0])
        }
        return String(chars)
    }

    /// Až tři klávesy s nejvyšší vahou (pokud výrazně vyčnívají).
    var focusKeys: [String] {
        weights
            .filter { $0.value >= 2.5 }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(3)
            .map { String($0.key) }
    }
}
