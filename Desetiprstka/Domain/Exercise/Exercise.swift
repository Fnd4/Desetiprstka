import Foundation

/// Vygenerované cvičení připravené k psaní.
struct Exercise: Equatable, Sendable {
    let text: String
    let difficulty: Difficulty
    /// Klávesy, na které se cvičení nejvíc zaměřuje (slabá nebo nová písmena).
    let focusKeys: [String]

    var stage: ExerciseStage { difficulty.stage }
}

/// Délka cvičení nastavitelná v Nastavení.
enum ExerciseLength: String, CaseIterable, Identifiable, Sendable {
    case short
    case medium
    case long

    var id: String { rawValue }

    var title: String {
        switch self {
        case .short: "Krátké"
        case .medium: "Střední"
        case .long: "Dlouhé"
        }
    }

    /// Přibližný počet znaků textu.
    var characterCount: Int {
        switch self {
        case .short: 80
        case .medium: 150
        case .long: 240
        }
    }
}
