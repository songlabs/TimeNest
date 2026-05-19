import Foundation

class ReminderUseCase {
    private let reminderRepository: ReminderRepository
    private let reminderScheduler: ReminderScheduling
    
    init(
        reminderRepository: ReminderRepository,
        reminderScheduler: ReminderScheduling
    ) {
        self.reminderRepository = reminderRepository
        self.reminderScheduler = reminderScheduler
    }
    
    func generateReminders(for event: CalendarEvent, occurrences: [EventOccurrence]) async throws -> [ScheduledReminder] {
        guard event.reminderTemplateID != nil else {
            return []
        }
        
        var reminders: [ScheduledReminder] = []
        for occurrence in occurrences {
            let reminder = ScheduledReminder(
                id: UUID(),
                eventID: event.id,
                occurrenceID: occurrence.id,
                occurrenceStartDate: occurrence.startDate,
                title: occurrence.title,
                message: nil,
                scheduledDate: occurrence.startDate,
                status: .pending,
                systemNotificationID: nil,
                alarmKitID: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            reminders.append(reminder)
        }
        
        return reminders
    }
    
    func scheduleReminders(for event: CalendarEvent) async throws {
    }
    
    func cancelReminders(for eventID: UUID) async throws {
        try await reminderRepository.deleteByEventID(eventID)
    }
}
