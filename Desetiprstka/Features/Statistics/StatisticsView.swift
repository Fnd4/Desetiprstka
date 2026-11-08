import SwiftUI
import SwiftData
import Charts

/// Statistiky: přehled výkonu a statistiky jednotlivých kláves.
struct StatisticsView: View {
    enum StatsSection: String, CaseIterable, Identifiable {
        case overview
        case keys

        var id: String { rawValue }
        var title: String { self == .overview ? String(localized: "Přehled") : String(localized: "Klávesy") }
    }

    @Query(sort: \PracticeSession.date) private var sessions: [PracticeSession]
    @State private var section: StatsSection = .overview

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    String(localized: "Zatím žádná data"),
                    systemImage: "chart.xyaxis.line",
                    description: Text("Dokonči první cvičení a uvidíš tu svůj pokrok.")
                )
            } else {
                switch section {
                case .overview: OverviewStatisticsView(sessions: sessions)
                case .keys: KeyStatisticsView()
                }
            }
        }
        .navigationTitle("Statistiky")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Sekce", selection: $section) {
                    ForEach(StatsSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }
        }
    }
}

// MARK: - Přehled

private struct OverviewStatisticsView: View {
    @Environment(\.theme) private var theme
    @AppStorage(SettingsKey.speedUnit) private var speedUnit: SpeedUnit = .wpm
    let sessions: [PracticeSession]
    @Query private var records: [PersonalRecord]
    @Query(sort: \PlayerProgress.createdAt) private var progresses: [PlayerProgress]

