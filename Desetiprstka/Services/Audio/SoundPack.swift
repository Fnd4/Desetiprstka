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
        case .silent: "Silent"
        case .soft: "Soft"
        case .mechanical: "Mechanical"
        case .typewriter: "Typewriter"
        case .clicky: "Clicky"
        }
    }

    var subtitle: String {
        switch self {
        case .silent: "Bez zvuku úhozů"
        case .soft: "Tlumené, sotva slyšitelné ťuknutí"
        case .mechanical: "Plný úhoz mechanické klávesnice"
        case .typewriter: "Kovový úder psacího stroje"
        case .clicky: "Ostré, krátké cvaknutí"
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
        case .key: "Úhoz"
        case .error: "Chyba"
        case .milestone: "Combo"
        case .completion: "Dokončení"
        case .record: "Rekord"
        case .challenge: "Výzva"
        case .achievement: "Odznak"
        case .levelUp: "Level up"
        }
    }

    /// Zvuky odměn, které jdou přehrát v Nastavení.
    static let rewards: [SoundEffect] = [.completion, .record, .challenge, .achievement, .levelUp]
}
