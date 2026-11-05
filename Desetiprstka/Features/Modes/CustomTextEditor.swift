import SwiftUI
import AppKit

/// Vložení vlastního textu k opisu.
struct CustomTextEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @AppStorage(SettingsKey.customText) private var savedText = ""
    @State private var draft = ""

    let onStart: (String) -> Void

    private var normalized: String { CustomTextNormalizer.normalize(draft) }
    private var isValid: Bool { normalized.count >= CustomTextNormalizer.minLength }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ModeIcon(mode: .customText, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vlastní text")
                        .font(.title3.weight(.semibold))
                    Text("Vlož cokoliv – článek, poznámky, úkol do školy. Opíšeš ho a dostaneš stejné výsledky jako u cvičení.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            TextEditor(text: $draft)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.cardBorder, lineWidth: 1)
                )
                .frame(minHeight: 220)
                .overlay(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("Sem vlož nebo napiš text…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }

            info

            HStack {
                Button("Vložit ze schránky") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        draft = text
                    }
                }
                Button("Vymazat", role: .destructive) { draft = "" }
                    .disabled(draft.isEmpty)
                Spacer()
                Button("Zrušit", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    savedText = normalized
                    onStart(normalized)
                    dismiss()
                } label: {
                    Label("Začít opis", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(22)
        .frame(width: 620)
        .onAppear { draft = savedText }
    }

    @ViewBuilder
    private var info: some View {
        let text = normalized
        let hard = CustomTextNormalizer.hardCharacters(in: text)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 14) {
                Label("\(Format.number(text.count)) znaků", systemImage: "character.cursor.ibeam")
                Label("\(Format.number(TypingMetrics.strokes(in: text))) úhozů", systemImage: "keyboard")
                if text.count > 0 {
                    Label("asi \(estimatedMinutes(for: text)) min", systemImage: "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if text.count >= CustomTextNormalizer.maxLength {
                Text("Text je dlouhý – použije se prvních \(Format.number(CustomTextNormalizer.maxLength)) znaků.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if !hard.isEmpty {
                Text("Velká písmena s diakritikou (\(hard.sorted().prefix(5).map(String.init).joined(separator: ", "))) napíšeš s Caps Lockem.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Odřádkování se změní na mezery, typografické uvozovky a pomlčky na znaky z klávesnice.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func estimatedMinutes(for text: String) -> Int {
        // Odhad při 150 úhozech za minutu.
        max(Int((Double(TypingMetrics.strokes(in: text)) / 150).rounded(.up)), 1)
    }
}
