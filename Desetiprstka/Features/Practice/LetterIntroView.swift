import SwiftUI

/// Představení nových kláves: která klávesa, kterým prstem a jak.
struct LetterIntroView: View {
    let keys: [String]
    let layout: KeyboardLayout
    let knownKeys: Set<String>
    let onFinish: () -> Void
    let onClose: () -> Void

    @State private var index = 0

    private var key: String { keys[min(index, keys.count - 1)] }
    private var stroke: KeyStroke? { layout.stroke(forLearnable: key) }
    private var finger: Finger { stroke?.primary.finger ?? .leftIndex }
    private var isLast: Bool { index >= keys.count - 1 }

    var body: some View {
        VStack(spacing: 26) {
            HStack {
                Button(action: onClose) {
                    Label("Ukončit", systemImage: "xmark")
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if keys.count > 1 {
                    Text("Nová klávesa \(index + 1) z \(keys.count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                Button("Přeskočit", action: onFinish)
                    .help("Přeskočit představení a začít psát")
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Text(key == Curriculum.shiftKey ? String(localized: "Nová klávesa") : String(localized: "Nové písmeno"))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(Curriculum.displayName(for: key))
                    .font(.system(size: key == Curriculum.shiftKey ? 64 : 104, weight: .bold, design: .rounded))
                    .foregroundStyle(finger.color)
                    .contentTransition(.opacity)
                    .id(key)

                Text(fingerSentence)
                    .font(.title2.weight(.medium))

                Text(Curriculum.tip(for: key, finger: finger))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .fixedSize(horizontal: false, vertical: true)
            }

            KeyboardView(
                layout: layout,
                knownKeys: knownKeys,
                highlightedKeyIDs: stroke?.keyIDs ?? []
            )
            .frame(maxWidth: 760)

            HandsView(activeFingers: stroke?.fingers ?? [finger], scale: 0.9)

            Spacer(minLength: 0)

            Button {
                if isLast {
                    onFinish()
                } else {
                    withAnimation(.snappy) { index += 1 }
                }
            } label: {
                Text(isLast ? String(localized: "Rozumím, jdeme psát") : String(localized: "Další klávesa"))
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fingerSentence: String {
        if key == Curriculum.shiftKey {
            return String(localized: "Mačkej malíčkem – levý nebo pravý Shift")
        }
        return String(localized: "Mačkej: \(finger.name)")
    }
}
