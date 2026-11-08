import AppKit
import SwiftUI
import SwiftData

/// Výběr kláves, které uživatel už umí. Změna se projeví v dalším cvičení.
struct LettersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query private var letterStats: [LetterStat]
    @AppStorage(SettingsKey.keyboardLayout) private var layoutKind: KeyboardLayoutKind = .czechQWERTZ
    @State private var showsMinimumWarning = false

    private var store: ProgressStore { ProgressStore(context: modelContext) }

    var body: some View {
        ScrollView {
            if let profile = profiles.first {
                let known = profile.knownKeySet
                VStack(alignment: .leading, spacing: 20) {
                    header(known: known)

                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            KeyboardView(layout: layoutKind.layout, knownKeys: known, onToggle: toggle)
                            HStack {
                                FingerLegend()
                                Spacer()
                                Text("Klikni na klávesu pro přidání nebo odebrání")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(Curriculum.lessons) { lesson in
                        LessonRow(
                            lesson: lesson,
                            known: known,
                            layout: layoutKind.layout,
                            accuracy: accuracyByKey,
                            onToggle: toggle,
                            onSetAll: { isKnown in
                                if !store.setKeys(lesson.keys, known: isKnown) { warnAboutMinimum() }
                            }
                        )
                    }
                }
                .padding(28)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Písmena")
        .alert("Potřebuješ alespoň \(Curriculum.minimumLetters) písmena", isPresented: $showsMinimumWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Z méně písmen se nedají sestavit cvičení.")
        }
    }

    private func header(known: Set<String>) -> some View {
        let next = Curriculum.nextKey(after: known)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Která písmena už umíš?")
                    .font(.title2.weight(.semibold))
                Text("Cvičení se skládají jen z vybraných kláves. Seznam můžeš kdykoliv změnit.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let next {
                Button {
                    store.addKnownKey(next)
                } label: {
                    Label("Přidat další: \(Curriculum.displayName(for: next))", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .help("Přidá další klávesu podle doporučeného pořadí výuky")
            }
        }
    }

    private var accuracyByKey: [String: Double] {
        Dictionary(
            letterStats.filter { $0.attempts >= 10 }.map { ($0.key, $0.snapshot.accuracy) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func toggle(_ key: String) {
        if !store.toggleKey(key) { warnAboutMinimum() }
    }

    private func warnAboutMinimum() {
        NSSound.beep()
        showsMinimumWarning = true
    }
}

/// Jedna lekce s čipy kláves.
private struct LessonRow: View {
    let lesson: Lesson
    let known: Set<String>
    let layout: KeyboardLayout
    let accuracy: [String: Double]
    let onToggle: (String) -> Void
    let onSetAll: (Bool) -> Void

    private var knownCount: Int { lesson.keys.filter(known.contains).count }
    private var isComplete: Bool { knownCount == lesson.keys.count }

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Lekce \(lesson.id)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    Text(lesson.title)
                        .font(.headline)
                    Text(lesson.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 240, alignment: .leading)

                FlowLayout(spacing: 8) {
                    ForEach(lesson.keys, id: \.self) { key in
                        Button {
                            onToggle(key)
                        } label: {
                            KeyChip(
                                key: key,
                                finger: layout.stroke(forLearnable: key)?.primary.finger,
                                isActive: known.contains(key),
                                size: 38
                            )
                        }
                        .buttonStyle(.plain)
                        .help(helpText(for: key))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(isComplete ? String(localized: "Odebrat vše") : String(localized: "Vybrat vše")) {
                    onSetAll(!isComplete)
                }
                .controlSize(.small)
            }
        }
    }

    private func helpText(for key: String) -> String {
        var parts: [String] = []
        if let finger = layout.stroke(forLearnable: key)?.primary.finger {
            parts.append(String(localized: "Prst: \(finger.name)"))
        }
        if let value = accuracy[key] {
            parts.append(String(localized: "Přesnost: \(Format.percent(value))"))
        }
        return parts.joined(separator: " · ")
    }
}
