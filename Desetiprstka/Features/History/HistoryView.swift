import SwiftUI
import SwiftData

/// Seznam všech dokončených cvičení.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @State private var selection: Set<PracticeSession.ID> = []
    @AppStorage(SettingsKey.speedUnit) private var speedUnit: SpeedUnit = .wpm

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    String(localized: "Žádná historie"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Každé dokončené cvičení se tu uloží.")
                )
            } else {
                VStack(spacing: 0) {
                    table
                    if let session = selectedSession {
                        Divider()
                        detail(for: session)
                    }
                }
            }
        }
        .navigationTitle("Historie")
    }

    private var table: some View {
        Table(sessions, selection: $selection) {
            TableColumn("Datum") { session in
                Text(Format.date(session.date))
            }
            .width(min: 120, ideal: 150)

            TableColumn("Typ") { session in
                Label(session.kindTitle, systemImage: session.kindSymbol)
            }
            .width(min: 130, ideal: 170)

            TableColumn("Úroveň") { session in
                Text("\(session.level)")
                    .monospacedDigit()
            }
            .width(60)

            TableColumn(speedUnit.symbol) { session in
                Text(speedUnit.format(session.wpm, strokesPerMinute: session.strokesPerMinute))
                    .monospacedDigit()
            }
            .width(60)

            TableColumn("Přesnost") { session in
                Text(Format.percent(session.accuracy))
                    .monospacedDigit()
                    .foregroundStyle(session.accuracy >= 0.94 ? Color.primary : Color.orange)
            }
            .width(80)

            TableColumn("Chyby") { session in
                Text("\(session.errorCount)")
                    .monospacedDigit()
            }
            .width(60)

            TableColumn("Combo") { session in
                Text("\(session.combo)")
                    .monospacedDigit()
            }
            .width(60)

            TableColumn("Čas") { session in
                Text(Format.duration(session.duration))
                    .monospacedDigit()
            }
            .width(70)

            TableColumn("XP") { session in
                Text(session.xp > 0 ? "+\(session.xp)" : "—")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(60)
        }
        .contextMenu(forSelectionType: PracticeSession.ID.self) { ids in
            Button("Smazat", role: .destructive) {
                delete(ids)
            }
            .disabled(ids.isEmpty)
        }
        .onDeleteCommand {
            delete(selection)
        }
    }

    private var selectedSession: PracticeSession? {
        guard selection.count == 1, let id = selection.first else { return nil }
        return sessions.first { $0.id == id }
    }

    private func detail(for session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Text cvičení")
                    .font(.headline)
                Spacer()
                if !session.problemKeys.isEmpty {
                    Text("Problémové klávesy: \(session.problemKeys.map { Curriculum.displayName(for: $0) }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            ScrollView {
                Text(session.text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 110)
        }
        .padding(16)
    }

    private func delete(_ ids: Set<PracticeSession.ID>) {
        let toDelete = sessions.filter { ids.contains($0.id) }
        ProgressStore(context: modelContext).deleteSessions(toDelete)
        selection.subtract(ids)
    }
}
