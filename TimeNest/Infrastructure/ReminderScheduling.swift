import Foundation

protocol ReminderScheduling {
    func schedule(_ reminder: ScheduledReminder) async throws
    func cancel(for reminderID: UUID) async throws
}
