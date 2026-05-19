import Foundation

protocol ExternalCalendarImporting {
    func requestAccess() async throws -> Bool
    func fetchEvents(in range: DateInterval) async throws -> [CalendarEvent]
}
