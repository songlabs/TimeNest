import Foundation

protocol CalendarRepository: Sendable {
    func calendars() async throws -> [TimeNestCalendar]
    func calendar(id: UUID) async throws -> TimeNestCalendar?
    func save(_ calendar: TimeNestCalendar) async throws
    func delete(id: UUID) async throws
}
