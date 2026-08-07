import Foundation

/// The production implementation is the same SwiftData actor that owns CalendarEvent rows.
/// This is intentionally one repository contract so a local owner edit and its cloud intent
/// cannot be committed independently.
protocol OwnerSharedEventMutationRepository: Sendable {
    func applyBatchWithOwnerSharedEventMutations(
        upserting events: [CalendarEvent],
        deleting eventsToDelete: [CalendarEvent],
        ifUnchanged expectedEvents: [CalendarEvent],
        mutations: [OwnerSharedEventMutation]
    ) async throws

    func ownerSharedEventMutations(
        calendarID: UUID
    ) async throws -> [OwnerSharedEventMutation]

    func saveOwnerSharedEventMutation(
        _ mutation: OwnerSharedEventMutation
    ) async throws
}
