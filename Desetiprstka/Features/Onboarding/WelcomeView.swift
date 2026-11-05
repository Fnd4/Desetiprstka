import SwiftUI
import SwiftData

/// Úvodní obrazovka při prvním spuštění.
struct WelcomeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    private enum Choice: CaseIterable, Identifiable {
        case beginner
        case homeRow
        case custom

        var id: Self { self }

        var title: String {
            switch self {
            case .beginner: "Jsem úplný začátečník"
            case .homeRow: "Znám základní řadu"
            case .custom: "Vyberu si písmena sám"
            }
        }

        var subtitle: String {
            switch self {
            case .beginner: "Začneme klávesami F, J, D a K. Ke každé ti ukážu správný prst."
            case .homeRow: "Začneš s klávesami A S D F G H J K L."
            case .custom: "Otevřu přehled písmen a označíš, co už umíš."
            }
        }

        var symbol: String {
            switch self {
            case .beginner: "leaf"
            case .homeRow: "hand.raised"
            case .custom: "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(theme.accent)
                Text("Vítej v Desetiprstce")
                    .font(.largeTitle.weight(.bold))
                Text("Naučíš se psát všemi deseti bez dívání na klávesnici. Cvičení se přizpůsobují tvému tempu a častěji opakují písmena, u kterých chybuješ.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(Choice.allCases) { choice in
                    Button {
                        select(choice)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: choice.symbol)
                                .font(.title2)
                                .frame(width: 32)
                                .foregroundStyle(theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(choice.title)
                                    .font(.headline)
                                Text(choice.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(32)
        .frame(width: 520)
    }

    private func select(_ choice: Choice) {
        let store = ProgressStore(context: modelContext)
        switch choice {
        case .beginner:
            store.completeOnboarding(knownKeys: Set(Curriculum.beginnerKeys), markAsIntroduced: false)
        case .homeRow:
            store.completeOnboarding(knownKeys: Set(Curriculum.homeRowKeys), markAsIntroduced: true)
        case .custom:
            store.completeOnboarding(knownKeys: Set(Curriculum.beginnerKeys), markAsIntroduced: false)
            appState.selection = .letters
        }
        dismiss()
    }
}
