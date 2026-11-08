import Foundation

/// Zvukový balíček pro úhozy kláves.
enum SoundPack: String, CaseIterable, Identifiable, Sendable {
    case silent
    case soft
    case mechanical
    case typewriter
    case clicky

    var id: String { rawValue }

    var title: String {
        switch self {
        case .silent: String(localized: "Silent")
        case .soft: String(localized: "Soft")
        case .mechanical: String(localized: "Mechanical")
        case .typewriter: String(localized: "Typewriter")
        case .clicky: String(localized: "Clicky")
        }
    }

    var subtitle: String {
        switch self {
        case .silent: String(localized: "Bez zvuku úhozů")
        case .soft: String(localized: "Tlumené, sotva slyšitelné ťuknutí")
        case .mechanical: String(localized: "Plný úhoz mechanické klávesnice")
        case .typewriter: String(localized: "Kovový úder psacího stroje")
        case .clicky: String(localized: "Ostré, krátké cvaknutí")
        }
    }

    var symbol: String {
        switch self {
        case .silent: "speaker.slash"
        case .soft: "drop"
        case .mechanical: "keyboard"
        case .typewriter: "doc.plaintext"
        case .clicky: "cursorarrow.click"
        }
    }
}

/// Zvuková událost. Typing = úhozy a chyby, reward = odměny.
enum SoundEffect: Hashable, Sendable {
    case key
    case error
    case milestone
    case completion
    case record
    case challenge
    case achievement
    case levelUp

    enum Category: Sendable {
        case typing
        case reward
    }

    var category: Category {
        switch self {
        case .key, .error: .typing
        case .milestone, .completion, .record, .challenge, .achievement, .levelUp: .reward
        }
    }

    var title: String {
        switch self {
        case .key: String(localized: "Úhoz")
        case .error: String(localized: "Chyba")
        case .milestone: String(localized: "Combo")
        case .completion: String(localized: "Dokončení")
        case .record: String(localized: "Rekord")
        case .challenge: String(localized: "Výzva")
        case .achievement: String(localized: "Odznak")
        case .levelUp: String(localized: "Level up")
        }
    }

    /// Zvuky odměn, které jdou přehrát v Nastavení.
    static let rewards: [SoundEffect] = [.completion, .record, .challenge, .achievement, .levelUp]
}
