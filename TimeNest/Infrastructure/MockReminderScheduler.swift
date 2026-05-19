import Foundation

actor MockReminderScheduler: ReminderScheduling {
    func schedule(_ reminder: ScheduledReminder) async throws {
    }
    
    func cancel(for reminderID: UUID) async throws {
    }
}
