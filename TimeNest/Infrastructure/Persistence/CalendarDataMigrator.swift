import Foundation
import SwiftData

enum CalendarDataMigrator {
    /// Version 2 introduces explicit calendar ownership for every local business row.
    static let currentVersion = 2

    struct Result: Equatable {
        let createdPersonalCalendar: Bool
        let migratedEventCount: Int
    }

    @MainActor
    static func migrate(
        container: ModelContainer,
        personalCalendarName: String
    ) throws -> Result {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let personalID = TimeNestCalendar.personalID
        let personalDescriptor = FetchDescriptor<SwiftDataCalendarEntity>(
            predicate: #Predicate { $0.id == personalID }
        )
        let createdPersonalCalendar: Bool
        if try context.fetch(personalDescriptor).first == nil {
            let now = Date()
            context.insert(
                SwiftDataCalendarEntity(
                    id: personalID,
                    name: personalCalendarName,
                    kindRawValue: TimeNestCalendarKind.personal.rawValue,
                    createdAt: now,
                    updatedAt: now
                )
            )
            createdPersonalCalendar = true
        } else {
            createdPersonalCalendar = false
        }

        let legacyDescriptor = FetchDescriptor<SwiftDataCalendarEventEntity>(
            predicate: #Predicate { $0.calendarID == nil }
        )
        let legacyEvents = try context.fetch(legacyDescriptor)
        legacyEvents.forEach { $0.calendarID = personalID }

        if createdPersonalCalendar || !legacyEvents.isEmpty {
            try context.save()
        }
        return Result(
            createdPersonalCalendar: createdPersonalCalendar,
            migratedEventCount: legacyEvents.count
        )
    }
}
