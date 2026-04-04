import Foundation

enum WatchFormatters {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale.current
        return f
    }()

    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    static func currencyString(_ value: Decimal) -> String {
        currency.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    static func timeString(_ date: Date) -> String {
        shortTime.string(from: date)
    }

    static func dateString(_ date: Date) -> String {
        shortDate.string(from: date)
    }

    static func durationString(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    static func milesString(_ miles: Double) -> String {
        String(format: "%.1f mi", miles)
    }

    static func milesString(_ miles: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: miles).doubleValue
        return String(format: "%.1f mi", doubleValue)
    }

    static func timeRangeString(start: Date?, end: Date?, duration: Int) -> String {
        if let start, let end {
            return "\(timeString(start)) – \(timeString(end))"
        } else if let start {
            let endDate = start.addingTimeInterval(TimeInterval(duration * 60))
            return "\(timeString(start)) – \(timeString(endDate))"
        }
        return durationString(minutes: duration)
    }
}
