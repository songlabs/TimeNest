import Foundation

enum EventUseCaseError: Error, LocalizedError {
    case invalidDateRange
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return LocalizationManager.shared.localized(.editorInvalidDateRange)
        case .eventNotFound:
            return LocalizationManager.shared.localized(.eventNotFound)
        }
    }
}

class EventUseCase {
    private let repository: EventRepository
    private let notificationScheduler: LocalNotificationScheduling?
    var onEventsChanged: (() -> Void)?

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
        onEventsChanged?()
    }

    func updateEvent(_ event: CalendarEvent) async throws {
        try validate(event)
        guard let oldEvent = try await repository.event(id: event.id) else {
            throw EventUseCaseError.eventNotFound
        }
        if let oldNotificationID = oldEvent.notificationID {
            notificationScheduler?.cancelNotification(id: oldNotificationID)
        }

        var eventToSave = event
        eventToSave.notificationID = await scheduledNotificationID(for: eventToSave)
        try await repository.update(eventToSave)
        onEventsChanged?()
    }

    func deleteEvent(id: UUID) async throws {
        if let notificationID = try await repository.event(id: id)?.notificationID {
            notificationScheduler?.cancelNotification(id: notificationID)
        }
        try await repository.delete(id: id)
        onEventsChanged?()
    }

    func events(in range: DateInterval) async throws -> [CalendarEvent] {
        try await repository.events(in: range)
    }

    func event(id: UUID) async throws -> CalendarEvent? {
        try await repository.event(id: id)
    }

    func occurrences(in range: DateInterval) async throws -> [EventOccurrence] {
        let events = try await repository.events(in: range)
        let calendar = Calendar(identifier: .gregorian)

        return events.flatMap { event -> [EventOccurrence] in
            let isWorkClockEvent = event.workClockKind != nil

            if isWorkClockEvent {
                let occurrenceDate = event.workInfo?.workDate ?? event.startDate
                return [makeOccurrence(event: event, occurrenceDate: occurrenceDate)]
            }

            return coveredDates(for: event, in: range, calendar: calendar).map { occurrenceDate in
                makeOccurrence(event: event, occurrenceDate: occurrenceDate)
            }
        }
        .sorted { lhs, rhs in
            let leftDay = lhs.isWorkClockEvent ? calendar.startOfDay(for: lhs.workDate) : lhs.occurrenceDate.toDate()
            let rightDay = rhs.isWorkClockEvent ? calendar.startOfDay(for: rhs.workDate) : rhs.occurrenceDate.toDate()
            if leftDay != rightDay { return leftDay < rightDay }
            let leftSessionTime = lhs.isWorkClockEvent ? sessionSortTime(for: lhs) : lhs.startDate
            let rightSessionTime = rhs.isWorkClockEvent ? sessionSortTime(for: rhs) : rhs.startDate
            if leftSessionTime != rightSessionTime { return leftSessionTime < rightSessionTime }
            if lhs.isClockInEvent != rhs.isClockInEvent { return lhs.isClockInEvent }
            return lhs.actualWorkClockDate < rhs.actualWorkClockDate
        }
    }

    private func makeOccurrence(event: CalendarEvent, occurrenceDate: Date) -> EventOccurrence {
        let dateOnly = DateOnly(from: occurrenceDate) ?? DateOnly(year: 2026, month: 1, day: 1)
        return EventOccurrence(
            id: "\(event.id)-\(dateOnly.id)",
            eventID: event.id,
            occurrenceDate: dateOnly,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            title: event.title,
            note: event.note,
            categoryID: event.categoryID,
            reminderOffsetMinutes: event.reminderOffsetMinutes,
            notificationID: event.notificationID,
            shiftTemplateID: event.shiftTemplateID,
            workInfo: event.workInfo
        )
    }

    private func coveredDates(for event: CalendarEvent, in range: DateInterval, calendar: Calendar) -> [Date] {
        guard event.endDate > event.startDate else {
            guard event.startDate >= range.start, event.startDate < range.end else { return [] }
            return [calendar.startOfDay(for: event.startDate)]
        }

        let coveredStart = max(event.startDate, range.start)
        let coveredEnd = min(event.endDate, range.end)
        guard coveredEnd > coveredStart else { return [] }

        var dates: [Date] = []
        var date = calendar.startOfDay(for: coveredStart)
        while date < coveredEnd {
            dates.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date else {
                break
            }
            date = nextDate
        }
        return dates
    }

    private func sessionSortTime(for occurrence: EventOccurrence) -> Date {
        if occurrence.isClockInEvent {
            return occurrence.workInfo?.workInTime ?? occurrence.startDate
        }
        return occurrence.workInfo?.workInTime ?? occurrence.workInfo?.workOutTime ?? occurrence.startDate
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
