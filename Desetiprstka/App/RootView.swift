import SwiftUI
import SwiftData

/// Kořenové view: buď hlavní okno se sidebarem, nebo cvičení přes celé okno.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var showsWelcome = false

    var body: some View {
        ZStack {
            if appState.isPracticing {
                PracticeContainerView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                MainView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.25), value: appState.isPracticing)
        .frame(minWidth: 940, minHeight: 680)
        .task {
            let store = ProgressStore(context: modelContext)
            let profile = store.profile()
            // Vytvoří gamifikační profil (při prvním spuštění v2 dopočítá data z historie).
            store.playerProgress()
            showsWelcome = !profile.hasCompletedOnboarding
        }
        .sheet(isPresented: $showsWelcome) {
            WelcomeView()
                .interactiveDismissDisabled()
        }
    }
}

/// Hlavní okno se sidebarem.
struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            List(SidebarItem.allCases, selection: $appState.selection) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            Group {
                switch appState.selection ?? .home {
                case .home: HomeView()
                case .modes: ModesView()
                case .letters: LettersView()
                case .statistics: StatisticsView()
                case .achievements: AchievementsView()
                case .history: HistoryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .themeBackground(theme)
        }
        .sheet(isPresented: $appState.showsPracticeSetup) {
            PracticeSetupView()
        }
    }
}
