import SwiftUI
import SwiftData
import Charts

/// Hlavní obrazovka (dashboard).
///
/// Progressive disclosure: nahoře jen to nejdůležitější (start, úroveň, rychlost,
/// rekord, streak, XP, výzva dne, doporučený krok), detaily po rozkliknutí.
struct HomeView: View {
    @Environment(\.theme) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \PlayerProgress.createdAt) private var progresses: [PlayerProgress]
    @Query(HomeView.recentDescriptor) private var recentSessions: [PracticeSession]
    @Query private var letterStats: [LetterStat]
    @Query private var records: [PersonalRecord]
    @Query(sort: \DailyChallengeRecord.dayKey, order: .reverse) private var challenges: [DailyChallengeRecord]
    @AppStorage(SettingsKey.keyboardLayout) private var layoutKind: KeyboardLayoutKind = .czechQWERTZ
    @AppStorage(SettingsKey.homeDetailsExpanded) private var detailsExpanded = false
    @AppStorage(SettingsKey.speedUnit) private var speedUnit: SpeedUnit = .wpm
    @State private var nextStep: NextStep?

    static var recentDescriptor: FetchDescriptor<PracticeSession> {
        var descriptor = FetchDescriptor<PracticeSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 20
        return descriptor
    }

    private var store: ProgressStore { ProgressStore(context: modelContext) }

    var body: some View {
        ScrollView {
            if let profile = profiles.first {
                VStack(alignment: .leading, spacing: 20) {
                    hero(profile)
                    summaryCard(profile)

                    HStack(alignment: .top, spacing: 20) {
                        dailyChallengeCard
                        nextStepCard
                    }

                    DisclosureGroup(isExpanded: $detailsExpanded) {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .top, spacing: 20) {
                                progressCard(profile)
                                recentCard
                            }
                            knownKeysCard(profile)
                        }
                        .padding(.top, 12)
                    } label: {
                        Text("Pokrok, poslední cvičení a známá písmena")
                            .font(.headline)
                    }
                }
                .padding(28)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Domů")
        .task(id: refreshKey) { refresh() }
    }

    // MARK: - Data

    private var progress: PlayerProgress? { progresses.first }
    private var speed: SpeedSetting { progress?.speedSetting ?? .default }

    private var todaysChallenge: DailyChallengeRecord? {
        let key = DayKey.string(for: .now)
        return challenges.first { $0.dayKey == key }
    }

    /// Změna klíče = přepočítat doporučený krok.
    private var refreshKey: String {
        [
            recentSessions.first.map { "\($0.date.timeIntervalSince1970)" } ?? "-",
            "\(profiles.first?.knownKeys.count ?? 0)",
            speed.label,
            DayKey.string(for: .now),
        ].joined(separator: "|")
    }

    private func refresh() {
        let store = self.store
        let progress = store.playerProgress()
        store.todaysChallengeRecord()
        store.refreshAchievements()

        let profile = store.profile()
        let snapshots = store.snapshots()
        let recentAccuracy = store.recentAccuracy() ?? 0
        let input = NextStepAdvisor.Input(
            hasSessions: !recentSessions.isEmpty,
            streak: progress.displayedStreak,
            streakAtRisk: StreakTracker.isAtRisk(progress.streakState),
            recommendedKey: AdaptiveEngine().recommendNewKey(
                knownKeys: profile.knownKeySet, snapshots: snapshots, recentAccuracy: recentAccuracy
            ),
            speedRecommendation: store.currentSpeedRecommendation(),
            weakKeys: weakKeys(for: profile),
            dailyChallengeDone: store.todaysChallengeRecord().isCompleted
        )
        nextStep = NextStepAdvisor.advise(input)
    }

    private func perform(_ action: NextStepAction) {
        switch action {
        case .startPractice(let configuration):
            appState.startPractice(configuration)
        case .addKey(let key):
            store.addKnownKey(key)
            store.refreshAchievements()
        case .changeSpeed(let setting):
            store.setSpeed(setting)
        }
        refresh()
    }

    // MARK: - Hero

    private func hero(_ profile: UserProfile) -> some View {
        let difficulty = profile.difficulty
        return HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Další cvičení")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(difficulty.stage.title, systemImage: difficulty.stage.symbol)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("\(difficulty.title) z \(Difficulty.maxLevel) · rychlost \(speed.label)")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Button {
                appState.openPracticeSetup()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .controlSize(.large)
            .help("Nastavit cvičení (⇧⌘N)")

            Button {
                appState.startPractice()
            } label: {
                Label("Start Practice", systemImage: "play.fill")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            .keyboardShortcut(.defaultAction)
            .help("Začít hned (⏎ nebo ⌘N)")
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.accent.opacity(0.16), theme.accent.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Souhrn

    private func summaryCard(_ profile: UserProfile) -> some View {
        let level = progress?.playerLevel ?? PlayerLevel(totalXP: 0)
        let streak = progress?.displayedStreak ?? 0
        let bestWPM = records.first { $0.kindRaw == RecordKind.bestWPM.rawValue }?.value

        return Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    StatTile(title: String(localized: "Psaní"), value: profile.difficulty.title,
                             systemImage: profile.difficulty.stage.symbol, size: 20)
                    StatTile(title: String(localized: "Rychlost"), value: speed.label,
                             systemImage: speed.mode.symbol, size: 20)
                    StatTile(title: String(localized: "Rekord"), value: bestWPM.map { speedUnit.label($0) } ?? "—",
                             systemImage: "trophy", size: 20)
                    StatTile(title: String(localized: "Série"), value: streak > 0 ? String(localized: "\(streak) day streak") : "—",
                             systemImage: "flame", tint: streak > 0 ? .orange : .primary, size: 20)
                }

                Divider()

                HStack(spacing: 12) {
                    let rank = PlayerRank.rank(for: level.level)
                    Label("Level \(level.level) · \(rank.title)", systemImage: rank.symbol)
                        .font(.headline)
                        .monospacedDigit()
                        .fixedSize()
                    ProgressView(value: level.progress)
                    Text(level.isMax
                         ? String(localized: "Max")
                         : String(localized: "\(Format.number(level.xpIntoLevel)) / \(Format.number(level.xpForNextLevel)) XP"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Výzva a doporučení

    private var dailyChallengeCard: some View {
        Card(title: String(localized: "Výzva dne"), systemImage: "star.circle") {
            if let record = todaysChallenge, let challenge = record.challenge {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: record.isCompleted ? "checkmark.circle.fill" : challenge.kind.symbol)
                            .font(.title2)
                            .foregroundStyle(record.isCompleted ? Color.green : theme.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.title)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(challenge.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ProgressView(value: challenge.fraction(record.progress))
                        .progressTint(record.isCompleted ? .green : nil)
                    HStack {
                        Text(challenge.formattedProgress(record.progress))
                            .monospacedDigit()
                        Spacer()
                        Text(record.isCompleted ? String(localized: "Splněno") : String(localized: "+\(challenge.reward) XP"))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
    }

    private var nextStepCard: some View {
        Card(title: String(localized: "Doporučený další krok"), systemImage: "arrow.forward.circle") {
            if let step = nextStep {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: step.symbol)
                            .font(.title2)
                            .foregroundStyle(theme.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.headline)
                            Text(step.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        Button(step.actionTitle) { perform(step.action) }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
    }

    // MARK: - Progres

    private func progressCard(_ profile: UserProfile) -> some View {
        let known = profile.knownKeySet
        let total = Curriculum.orderedKeys.count
        let learned = known.intersection(Curriculum.allKeySet).count
        let next = Curriculum.nextKey(after: known)

        return Card(title: String(localized: "Tvůj pokrok"), systemImage: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Obtížnost")
                        Spacer()
                        Text(profile.difficulty.title)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    LevelTrackView(difficulty: profile.difficulty)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Naučené klávesy")
                        Spacer()
                        Text("\(learned) z \(total)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    ProgressView(value: Double(learned), total: Double(total))
                }

                if let next {
                    Divider()
                    HStack(spacing: 12) {
                        KeyChip(key: next, finger: layoutKind.layout.stroke(forLearnable: next)?.primary.finger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Další na řadě")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Curriculum.lesson(containing: next)?.title ?? "")
                                .font(.subheadline)
                        }
                        Spacer()
                        Button("Přidat") {
                            ProgressStore(context: modelContext).addKnownKey(next)
                        }
                        .help("Při dalším cvičení se ti klávesa představí")
                    }
                }
            }
        }
    }

    // MARK: - Poslední výsledky

    private var recentCard: some View {
        Card(title: String(localized: "Poslední cvičení"), systemImage: "clock") {
            if let last = recentSessions.first {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        StatTile(title: speedUnit.symbol, value: speedUnit.format(last.wpm, strokesPerMinute: last.strokesPerMinute), systemImage: "speedometer")
                        StatTile(title: String(localized: "Přesnost"), value: Format.percent(last.accuracy), systemImage: "target")
                    }
                    HStack(spacing: 12) {
                        StatTile(title: String(localized: "Chyby"), value: "\(last.errorCount)", systemImage: "xmark.circle")
                        StatTile(title: String(localized: "Čas"), value: Format.duration(last.duration), systemImage: "timer")
                    }

                    if recentSessions.count > 1 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rychlost v posledních cvičeních")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            sparkline
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zatím žádné cvičení")
                        .font(.title3.weight(.semibold))
                    Text("Klikni na Start Practice a začni. Výsledky se ti tady objeví hned po prvním cvičení.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            }
        }
    }

    private var sparkline: some View {
        let points = recentSessions.reversed().enumerated().map {
            ChartPoint(index: $0.offset, value: $0.element.wpm)
        }
        return Chart(points) { point in
            AreaMark(x: .value(String(localized: "Cvičení"), point.index), y: .value(String(localized: "WPM"), point.value))
                .foregroundStyle(
                    LinearGradient(colors: [theme.accent.opacity(0.25), theme.accent.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)
            LineMark(x: .value(String(localized: "Cvičení"), point.index), y: .value(String(localized: "WPM"), point.value))
                .foregroundStyle(theme.accent)
                .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 56)
    }

    // MARK: - Známá písmena

    private func knownKeysCard(_ profile: UserProfile) -> some View {
        let weak = weakKeys(for: profile)
        let layout = layoutKind.layout

        return Card(title: String(localized: "Známá písmena"), systemImage: "character.cursor.ibeam") {
            VStack(alignment: .leading, spacing: 14) {
                FlowLayout(spacing: 8) {
                    ForEach(profile.knownKeys, id: \.self) { key in
                        KeyChip(
                            key: key,
                            finger: layout.stroke(forLearnable: key)?.primary.finger,
                            badge: weak.contains(key) ? "!" : nil
                        )
                    }
                }

                HStack {
                    if !weak.isEmpty {
                        Label("Častěji chybuješ u: \(weak.map { Curriculum.displayName(for: $0) }.joined(separator: ", "))",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button("Upravit písmena") {
                        appState.selection = .letters
                    }
                }
            }
        }
    }

    private func weakKeys(for profile: UserProfile) -> [String] {
        let snapshots = Dictionary(letterStats.map { ($0.key, $0.snapshot) }, uniquingKeysWith: { first, _ in first })
        return AdaptiveEngine()
            .weakestKeys(knownKeys: profile.knownKeySet, snapshots: snapshots, limit: 4)
            .map(\.key)
    }
}

/// Bod pro jednoduché grafy.
struct ChartPoint: Identifiable {
    let index: Int
    let value: Double
    var id: Int { index }
}
