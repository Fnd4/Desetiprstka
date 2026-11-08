import SwiftUI

/// Ruka, ke které prst patří.
enum Hand: String, Codable, Sendable {
    case left
    case right
}

/// Prsty používané při psaní všemi deseti.
/// Oba palce sdílí jeden případ – mezerník se mačká kterýmkoliv z nich.
enum Finger: Int, CaseIterable, Identifiable, Codable, Sendable {
    case leftPinky
    case leftRing
    case leftMiddle
    case leftIndex
    case thumbs
    case rightIndex
    case rightMiddle
    case rightRing
    case rightPinky

    var id: Int { rawValue }

    var hand: Hand? {
        switch self {
        case .leftPinky, .leftRing, .leftMiddle, .leftIndex: .left
        case .rightIndex, .rightMiddle, .rightRing, .rightPinky: .right
        case .thumbs: nil
        }
    }

    /// Plný název, např. „ukazováček levé ruky“.
    var name: String {
        switch self {
        case .leftPinky: String(localized: "malíček levé ruky")
        case .leftRing: String(localized: "prsteníček levé ruky")
        case .leftMiddle: String(localized: "prostředníček levé ruky")
        case .leftIndex: String(localized: "ukazováček levé ruky")
        case .thumbs: String(localized: "palec")
        case .rightIndex: String(localized: "ukazováček pravé ruky")
        case .rightMiddle: String(localized: "prostředníček pravé ruky")
        case .rightRing: String(localized: "prsteníček pravé ruky")
        case .rightPinky: String(localized: "malíček pravé ruky")
        }
    }

    /// Krátký název do legendy.
    var kindName: String {
        switch self {
        case .leftPinky, .rightPinky: String(localized: "Malíček")
        case .leftRing, .rightRing: String(localized: "Prsteníček")
        case .leftMiddle, .rightMiddle: String(localized: "Prostředníček")
        case .leftIndex, .rightIndex: String(localized: "Ukazováček")
        case .thumbs: String(localized: "Palec")
        }
    }

    /// Klávesa základní řady, na které prst odpočívá.
    var homeKeyLabel: String {
        switch self {
        case .leftPinky: "A"
        case .leftRing: "S"
        case .leftMiddle: "D"
        case .leftIndex: "F"
        case .thumbs: String(localized: "mezerníku")
        case .rightIndex: "J"
        case .rightMiddle: "K"
        case .rightRing: "L"
        case .rightPinky: KeyboardLayoutKind.current.isCzech ? "Ů" : ";"
        }
    }

    var color: Color {
        switch self {
        case .leftPinky, .rightPinky: .purple
        case .leftRing, .rightRing: .blue
        case .leftMiddle, .rightMiddle: .green
        case .leftIndex, .rightIndex: .orange
        case .thumbs: .gray
        }
    }

    /// Jeden zástupce každého druhu prstu – pro legendu barev.
    static let legend: [Finger] = [.leftPinky, .leftRing, .leftMiddle, .leftIndex, .thumbs]
}
