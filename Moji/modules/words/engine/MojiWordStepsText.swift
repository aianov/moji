import Foundation

enum MojiWordStepsText {
    static func parse(_ text: String) -> [Double]? {
        let pieces = text
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == ";" })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",.")) }
            .filter { !$0.isEmpty }
        guard !pieces.isEmpty else { return [] }
        var steps: [Double] = []
        for piece in pieces {
            guard let minutes = minutes(piece) else { return nil }
            steps.append(minutes)
        }
        return steps
    }

    static func format(_ steps: [Double]) -> String {
        steps.map(format).joined(separator: " ")
    }

    static func format(_ minutes: Double) -> String {
        let seconds = Int((minutes * 60).rounded())
        if seconds % 86_400 == 0 {
            return "\(seconds / 86_400)d"
        }
        if seconds % 3_600 == 0 {
            return "\(seconds / 3_600)h"
        }
        if seconds % 60 == 0 {
            return "\(seconds / 60)m"
        }
        return "\(seconds)s"
    }

    private static func minutes(_ piece: String) -> Double? {
        let units: [(String, Double)] = [
            ("мин", 1), ("min", 1), ("сек", 1.0 / 60), ("м", 1), ("ч", 60), ("д", 1_440),
            ("s", 1.0 / 60), ("m", 1), ("h", 60), ("d", 1_440)
        ]
        var number = piece
        var factor = 1.0
        for (suffix, value) in units where piece.hasSuffix(suffix) {
            number = String(piece.dropLast(suffix.count))
            factor = value
            break
        }
        guard let value = Double(number.replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0 else {
            return nil
        }
        let minutes = value * factor
        guard minutes >= 1.0 / 60, minutes <= MojiWordDefaults.maximumStepMinutes else { return nil }
        return minutes
    }
}
