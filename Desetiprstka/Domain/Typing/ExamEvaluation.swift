import Foundation

/// Vyhodnocení opisu podle zvyklostí českých škol.
///
/// - čisté úhozy = hrubé úhozy − 100 × chyby (penalizace jako u zkoušek z psaní na klávesnici)
/// - chybovost = chyby / hrubé úhozy
/// Známka je orientační – školy mají vlastní tabulky podle ročníku a měsíce.
struct ExamEvaluation: Equatable, Sendable {
    static let penaltyPerError = 100

    let grossStrokes: Int
    let errors: Int
    let duration: TimeInterval

    var minutes: Double { max(duration, 1) / 60 }
    var netStrokes: Int { max(grossStrokes - errors * Self.penaltyPerError, 0) }
    var grossPerMinute: Double { Double(grossStrokes) / minutes }
    var netPerMinute: Double { Double(netStrokes) / minutes }
    /// Chybovost v procentech (0,25 = 0,25 %).
    var errorPercent: Double { grossStrokes > 0 ? Double(errors) / Double(grossStrokes) * 100 : 0 }

    var grade: Grade { Grade.evaluate(netPerMinute: netPerMinute, errorPercent: errorPercent) }

    enum Grade: Int, CaseIterable, Sendable {
        case excellent = 1
        case veryGood = 2
        case good = 3
        case sufficient = 4
        case insufficient = 5

        var title: String {
            switch self {
            case .excellent: "Výborně"
            case .veryGood: "Chvalitebně"
            case .good: "Dobře"
            case .sufficient: "Dostatečně"
            case .insufficient: "Nedostatečně"
            }
        }

        /// Minimum čistých úhozů za minutu a maximální chybovost v %.
        var requirement: (net: Double, errorPercent: Double)? {
            switch self {
            case .excellent: (250, 0.3)
            case .veryGood: (200, 0.5)
            case .good: (150, 1.0)
            case .sufficient: (100, 2.0)
            case .insufficient: nil
            }
        }

        static func evaluate(netPerMinute: Double, errorPercent: Double) -> Grade {
            for grade in allCases {
                guard let requirement = grade.requirement else { continue }
                if netPerMinute >= requirement.net, errorPercent <= requirement.errorPercent {
                    return grade
                }
            }
            return .insufficient
        }

        /// Co chybí do lepší známky.
        func nextStep(netPerMinute: Double, errorPercent: Double) -> String? {
            guard rawValue > 1, let better = Grade(rawValue: rawValue - 1), let requirement = better.requirement else {
                return nil
            }
            var parts: [String] = []
            if netPerMinute < requirement.net {
                parts.append("+\(Int((requirement.net - netPerMinute).rounded(.up))) čistých úhozů/min")
            }
            if errorPercent > requirement.errorPercent {
                parts.append("chybovost pod \(Format.decimal(requirement.errorPercent)) %")
            }
            guard !parts.isEmpty else { return nil }
            return "Na \(better.rawValue) (\(better.title.lowercased())): " + parts.joined(separator: " a ")
        }
    }
}
