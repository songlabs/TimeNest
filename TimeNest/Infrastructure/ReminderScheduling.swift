import Foundation
import UserNotifications

protocol ReminderScheduling {
    func schedule(_ reminder: ScheduledReminder) async throws
    func cancel(for reminderID: UUID) async throws
}

protocol LocalNotificationScheduling {
    func requestAuthorizationOnFirstLaunchIfNeeded() async
    func requestAuthorizationIfNeeded() async -> Bool
    func scheduleEventNotification(event: CalendarEvent) async throws -> String?
    func scheduleEventNotificationResult(event: CalendarEvent) async -> EventNotificationScheduleResult
    func cancelNotification(id: String)
    func scheduleDailyScheduleCheck(hour: Int, minute: Int) async
    func cancelDailyScheduleCheck()
}

struct EventNotificationScheduleFailure: Error, LocalizedError, Equatable {
    let underlyingError: Error

    var errorDescription: String? {
        underlyingError.localizedDescription
    }

    static func == (
        lhs: EventNotificationScheduleFailure,
        rhs: EventNotificationScheduleFailure
    ) -> Bool {
        let lhsError = lhs.underlyingError as NSError
        let rhsError = rhs.underlyingError as NSError
        return String(reflecting: type(of: lhs.underlyingError))
                == String(reflecting: type(of: rhs.underlyingError))
            && lhsError.domain == rhsError.domain
            && lhsError.code == rhsError.code
            && lhsError.localizedDescription == rhsError.localizedDescription
    }
}

enum EventNotificationScheduleResult: Equatable {
    case scheduled(String)
    case noReminder
    case triggerDateInPast
    case denied
    case failed
    case failedWithCause(EventNotificationScheduleFailure)

    var notificationID: String? {
        if case .scheduled(let id) = self {
            return id
        }
        return nil
    }
}

private enum LocalNotificationAuthorizationResult: Equatable {
    case authorized
    case denied
    case failed(EventNotificationScheduleFailure)
}

extension LocalNotificationScheduling {
    func requestAuthorizationOnFirstLaunchIfNeeded() async {
        _ = await requestAuthorizationIfNeeded()
    }

    func scheduleEventNotificationResult(event: CalendarEvent) async -> EventNotificationScheduleResult {
        guard event.reminderOffsetMinutes != nil else {
            return .noReminder
        }

        do {
            if let notificationID = try await scheduleEventNotification(event: event) {
                return .scheduled(notificationID)
            }
            return .failed
        } catch {
            return .failedWithCause(
                EventNotificationScheduleFailure(underlyingError: error)
            )
        }
    }
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

    func requestAuthorizationOnFirstLaunchIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return
        }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return
        }
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        return await authorizationResultRequestingIfNeeded() == .authorized
    }

    func scheduleEventNotification(event: CalendarEvent) async throws -> String? {
        let result = await scheduleEventNotificationResult(event: event)
        if case .failedWithCause(let failure) = result {
            throw failure.underlyingError
        }
        return result.notificationID
    }

    func scheduleEventNotificationResult(event: CalendarEvent) async -> EventNotificationScheduleResult {
        guard let reminderOffsetMinutes = event.reminderOffsetMinutes else {
            return .noReminder
        }

        let triggerDate = event.startDate.addingTimeInterval(TimeInterval(-reminderOffsetMinutes * 60))
        guard triggerDate > Date() else {
            return .triggerDateInPast
        }

        switch await authorizationResultRequestingIfNeeded() {
        case .authorized:
            return await addEventNotification(event: event, triggerDate: triggerDate)
        case .denied:
            return .denied
        case .failed(let failure):
            return .failedWithCause(failure)
        }
    }

    private func authorizationResultRequestingIfNeeded() async -> LocalNotificationAuthorizationResult {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge]) ? .authorized : .denied
            } catch {
                return .failed(
                    EventNotificationScheduleFailure(underlyingError: error)
                )
            }
        @unknown default:
            return .failed(
                EventNotificationScheduleFailure(
                    underlyingError: LocalNotificationSchedulingError.unknownAuthorizationStatus
                )
            )
        }
    }

    private func addEventNotification(event: CalendarEvent, triggerDate: Date) async -> EventNotificationScheduleResult {
        let notificationID = event.notificationID ?? UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = notificationBody(for: event)
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return .scheduled(notificationID)
        } catch {
            return .failedWithCause(
                EventNotificationScheduleFailure(underlyingError: error)
            )
        }
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

        return LocalizationManager.shared.dateFormatter(dateFormat: "HH:mm").string(from: event.startDate)
    }
}

private enum LocalNotificationSchedulingError: Error {
    case unknownAuthorizationStatus
}
