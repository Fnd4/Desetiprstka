import SwiftUI
import SwiftData

/// Rychlé nastavení před cvičením. Start Practice na Domů ho nepotřebuje.
struct PracticeSetupView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \PlayerProgress.createdAt) private var progresses: [PlayerProgress]
    @AppStorage(SettingsKey.exerciseLength) private var preferredLength: ExerciseLength = .medium
    @AppStorage(SettingsKey.keyboardLayout) private var layoutKind: KeyboardLayoutKind = .czechQWERTZ

    @State private var configuration: PracticeConfiguration = .adaptive
    @State private var showsMinimumWarning = false

    private var store: ProgressStore { ProgressStore(context: modelContext) }
    private var profileLevel: Int { profiles.first?.level ?? 1 }
    private var currentSpeed: SpeedSetting { progresses.first?.speedSetting ?? .default }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Režim", selection: $configuration.mode) {
                        // Vlastní text se zadává v Režimech (potřebuje text).
                        ForEach(GameMode.allCases.filter { $0 != .customText }) { mode in
                            Label(mode.title, systemImage: mode.symbol).tag(mode)
                        }
                    }
                    Text(configuration.mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if configuration.mode == .timeAttack {
                        Picker("Délka", selection: $configuration.duration) {
                            ForEach(TimeAttackDuration.allCases) { duration in
                                Text(duration.title).tag(duration)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    if configuration.mode == .speedTest {
                        Picker("Délka", selection: $configuration.speedTestDuration) {
                            ForEach(TimeAttackDuration.allCases) { duration in
                                Text(duration.title).tag(duration)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    if configuration.mode == .exam {
                        Picker("Délka", selection: $configuration.examDuration) {
                            ForEach(ExamDuration.allCases) { duration in
                                Text(duration.title).tag(duration)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section {
                    Toggle(isOn: $configuration.isAdaptive) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Adaptive")
                            Text("Aplikace zvolí obtížnost, rychlost i délku podle tvých výsledků.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !configuration.isAdaptive {
                        Picker("Obtížnost textu", selection: $configuration.textLevel) {
                            Text("Podle pokroku (úroveň \(profileLevel))").tag(Int?.none)
                            Divider()
                            ForEach(Difficulty.range, id: \.self) { level in
                                Text("Úroveň \(level) · \(Difficulty(level: level).stage.title)").tag(Int?.some(level))
                            }
                        }

                        Picker("Rychlost", selection: $configuration.speed) {
                            Text("Aktuální (\(currentSpeed.label))").tag(SpeedDifficulty?.none)
                            Divider()
                            ForEach(SpeedDifficulty.allCases) { speed in
                                Text(speedLabel(speed)).tag(SpeedDifficulty?.some(speed))
                            }
                        }

                        if configuration.mode.usesLengthSetting {
                            Picker("Délka textu", selection: lengthBinding) {
                                ForEach(ExerciseLength.allCases) { length in
                                    Text("\(length.title) (~\(length.characterCount) znaků)").tag(length)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Obtížnost")
                }

                Section {
                    knownKeysEditor
                } header: {
                    HStack {
                        Text("Známá písmena")
                        Spacer()
                        Text("\(profiles.first?.knownKeys.count ?? 0) z \(Curriculum.orderedKeys.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Zrušit") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    appState.startPractice(configuration)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(16)
        }
        .frame(width: 520, height: 620)
        .onAppear { configuration = appState.setupPreset }
        .alert("Potřebuješ alespoň \(Curriculum.minimumLetters) písmena", isPresented: $showsMinimumWarning) {
            Button("OK", role: .cancel) {}
        }
    }

    private var lengthBinding: Binding<ExerciseLength> {
        Binding(
            get: { configuration.length ?? preferredLength },
            set: { configuration.length = $0 }
        )
    }

    private func speedLabel(_ speed: SpeedDifficulty) -> String {
        let setting = SpeedSetting(mode: speed, customWPM: currentSpeed.customWPM)
        return setting.label
    }

    private var knownKeysEditor: some View {
        let known = profiles.first?.knownKeySet ?? []
        return FlowLayout(spacing: 6) {
            ForEach(Curriculum.orderedKeys, id: \.self) { key in
                Button {
                    if !store.toggleKey(key) { showsMinimumWarning = true }
                } label: {
                    KeyChip(
                        key: key,
                        finger: layoutKind.layout.stroke(forLearnable: key)?.primary.finger,
                        isActive: known.contains(key),
                        size: 28
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
