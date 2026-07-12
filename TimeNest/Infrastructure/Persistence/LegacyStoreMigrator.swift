import Foundation
import OSLog
import SwiftData

@MainActor
enum LegacyStoreMigrator {
    static let appGroupIdentifier = WidgetSnapshotStore.appGroupIdentifier
    static let storeFileName = "TimeNest.store"
    static let markerFileName = ".legacy-store-migration-v1.complete"

    struct Preparation {
        let container: ModelContainer
        let outcome: Outcome
    }

    enum Outcome: Equatable {
        case legacyStoreMissing
        case alreadyCompleted
        case destinationHasData(eventCount: Int, reminderCount: Int)
        case migrated(eventCount: Int, reminderCount: Int)
        case failed

        var logSummary: String {
            switch self {
            case .legacyStoreMissing:
                "Legacy store is absent; no migration was needed."
            case .alreadyCompleted:
                "Legacy store migration already completed."
            case .destinationHasData(let eventCount, let reminderCount):
                "Current store already has data; legacy import was skipped (events: \(eventCount), reminders: \(reminderCount))."
            case .migrated(let eventCount, let reminderCount):
                "Legacy store migration completed (events: \(eventCount), reminders: \(reminderCount))."
            case .failed:
                "Legacy store migration failed; the legacy store was preserved and the current store remains available."
            }
        }
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "TimeNest",
        category: "LegacyStoreMigration"
    )

    static func destinationStoreURL(appGroupContainerURL: URL) -> URL {
        appGroupContainerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(storeFileName, isDirectory: false)
    }

    static func prepareModelContainer(
        schema: Schema,
        legacyStoreURL: URL,
        destinationStoreURL: URL,
        markerURL: URL,
        fileManager: FileManager = .default,
        beforeSave: (() throws -> Void)? = nil
    ) throws -> Preparation {
        let destinationExistedBeforeOpening = fileManager.fileExists(atPath: destinationStoreURL.path)
        let destinationConfiguration = ModelConfiguration(
            "TimeNest",
            schema: schema,
            url: destinationStoreURL,
            cloudKitDatabase: .none
        )
        let destinationContainer = try ModelContainer(
            for: schema,
            configurations: [destinationConfiguration]
        )

        let outcome: Outcome
        if destinationExistedBeforeOpening,
           fileManager.fileExists(atPath: markerURL.path) {
            outcome = .alreadyCompleted
        } else {
            outcome = migrateIfNeeded(
                schema: schema,
                legacyStoreURL: legacyStoreURL,
                destinationContainer: destinationContainer,
                destinationStoreURL: destinationStoreURL,
                markerURL: markerURL,
                fileManager: fileManager,
                beforeSave: beforeSave
            )
        }

        logger.notice("\(outcome.logSummary, privacy: .public)")
        return Preparation(container: destinationContainer, outcome: outcome)
    }

