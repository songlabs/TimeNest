import Foundation

protocol ReminderRepository {
    func save(_ reminder: ScheduledReminder) async throws
    func reminders(for eventID: UUID) async throws -> [ScheduledReminder]
    func reminders(in range: DateInterval) async throws -> [ScheduledReminder]
    func deleteByEventID(_ eventID: UUID) async throws
}
