import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    func scheduleBlockReminders(for block: Block, config: ReminderConfiguration) {
        let identifiers = identifiers(for: block.id)
        center.removePendingNotificationRequests(withIdentifiers: identifiers.allIdentifiers)

        let now = Date()
        let startDate = block.scheduledStartDate
        let endDate = block.scheduledEndDate
        guard endDate > now else { return }

        if config.startEnabled,
           let startAlert = Calendar.current.date(byAdding: .minute, value: -config.startMinutes, to: startDate),
           startAlert > now {
            schedule(
                id: identifiers.start,
                title: "Upcoming block",
                body: "\(config.startMinutes) minutes to block start — get ready to roll.",
                date: startAlert
            )
        }

        if config.preEndEnabled,
           let events = Calendar.current.date(byAdding: .minute, value: -config.preEndMinutes, to: endDate),
           events > now {
            schedule(
                id: identifiers.preEnd,
                title: "Block ending soon",
                body: "You have \(config.preEndMinutes) minutes until this block ends — wrap things up or pause tracking.",
                date: events
            )
        }

        if config.endEnabled {
            schedule(
                id: identifiers.end,
                title: "Block end reached",
                body: "Block scheduled end time arrived. Don’t forget to stop GPS tracking when you're finished.",
                date: endDate
            )
        }

        if config.tipEnabled && config.hasTips {
            let tipDate = Calendar.current.date(byAdding: .hour, value: config.tipHours, to: endDate)
            if let tipDate, tipDate > now {
                schedule(
                    id: identifiers.tip,
                    title: "\(config.tipHours)-hour tip reminder",
                    body: "It’s been \(config.tipHours) hour(s) since this block ended — enter any tips you earned for accurate tracking.",
                    date: tipDate
                )
            }
        }
    }

    func cancelReminders(for blockID: UUID) {
        let identifiers = identifiers(for: blockID)
        center.removePendingNotificationRequests(withIdentifiers: identifiers.allIdentifiers)
    }

    struct ReminderConfiguration {
        let startMinutes: Int
        let preEndMinutes: Int
        let tipHours: Int
        let startEnabled: Bool
        let preEndEnabled: Bool
        let endEnabled: Bool
        let tipEnabled: Bool
        let hasTips: Bool
    }

    private func schedule(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    private func identifiers(for blockID: UUID) -> NotificationIdentifiers {
        let base = "flexerrn.block.\(blockID.uuidString)"
        return NotificationIdentifiers(
            start: "\(base).start",
            preEnd: "\(base).pre",
            end: "\(base).end",
            tip: "\(base).tip"
        )
    }

    private struct NotificationIdentifiers {
        let start: String
        let preEnd: String
        let end: String
        let tip: String

        var allIdentifiers: [String] {
            [start, preEnd, end, tip]
        }
    }
}
