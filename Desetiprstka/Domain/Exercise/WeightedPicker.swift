import Foundation

/// Náhodný výběr s vahami – prvky s vyšší vahou padají častěji.
enum WeightedPicker {
    static func pick<T, G: RandomNumberGenerator>(
        _ items: [T],
        weights: [Double],
        using rng: inout G
    ) -> T? {
        guard !items.isEmpty, items.count == weights.count else { return items.randomElement(using: &rng) }
        let total = weights.reduce(0) { $0 + max($1, 0) }
        guard total > 0 else { return items.randomElement(using: &rng) }

        var roll = Double.random(in: 0..<total, using: &rng)
        for (item, weight) in zip(items, weights) {
            let weight = max(weight, 0)
            if roll < weight { return item }
            roll -= weight
        }
        return items.last
    }

    static func pick<T, G: RandomNumberGenerator>(
        _ items: [T],
        using rng: inout G,
        weight: (T) -> Double
    ) -> T? {
        pick(items, weights: items.map(weight), using: &rng)
    }
}