    /// Kolik posledních cvičení ukazují grafy.
    private let chartWindow = 60

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                HStack(alignment: .top, spacing: 20) {
                    wpmChart
                    accuracyChart
                }
                activityChart
                recordsCard
            }
            .padding(28)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
    }

    private var fullSessions: [PracticeSession] { sessions.filter { $0.isFullExercise } }

    private var summaryCard: some View {
        let full = fullSessions
        let source = full.isEmpty ? sessions : full
        let averageWPM = source.map(\.wpm).reduce(0, +) / Double(max(source.count, 1))
        let averageAccuracy = source.map(\.accuracy).reduce(0, +) / Double(max(source.count, 1))
        let bestWPM = recordValue(.bestWPM) ?? (source.map(\.wpm).max() ?? 0)
        let totalTime = sessions.map(\.duration).reduce(0, +)
        let totalCharacters = sessions.map(\.characterCount).reduce(0, +)
        let longestCombo = recordValue(.longestCombo) ?? Double(sessions.map(\.combo).max() ?? 0)

        return Card {
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    StatTile(title: String(localized: "Průměr · \(speedUnit.symbol)"), value: speedUnit.format(averageWPM), systemImage: "speedometer")
                    StatTile(title: String(localized: "Rekord · \(speedUnit.symbol)"), value: speedUnit.format(bestWPM), systemImage: "trophy")
                    StatTile(title: String(localized: "Průměrná přesnost"), value: Format.percent(averageAccuracy), systemImage: "target")
                    StatTile(title: String(localized: "Nejdelší combo"), value: Format.number(longestCombo), systemImage: "bolt")
                }
                HStack(spacing: 16) {
                    StatTile(title: String(localized: "Celkový čas"), value: Format.longDuration(totalTime), systemImage: "timer")
                    StatTile(title: String(localized: "Napsané znaky"), value: Format.number(totalCharacters), systemImage: "character.cursor.ibeam")
                    StatTile(title: String(localized: "Dokončená cvičení"), value: Format.number(sessions.count), systemImage: "checkmark.circle")
                    StatTile(title: String(localized: "Nejdelší série"), value: Format.days(progresses.first?.longestStreak ?? 0), systemImage: "flame")
                }
            }
        }
    }

    private var chartSessions: [PracticeSession] { Array(fullSessions.suffix(chartWindow)) }

    private var wpmChart: some View {
        Card(title: String(localized: "Rychlost v čase (\(speedUnit.symbol))"), systemImage: "speedometer") {
            Chart(chartSessions) { session in
                LineMark(x: .value(String(localized: "Datum"), session.date), y: .value(String(localized: "Rychlost"), speedUnit.value(wpm: session.wpm, strokesPerMinute: session.strokesPerMinute)))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(theme.accent)
                PointMark(x: .value(String(localized: "Datum"), session.date), y: .value(String(localized: "Rychlost"), speedUnit.value(wpm: session.wpm, strokesPerMinute: session.strokesPerMinute)))
                    .symbolSize(14)
                    .foregroundStyle(theme.accent)
            }
            .frame(height: 200)
        }
    }

    private var accuracyChart: some View {
        let values = chartSessions.map { $0.accuracy * 100 }
        let lowest = min(values.min() ?? 80, 80)
        return Card(title: String(localized: "Přesnost v čase (%)"), systemImage: "target") {
            Chart {
                RuleMark(y: .value(String(localized: "Cíl"), 94))
                    .foregroundStyle(Color.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                ForEach(chartSessions) { session in
                    LineMark(x: .value(String(localized: "Datum"), session.date), y: .value(String(localized: "Přesnost"), session.accuracy * 100))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.green)
                }
            }
            .chartYScale(domain: floor(lowest / 5) * 5...100)
            .frame(height: 200)
        }
    }

    /// Minuty psaní po dnech za posledních 30 dní.
    private var activityChart: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days: [Date] = (0..<30).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
        var minutes: [Date: Double] = [:]
        for session in sessions {
            minutes[calendar.startOfDay(for: session.date), default: 0] += session.duration / 60
        }
        let activeDays = days.filter { (minutes[$0] ?? 0) > 0 }.count

        return Card(title: String(localized: "Aktivita za posledních 30 dní"), systemImage: "calendar") {
            Chart(days, id: \.self) { day in
                BarMark(
                    x: .value(String(localized: "Den"), day, unit: .day),
                    y: .value(String(localized: "Minuty"), minutes[day] ?? 0)
                )
                .foregroundStyle(theme.accent.opacity((minutes[day] ?? 0) > 0 ? 0.8 : 0.15))
                .cornerRadius(3)
            }
            .chartYAxisLabel("min")
            .frame(height: 140)
            Text("Aktivní dny: \(activeDays) z 30")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var recordsCard: some View {
        Card(title: String(localized: "Osobní rekordy"), systemImage: "trophy") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(RecordKind.allCases) { kind in
                    HStack(spacing: 10) {
                        Image(systemName: kind.symbol)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(kind.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(recordValue(kind).map { kind.format($0) } ?? "—")
                                .font(.callout.weight(.semibold))
                                .monospacedDigit()
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func recordValue(_ kind: RecordKind) -> Double? {
        records.first { $0.kindRaw == kind.rawValue }?.value
    }
}

// MARK: - Klávesy

private struct KeyStatisticsView: View {
    @Query(sort: \LetterStat.key) private var letterStats: [LetterStat]
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @AppStorage(SettingsKey.keyboardLayout) private var layoutKind: KeyboardLayoutKind = .czechQWERTZ
    @State private var selectedKey: String?

    private var snapshots: [String: LetterStatSnapshot] {
        Dictionary(letterStats.map { ($0.key, $0.snapshot) }, uniquingKeysWith: { first, _ in first })
    }

    /// Klávesy s dostatkem dat pro hodnocení.
    private var rated: [LetterStatSnapshot] {
        snapshots.values.filter { $0.attempts >= 10 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heatmapCard
                HStack(alignment: .top, spacing: 20) {
                    rankingCard(title: String(localized: "Nejslabší klávesy"), symbol: "arrow.down.circle",
                                items: rated.sorted { $0.recentErrorRate > $1.recentErrorRate })
                    rankingCard(title: String(localized: "Nejsilnější klávesy"), symbol: "arrow.up.circle",
                                items: rated.sorted { $0.recentErrorRate < $1.recentErrorRate })
                }
                tableCard
            }
            .padding(28)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
    }

    private var heatmapCard: some View {
        let accuracy = Dictionary(
            snapshots.values.filter { $0.attempts > 0 }.map { ($0.key, $0.accuracy) },
            uniquingKeysWith: { first, _ in first }
        )
        return Card(title: String(localized: "Heatmapa klávesnice"), systemImage: "keyboard") {
            VStack(alignment: .leading, spacing: 14) {
                KeyboardView(
                    layout: layoutKind.layout,
                    knownKeys: profiles.first?.knownKeySet ?? [],
                    heatmap: accuracy,
                    selectedKey: selectedKey,
                    onSelect: { key in
                        withAnimation(.snappy) { selectedKey = selectedKey == key ? nil : key }
                    }
                )
                HStack {
                    HeatmapLegend()
                    Spacer()
                    Text(layoutKind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let key = selectedKey {
                    Divider()
                    KeyDetailView(key: key, snapshot: snapshots[key], layout: layoutKind.layout)
                        .transition(.opacity)
                } else {
                    Text("Klikni na klávesu pro detailní statistiku.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func rankingCard(title: String, symbol: String, items: [LetterStatSnapshot]) -> some View {
        Card(title: title, systemImage: symbol) {
            if items.isEmpty {
                Text("Potřebujeme víc dat – stačí pár cvičení.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(items.prefix(5), id: \.key) { item in
                        Button {
                            withAnimation(.snappy) { selectedKey = item.key }
                        } label: {
                            HStack(spacing: 10) {
                                KeyChip(key: item.key,
                                        finger: layoutKind.layout.stroke(forLearnable: item.key)?.primary.finger,
                                        size: 28)
                                Text(Format.percent(item.accuracy))
                                    .monospacedDigit()
                                Spacer()
                                if let reaction = item.averageReaction {
                                    Text(Format.milliseconds(reaction))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var tableCard: some View {
        let rows = Curriculum.orderedKeys.compactMap { snapshots[$0] }.filter { $0.attempts > 0 }
        return Card(title: String(localized: "Všechny klávesy"), systemImage: "tablecells") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Klávesa")
                    Text("Stisknutí")
                    Text("Chyby")
                    Text("Přesnost")
                    Text("Reakce")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                ForEach(rows, id: \.key) { row in
                    GridRow {
                        Text(Curriculum.displayName(for: row.key))
                            .fontWeight(.semibold)
                        Text(Format.number(row.attempts))
                        Text(Format.number(row.errors))
                            .foregroundStyle(row.errors > 0 ? Color.primary : Color.secondary)
                        Text(Format.percent(row.accuracy))
                            .foregroundStyle(HeatmapScale.baseColor(for: row.accuracy))
                        Text(row.averageReaction.map { Format.milliseconds($0) } ?? "—")
                    }
                    .monospacedDigit()
                    .font(.callout)
                }
            }
        }
    }
}

/// Detail jedné klávesy.
struct KeyDetailView: View {
    let key: String
    let snapshot: LetterStatSnapshot?
    let layout: KeyboardLayout

    var body: some View {
        let finger = layout.stroke(forLearnable: key)?.primary.finger
        HStack(alignment: .center, spacing: 20) {
            KeyChip(key: key, finger: finger, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text("Klávesa \(Curriculum.displayName(for: key))")
                    .font(.headline)
                if let finger {
                    Text("Prst: \(finger.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 170, alignment: .leading)

            if let snapshot, snapshot.attempts > 0 {
                StatTile(title: String(localized: "Stisknutí"), value: Format.number(snapshot.attempts), size: 20)
                StatTile(title: String(localized: "Chyby"), value: Format.number(snapshot.errors), size: 20)
                StatTile(title: String(localized: "Přesnost"), value: Format.percent(snapshot.accuracy), size: 20)
                StatTile(title: String(localized: "Průměrná reakce"),
                         value: snapshot.averageReaction.map { Format.milliseconds($0) } ?? "—", size: 20)
            } else {
                Text("Tuto klávesu jsi zatím nepsal.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}
