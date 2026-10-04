import Foundation

enum MojiWordSpan: Equatable, Sendable {
    case minutes(Int, isUpperBound: Bool)
    case hours(Double, isUpperBound: Bool)
    case days(Int)
    case months(Double)
    case years(Double)

    static let daysPerMonth = 30.0
    static let daysPerYear = 365.0

    init(_ delay: MojiWordDelay, collapseSeconds: Int = MojiWordDefaults.learnAheadSeconds) {
        switch delay {
        case .seconds(let seconds):
            let isUpperBound = seconds < collapseSeconds
            if seconds < 3_600 {
                self = .minutes(max(1, Int((Double(seconds) / 60).rounded())), isUpperBound: isUpperBound)
            } else {
                self = .hours(Self.tenths(Double(seconds) / 3_600), isUpperBound: isUpperBound)
            }
        case .days(let days):
            self.init(days: days)
        }
    }

    init(days: Int) {
        let value = Double(max(0, days))
        if value < Self.daysPerMonth {
            self = .days(max(0, days))
        } else if value < Self.daysPerYear {
            self = .months(Self.tenths(value / Self.daysPerMonth))
        } else {
            self = .years(Self.tenths(value / Self.daysPerYear))
        }
    }

    private static func tenths(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
