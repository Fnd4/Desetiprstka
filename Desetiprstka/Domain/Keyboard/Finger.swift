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
        case .leftPinky: "malíček levé ruky"
        case .leftRing: "prsteníček levé ruky"
        case .leftMiddle: "prostředníček levé ruky"
        case .leftIndex: "ukazováček levé ruky"
        case .thumbs: "palec"
        case .rightIndex: "ukazováček pravé ruky"
        case .rightMiddle: "prostředníček pravé ruky"
        case .rightRing: "prsteníček pravé ruky"
        case .rightPinky: "malíček pravé ruky"
        }
    }

    /// Krátký název do legendy.
    var kindName: String {
        switch self {
        case .leftPinky, .rightPinky: "Malíček"
        case .leftRing, .rightRing: "Prsteníček"
        case .leftMiddle, .rightMiddle: "Prostředníček"
        case .leftIndex, .rightIndex: "Ukazováček"
        case .thumbs: "Palec"
        }
    }

    /// Klávesa základní řady, na které prst odpočívá.
    var homeKeyLabel: String {
        switch self {
        case .leftPinky: "A"
        case .leftRing: "S"
        case .leftMiddle: "D"
        case .leftIndex: "F"
        case .thumbs: "mezerníku"
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
