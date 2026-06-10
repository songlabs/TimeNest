import Foundation

enum EventUseCaseError: Error, LocalizedError {
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return LocalizationManager.shared.localized(.editorInvalidDateRange)
        }
    }
}

class EventUseCase {
    private let repository: EventRepository
    private let notificationScheduler: LocalNotificationScheduling?

    init(
        repository: EventRepository,
        notificationScheduler: LocalNotificationScheduling? = nil
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
    }

    func createEvent(_ event: CalendarEvent) async throws {
        try validate(event)
        var eventToSave = event
        eventToSave.notificationID = await scheduledNotificationID(for: eventToSave)
        try await repository.create(eventToSave)
    }

    func updateEvent(_ event: CalendarEvent) async throws {
        try validate(event)
        let oldEvent = try await repository.event(id: event.id)
        if let oldNotificationID = oldEvent?.notificationID {
            notificationScheduler?.cancelNotification(id: oldNotificationID)
        }

        var eventToSave = event
        eventToSave.notificationID = await scheduledNotificationID(for: eventToSave)
        try await repository.update(eventToSave)
    }

    func deleteEvent(id: UUID) async throws {
        if let notificationID = try await repository.event(id: id)?.notificationID {
            notificationScheduler?.cancelNotification(id: notificationID)
        }
        try await repository.delete(id: id)
    }

    func events(in range: DateInterval) async throws -> [CalendarEvent] {
        try await repository.events(in: range)
    }

    func event(id: UUID) async throws -> CalendarEvent? {
        try await repository.event(id: id)
    }

    func occurrences(in range: DateInterval) async throws -> [EventOccurrence] {
        let events = try await repository.events(in: range)
        return events.map { event in
            EventOccurrence(
                id: "\(event.id)-\(event.startDate)",
                eventID: event.id,
                occurrenceDate: DateOnly(from: event.startDate) ?? DateOnly(year: 2026, month: 1, day: 1),
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                title: event.title,
                categoryID: event.categoryID,
                reminderOffsetMinutes: event.reminderOffsetMinutes,
                notificationID: event.notificationID
            )
        }
    }

    private func validate(_ event: CalendarEvent) throws {
        guard event.endDate > event.startDate else {
            throw EventUseCaseError.invalidDateRange
        }
    }

    private func scheduledNotificationID(for event: CalendarEvent) async -> String? {
        guard event.reminderOffsetMinutes != nil else {
            return nil
        }

        do {
            return try await notificationScheduler?.scheduleEventNotification(event: event)
        } catch {
            return nil
        }
    }
}
