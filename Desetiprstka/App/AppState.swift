import SwiftUI
import Observation

/// Sekce v postranním panelu.
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case home
    case modes
    case letters
    case statistics
    case achievements
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Domů"
        case .modes: "Režimy"
        case .letters: "Písmena"
        case .statistics: "Statistiky"
        case .achievements: "Odznaky"
        case .history: "Historie"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .modes: "square.grid.2x2"
        case .letters: "keyboard"
        case .statistics: "chart.xyaxis.line"
        case .achievements: "rosette"
        case .history: "clock.arrow.circlepath"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .home: "1"
        case .modes: "2"
        case .letters: "3"
        case .statistics: "4"
        case .achievements: "5"
        case .history: "6"
        }
    }
}

/// Navigační stav aplikace.
@Observable
final class AppState {
    var selection: SidebarItem? = .home
    private(set) var isPracticing = false
    /// Konfigurace právě běžícího cvičení.
    private(set) var activeConfiguration: PracticeConfiguration = .adaptive
    /// Zvyšuje se při každém spuštění – nové cvičení = nový view model.
    private(set) var practiceID = 0

    /// Rychlé nastavení před cvičením.
    var showsPracticeSetup = false
    var setupPreset: PracticeConfiguration = .adaptive

    func startPractice(_ configuration: PracticeConfiguration = .adaptive) {
        activeConfiguration = configuration
        practiceID += 1
        showsPracticeSetup = false
        isPracticing = true
    }

    func openPracticeSetup(_ preset: PracticeConfiguration = .adaptive) {
        setupPreset = preset
        showsPracticeSetup = true
    }

    func endPractice() {
        isPracticing = false
    }
}