    private static func migrateIfNeeded(
        schema: Schema,
        legacyStoreURL: URL,
        destinationContainer: ModelContainer,
        destinationStoreURL: URL,
        markerURL: URL,
        fileManager: FileManager,
        beforeSave: (() throws -> Void)?
    ) -> Outcome {
        let destinationContext = ModelContext(destinationContainer)
        destinationContext.autosaveEnabled = false

        do {
            let destinationEvents = try destinationContext.fetch(
                FetchDescriptor<SwiftDataCalendarEventEntity>()
            )
            let destinationReminders = try destinationContext.fetch(
                FetchDescriptor<SwiftDataReminderEntity>()
            )
            if !destinationEvents.isEmpty || !destinationReminders.isEmpty {
                writeMarkerIfPossible(to: markerURL)
                return .destinationHasData(
                    eventCount: destinationEvents.count,
                    reminderCount: destinationReminders.count
                )
            }

            guard fileManager.fileExists(atPath: legacyStoreURL.path) else {
                return .legacyStoreMissing
            }

            let legacyConfiguration = ModelConfiguration(
                "TimeNest",
                schema: schema,
                url: legacyStoreURL,
                cloudKitDatabase: .none
            )
            let legacyContainer = try ModelContainer(
                for: schema,
                configurations: [legacyConfiguration]
            )
            let legacyContext = ModelContext(legacyContainer)
            legacyContext.autosaveEnabled = false
            let legacyEvents = try legacyContext.fetch(
                FetchDescriptor<SwiftDataCalendarEventEntity>()
            )
            let legacyReminders = try legacyContext.fetch(
                FetchDescriptor<SwiftDataReminderEntity>()
            )

            for entity in legacyEvents {
                destinationContext.insert(copyEvent(entity))
            }
            for entity in legacyReminders {
                destinationContext.insert(copyReminder(entity))
            }

            try beforeSave?()
            try destinationContext.save()

            let migratedEventCount = try destinationContext.fetch(
                FetchDescriptor<SwiftDataCalendarEventEntity>()
            ).count
            let migratedReminderCount = try destinationContext.fetch(
                FetchDescriptor<SwiftDataReminderEntity>()
            ).count
            guard migratedEventCount == legacyEvents.count,
                  migratedReminderCount == legacyReminders.count,
                  fileManager.fileExists(atPath: destinationStoreURL.path) else {
                throw MigrationError.validationFailed
            }

            writeMarkerIfPossible(to: markerURL)
            return .migrated(
                eventCount: migratedEventCount,
                reminderCount: migratedReminderCount
            )
        } catch {
            destinationContext.rollback()
            logger.error(
                "Legacy migration error type: \(String(reflecting: type(of: error)), privacy: .public)"
            )
            return .failed
        }
    }

    private static func writeMarkerIfPossible(to markerURL: URL) {
        do {
            try Data("completed".utf8).write(to: markerURL, options: .atomic)
        } catch {
            logger.error(
                "Legacy migration marker could not be written; destination data state will still prevent duplicate import."
            )
        }
    }

    private static func copyEvent(
        _ source: SwiftDataCalendarEventEntity
    ) -> SwiftDataCalendarEventEntity {
        let copy = SwiftDataCalendarEventEntity(
            id: source.id,
            title: source.title,
            startDate: source.startDate,
            endDate: source.endDate,
            isAllDay: source.isAllDay,
            recurrenceRuleRawValue: source.recurrenceRuleRawValue,
            createdAt: source.createdAt,
            updatedAt: source.updatedAt
        )
        copy.note = source.note
        copy.categoryID = source.categoryID
        copy.reminderTemplateID = source.reminderTemplateID
        copy.reminderOffsetMinutes = source.reminderOffsetMinutes
        copy.notificationID = source.notificationID
        copy.importSourceTypeRawValue = source.importSourceTypeRawValue
        copy.importExternalEventIdentifier = source.importExternalEventIdentifier
        copy.importExternalCalendarIdentifier = source.importExternalCalendarIdentifier
        copy.importExternalCalendarTitle = source.importExternalCalendarTitle
        copy.importedAt = source.importedAt
        copy.shiftTemplateKind = source.shiftTemplateKind
        copy.shiftTemplateCustomID = source.shiftTemplateCustomID
        copy.hasWorkInfo = source.hasWorkInfo
        copy.workInTime = source.workInTime
        copy.workOutTime = source.workOutTime
        copy.restHours = source.restHours
        copy.workDate = source.workDate
        copy.transportFee = source.transportFee
        copy.hourlyRate = source.hourlyRate
        copy.workSessionID = source.workSessionID
        copy.isWorkOutTimeSet = source.isWorkOutTimeSet
        return copy
    }

    private static func copyReminder(
        _ source: SwiftDataReminderEntity
    ) -> SwiftDataReminderEntity {
        let copy = SwiftDataReminderEntity(
            id: source.id,
            eventID: source.eventID,
            occurrenceID: source.occurrenceID,
            occurrenceStartDate: source.occurrenceStartDate,
            title: source.title,
            scheduledDate: source.scheduledDate,
            statusRawValue: source.statusRawValue,
            createdAt: source.createdAt,
            updatedAt: source.updatedAt
        )
        copy.message = source.message
        copy.systemNotificationID = source.systemNotificationID
        copy.alarmKitID = source.alarmKitID
        return copy
    }
}

private enum MigrationError: Error {
    case validationFailed
}
