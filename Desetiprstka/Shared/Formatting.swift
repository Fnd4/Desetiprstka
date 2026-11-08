import Foundation

/// Jednotné formátování čísel v celé aplikaci.
enum Format {
    static func wpm(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    /// Desetinné číslo s českou čárkou (0,25).
    static func decimal(_ value: Double, digits: Int = 2) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)).locale(.autoupdatingCurrent))
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Celé číslo s oddělovači tisíců (10 000).
    static func number(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number.locale(.autoupdatingCurrent))
    }

    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(.autoupdatingCurrent))
    }

    /// Reakční doba v milisekundách.
    static func milliseconds(_ seconds: Double) -> String {
        "\(Int((seconds * 1000).rounded())) ms"
    }

    /// Delší doba jako „2 h 15 min“.
    static func longDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    /// „1 den“, „3 dny“, „7 dní“.
    static func days(_ count: Int) -> String {
        switch count {
        case 1: "1 den"
        case 2...4: "\(count) dny"
        default: "\(count) dní"
        }
    }

    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}
