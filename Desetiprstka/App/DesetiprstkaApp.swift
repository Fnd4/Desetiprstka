import SwiftUI
import SwiftData

@main
struct DesetiprstkaApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager.shared
    private let container = Persistence.makeContainer()

    init() {
        // Zvuky se vygenerují na pozadí hned při startu → první úhoz už nic nečeká.
        AudioManager.shared.prepare()
    }

    var body: some Scene {
        Window("Desetiprstka", id: "main") {
            RootView()
                .environment(appState)
                .environment(themeManager)
                .themed(themeManager)
        }
        .modelContainer(container)
        .defaultSize(width: 1120, height: 780)
        .commands {
            AppCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .environment(themeManager)
                .themed(themeManager)
        }
        .modelContainer(container)
    }
}

/// Položky v menu aplikace.
struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Start Practice") {
                appState.startPractice()
            }
            .keyboardShortcut("n")

            Button("Nastavit cvičení…") {
                appState.endPractice()
                appState.openPracticeSetup()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandMenu("Přejít") {
            ForEach(SidebarItem.allCases) { item in
                Button(item.title) {
                    appState.endPractice()
                    appState.selection = item
                }
                .keyboardShortcut(item.shortcut, modifiers: .command)
            }
        }
    }
}
