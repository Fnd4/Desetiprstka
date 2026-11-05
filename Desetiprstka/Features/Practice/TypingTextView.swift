import SwiftUI

/// Text cvičení s barevným odlišením napsaných, aktuálních a chybných znaků.
struct TypingTextView: View {
    /// Vzhled plochy s textem.
    enum Surface {
        /// Karta (Default, Focus).
        case card
        /// Čistý papír se serifovým písmem.
        case paper
        /// Bez rámečku (Minimal).
        case bare
    }

    @Environment(\.theme) private var theme
    let engine: TypingEngine
    /// Nekonečné režimy: zobrazí jen okno textu kolem kurzoru.
    var windowed = false
    var surface: Surface = .card
    var cursor: CursorStyle = .underline

    /// Kolik znaků před kurzorem zůstane vidět v nekonečných režimech.
    private static let trailingContext = 40
    private static let windowLength = 150

    var body: some View {
        ZStack(alignment: .topLeading) {
            if windowed {
                // Neviditelná rezerva na celou stránku → výška karty se mezi stránkami nemění.
                Text(verbatim: Self.placeholder)
                    .hidden()
                    .accessibilityHidden(true)
            }
            Text(styledText)
        }
        .font(.system(size: surface == .bare ? 34 : 30, weight: .regular,
                      design: surface == .paper ? .serif : .monospaced))
        .lineSpacing(surface == .paper ? 16 : 12)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(surface == .paper ? 40 : 28)
        .background(background)
        .overlay(border)
        .accessibilityLabel(engine.text)
    }

    private static let placeholder = String(repeating: "m", count: windowLength) + "\nm"

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: surface == .paper ? 6 : 16, style: .continuous)
        switch surface {
        case .card:
            shape.fill(theme.cardBackground)
        case .paper:
            shape.fill(theme.paper)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        case .bare:
            Color.clear
        }
    }

    @ViewBuilder
    private var border: some View {
        let shape = RoundedRectangle(cornerRadius: surface == .paper ? 6 : 16, style: .continuous)
        if engine.currentHasError {
            shape.strokeBorder(Color.red.opacity(0.5), lineWidth: 1.5)
        } else if surface == .card {
            shape.strokeBorder(theme.cardBorder, lineWidth: 1)
        } else if surface == .paper {
            shape.strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private var palette: Style.Palette {
        Style.Palette(
            highlight: theme.typingHighlight,
            pending: surface == .paper ? theme.paperText : (theme.textPrimary ?? .primary),
            inverse: surface == .paper ? theme.paper : (theme.background ?? Color(nsColor: .textBackgroundColor)),
            cursor: cursor
        )
    }

    /// Text složený z úseků se stejným stylem.
    /// Žádný úsek nemění šířku znaků (bez tučného písma, bez náhrady mezery symbolem),
    /// takže se řádky při psaní nikdy nepřelámou jinak.
    private var styledText: AttributedString {
        var segments: [(style: Style, text: String)] = []
        for index in visibleRange {
            let style: Style
            if index < engine.position {
                style = engine.states[index] == .corrected ? .corrected : .done
            } else if index == engine.position {
                style = engine.currentHasError ? .currentError : .current
            } else {
                style = .pending
            }
            let piece = String(engine.characters[index])
            if let last = segments.last, last.style == style {
                segments[segments.count - 1].text += piece
            } else {
                segments.append((style, piece))
            }
        }
        var result = AttributedString()
        for segment in segments {
            result += segment.style.apply(AttributedString(segment.text), palette: palette)
        }
        return result
    }

    /// Rozsah zobrazených znaků. Nekonečné režimy se zobrazují po pevných stránkách:
    /// text stojí, dokud nedopíšeš stránku, pak se celý vymění za další.
    private var visibleRange: Range<Int> {
        let count = engine.characters.count
        guard windowed, count > Self.windowLength else { return 0..<count }
        var start = 0
        while true {
            let end = pageEnd(from: start)
            if engine.position < end || end >= count { return start..<min(end, count) }
            start = end
        }
    }

    /// Konec stránky – zarovnaný za mezeru, ať se slovo neusekne. Závisí jen na textu před ním.
    private func pageEnd(from start: Int) -> Int {
        let count = engine.characters.count
        let limit = min(start + Self.windowLength, count)
        guard limit < count else { return count }
        var candidate = limit
        while candidate > start + Self.windowLength / 2, engine.characters[candidate - 1] != " " {
            candidate -= 1
        }
        return candidate > start + Self.windowLength / 2 ? candidate : limit
    }

    private enum Style: Equatable {
        case done
        case corrected
        case current
        case currentError
        case pending

        struct Palette {
            let highlight: Color
            let pending: Color
            /// Barva textu na plném bloku kurzoru.
            let inverse: Color
            let cursor: CursorStyle
        }

        /// Kurzor podle zvoleného stylu – jen barvy a čáry, nikdy jiná šířka znaku.
        static func cursor(_ text: inout AttributedString, color: Color, palette: Palette) {
            switch palette.cursor {
            case .underline:
                text.swiftUI.foregroundColor = color
                text.swiftUI.backgroundColor = color.opacity(0.18)
                text.swiftUI.underlineStyle = Text.LineStyle(pattern: .solid, color: color)
            case .highlight:
                text.swiftUI.foregroundColor = color
                text.swiftUI.backgroundColor = color.opacity(0.3)
            case .block:
                text.swiftUI.foregroundColor = palette.inverse
                text.swiftUI.backgroundColor = color
            case .dotted:
                text.swiftUI.foregroundColor = color
                text.swiftUI.underlineStyle = Text.LineStyle(pattern: .dot, color: color)
            }
        }

        func apply(_ text: AttributedString, palette: Palette) -> AttributedString {
            var text = text
            switch self {
            case .done:
                text.swiftUI.foregroundColor = palette.pending.opacity(0.4)
            case .corrected:
                text.swiftUI.foregroundColor = .orange
            case .current:
                Style.cursor(&text, color: palette.highlight, palette: palette)
            case .currentError:
                Style.cursor(&text, color: .red, palette: palette)
            case .pending:
                text.swiftUI.foregroundColor = palette.pending
            }
            return text
        }
    }
}
