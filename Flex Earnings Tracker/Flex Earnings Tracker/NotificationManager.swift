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

    func scheduleBlockReminders(for block: Block) {
        let identifiers = pendingIdentifiers(for: block)
        center.removePendingNotificationRequests(withIdentifiers: [identifiers.preAlert, identifiers.finalAlert])

        let now = Date()
        let endDate = block.scheduledEndDate
        guard endDate > now else { return }

        if let preEndDate = Calendar.current.date(byAdding: .minute, value: -15, to: endDate),
           preEndDate > now {
            schedule(
                id: identifiers.preAlert,
                title: "15 minutes to block end",
                body: "Your block ends soon—stop mileage tracking after you wrap up to keep everything tidy.",
                date: preEndDate
            )
        }

        schedule(
            id: identifiers.finalAlert,
            title: "Block end reached",
            body: "Block scheduled end time arrived. Don’t forget to stop GPS tracking if you’re done.",
            date: endDate
        )
    }

    func cancelReminders(for blockID: UUID) {
        let identifiers = identifiers(for: blockID)
        center.removePendingNotificationRequests(withIdentifiers: [identifiers.preAlert, identifiers.finalAlert])
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

    private func pendingIdentifiers(for block: Block) -> (preAlert: String, finalAlert: String) {
        identifiers(for: block.id)
    }

    private func identifiers(for blockID: UUID) -> (preAlert: String, finalAlert: String) {
        let base = "flexerrn.block.\(blockID.uuidString)"
        return (preAlert: "\(base).pre", finalAlert: "\(base).final")
    }
}
