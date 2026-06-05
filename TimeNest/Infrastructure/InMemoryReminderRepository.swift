import Foundation

actor InMemoryReminderRepository: ReminderRepository {
    static let shared = InMemoryReminderRepository()
    
    private var reminders: [UUID: ScheduledReminder] = [:]

    func save(_ reminder: ScheduledReminder) async throws {
        reminders[reminder.id] = reminder
    }
    
    func reminders(for eventID: UUID) async throws -> [ScheduledReminder] {
        reminders.values.filter { $0.eventID == eventID }.sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    func reminders(in range: DateInterval) async throws -> [ScheduledReminder] {
        reminders.values.filter {
            $0.scheduledDate >= range.start && $0.scheduledDate <= range.end
        }.sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    func deleteByEventID(_ eventID: UUID) async throws {
        reminders = reminders.filter { $0.value.eventID != eventID }
    }
}
