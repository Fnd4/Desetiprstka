import SwiftUI
import SwiftData

/// Přepíná mezi fázemi cvičení. Vytváří a drží view model.
struct PracticeContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.exerciseLength) private var exerciseLength: ExerciseLength = .medium
    @AppStorage(SettingsKey.keyboardLayout) private var layoutKind: KeyboardLayoutKind = .czechQWERTZ
    @Environment(\.theme) private var theme
    @State private var viewModel: PracticeViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(theme.background ?? Color(nsColor: .windowBackgroundColor))
        .task(id: appState.practiceID) {
            viewModel?.cancel()
            viewModel = PracticeViewModel(
                store: ProgressStore(context: modelContext),
                configuration: appState.activeConfiguration,
                preferredLength: exerciseLength
            )
        }
        .onDisappear {
            viewModel?.cancel()
        }
    }

    @ViewBuilder
    private func content(for viewModel: PracticeViewModel) -> some View {
        switch viewModel.phase {
        case .intro(let keys):
            LetterIntroView(
                keys: keys,
                layout: layoutKind.layout,
                knownKeys: viewModel.knownKeys,
                onFinish: { viewModel.completeIntro() },
                onClose: close
            )
        case .typing:
            PracticeView(viewModel: viewModel, layout: layoutKind.layout, onClose: close)
        case .results(let summary):
            ResultsView(
                summary: summary,
                onNext: { viewModel.nextExercise() },
                onRetry: { viewModel.restart() },
                onAddKey: { viewModel.addKeyAndContinue($0) },
                onApplySpeed: { viewModel.applySpeed($0) },
                onClose: close
            )
        }
    }

    private func close() {
        viewModel?.cancel()
        appState.endPractice()
    }
}
