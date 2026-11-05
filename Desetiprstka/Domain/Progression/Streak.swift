import Foundation

/// Denní série (streak).
struct StreakState: Equatable, Sendable {
    var current: Int = 0
    var longest: Int = 0
    /// Poslední den s alespoň jedním plnohodnotným cvičením.
    var lastActiveDay: Date?
}

enum StreakTracker {
    /// Zaznamená aktivitu v daný den. Opakovaná aktivita ve stejný den nic nemění.
    static func register(activityOn date: Date, state: StreakState, calendar: Calendar = .current) -> StreakState {
        let today = calendar.startOfDay(for: date)
        var next = state

        if let last = state.lastActiveDay.map({ calendar.startOfDay(for: $0) }) {
            let days = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            switch days {
            case ..<1:
                return state
            case 1:
                next.current = state.current + 1
            default:
                next.current = 1
            }
        } else {
            next.current = 1
        }

        next.lastActiveDay = today
        next.longest = max(next.longest, next.current)
        return next
    }

    /// Série, kterou má smysl ukázat dnes (0, pokud už je přerušená).
    static func displayedStreak(_ state: StreakState, today: Date = .now, calendar: Calendar = .current) -> Int {
        guard let last = state.lastActiveDay else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last),
                                           to: calendar.startOfDay(for: today)).day ?? 0
        return days <= 1 ? state.current : 0
    }

    static func isActiveToday(_ state: StreakState, today: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let last = state.lastActiveDay else { return false }
        return calendar.isDate(last, inSameDayAs: today)
    }

    /// Série běží, ale dnes ještě nebylo cvičení.
    static func isAtRisk(_ state: StreakState, today: Date = .now, calendar: Calendar = .current) -> Bool {
        displayedStreak(state, today: today, calendar: calendar) > 0 && !isActiveToday(state, today: today, calendar: calendar)
    }

    /// Dopočítá sérii z historie (při prvním spuštění nové verze).
    static func rebuild(from dates: [Date], calendar: Calendar = .current) -> StreakState {
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
        var state = StreakState()
        for day in days {
            state = register(activityOn: day, state: state, calendar: calendar)
        }
        return state
    }
}

/// Klíč dne ve formátu „2026-10-09“.
enum DayKey {
    static func string(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// Číslo dne – stabilní „seed“ pro denní výzvu.
    static func number(for date: Date, calendar: Calendar = .current) -> UInt64 {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let value = (components.year ?? 0) * 10_000 + (components.month ?? 0) * 100 + (components.day ?? 0)
        return UInt64(max(value, 0))
    }
}

/// Deterministický generátor náhodných čísel (SplitMix64).
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
