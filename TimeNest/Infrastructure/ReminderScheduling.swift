import Foundation
import UserNotifications

protocol ReminderScheduling {
    func schedule(_ reminder: ScheduledReminder) async throws
    func cancel(for reminderID: UUID) async throws
}

protocol LocalNotificationScheduling {
    func requestAuthorizationIfNeeded() async -> Bool
    func scheduleEventNotification(event: CalendarEvent) async throws -> String?
    func cancelNotification(id: String)
    func scheduleDailyScheduleCheck(hour: Int, minute: Int) async
    func cancelDailyScheduleCheck()
}

final class LocalNotificationService: LocalNotificationScheduling {
    static let dailyScheduleCheckIdentifier = "TimeNest.dailyScheduleCheck"

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.center = center
        self.calendar = calendar
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func scheduleEventNotification(event: CalendarEvent) async throws -> String? {
        guard let reminderOffsetMinutes = event.reminderOffsetMinutes else {
            return nil
        }

        let triggerDate = event.startDate.addingTimeInterval(TimeInterval(-reminderOffsetMinutes * 60))
        guard triggerDate > Date() else {
            return nil
        }

        guard await requestAuthorizationIfNeeded() else {
            return nil
        }

        let notificationID = event.notificationID ?? UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = notificationBody(for: event)
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        try await center.add(request)
        return notificationID
    }

    func cancelNotification(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    func scheduleDailyScheduleCheck(hour: Int, minute: Int) async {
        guard await requestAuthorizationIfNeeded() else {
            return
        }

        cancelDailyScheduleCheck()

        let content = UNMutableNotificationContent()
        content.title = "TimeNest"
        content.body = LocalizationManager.shared.localized(.notificationDailyScheduleCheck)
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyScheduleCheckIdentifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    func cancelDailyScheduleCheck() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyScheduleCheckIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.dailyScheduleCheckIdentifier])
    }

    private func notificationBody(for event: CalendarEvent) -> String {
        if event.isAllDay {
            return LocalizationManager.shared.localized(.notificationEventStartingSoon)
        }

        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: event.startDate)
    }
}
