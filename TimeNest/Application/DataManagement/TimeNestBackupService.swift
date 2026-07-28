import Foundation
import SwiftData
import UserNotifications

enum TimeNestBackupError: Error, Equatable {
    case invalidAppIdentifier
    case unsupportedFormatVersion(Int)
    case duplicateCalendarID
    case duplicateEventID
    case missingCalendarRelationship
    case invalidEventDateRange
    case invalidRecurrenceRule
    case invalidWorkInfo
    case invalidSettings
}

struct TimeNestBackupDocument: Codable, Equatable {
    static let currentFormatVersion = 1
    static let appIdentifier = "TimeNest"

    let formatVersion: Int
    let appIdentifier: String
    let createdAt: Date
    let appVersion: String
    let data: TimeNestBackupData

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> TimeNestBackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(TimeNestBackupDocument.self, from: data)
        try TimeNestBackupValidator.validate(document)
        return document
    }
}

struct TimeNestBackupData: Codable, Equatable {
    let calendars: [TimeNestBackupCalendar]
    let events: [TimeNestBackupEvent]
    let shifts: [TimeNestBackupEvent]
    let workRecords: [TimeNestBackupEvent]
    let settings: TimeNestBackupSettings

    var allEvents: [TimeNestBackupEvent] {
        events + shifts + workRecords
    }
}

struct TimeNestBackupCalendar: Codable, Equatable {
    enum SourceKind: String, Codable {
        case personal
        case sharedOwned
    }

    let id: UUID
    let name: String
    let sourceKind: SourceKind
    let createdAt: Date
    let updatedAt: Date
}

struct TimeNestBackupEvent: Codable, Equatable {
    struct ImportSourcePayload: Codable, Equatable {
        let sourceType: String
        let externalEventIdentifier: String?
        let externalCalendarIdentifier: String?
        let externalCalendarTitle: String?
        let importedAt: Date
    }

    struct ShiftTemplatePayload: Codable, Equatable {
        let kind: String
        let customID: UUID?
    }

    struct WorkInfoPayload: Codable, Equatable {
        let workInTime: Date?
        let workOutTime: Date?
        let restHours: Double
        let workDate: Date?
        let transportFee: Int?
        let hourlyRate: Int?
        let workSessionID: UUID?
        let isWorkOutTimeSet: Bool
    }

    let id: UUID
    let calendarID: UUID
    let title: String
    let note: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let categoryID: UUID?
    let recurrenceRule: String
    let reminderTemplateID: UUID?
    let reminderOffsetMinutes: Int?
    let importSource: ImportSourcePayload?
    let createdAt: Date
    let updatedAt: Date
    let shiftTemplate: ShiftTemplatePayload?
    let workInfo: WorkInfoPayload?

    init(event: CalendarEvent) {
        id = event.id
        calendarID = event.calendarID
        title = event.title
        note = event.note
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        categoryID = event.categoryID
        recurrenceRule = event.recurrenceRule.rawValue
        reminderTemplateID = event.reminderTemplateID
        reminderOffsetMinutes = event.reminderOffsetMinutes
        importSource = event.importSource.map {
            ImportSourcePayload(
                sourceType: $0.sourceType.rawValue,
                externalEventIdentifier: $0.externalEventIdentifier,
                externalCalendarIdentifier: $0.externalCalendarIdentifier,
                externalCalendarTitle: $0.externalCalendarTitle,
                importedAt: $0.importedAt
            )
        }
        createdAt = event.createdAt
        updatedAt = event.updatedAt
        switch event.shiftTemplateID {
        case .day:
            shiftTemplate = ShiftTemplatePayload(kind: "day", customID: nil)
        case .night:
            shiftTemplate = ShiftTemplatePayload(kind: "night", customID: nil)
        case .custom(let id):
            shiftTemplate = ShiftTemplatePayload(kind: "custom", customID: id)
        case nil:
            shiftTemplate = nil
        }
        workInfo = event.workInfo.map {
            WorkInfoPayload(
                workInTime: $0.workInTime,
                workOutTime: $0.workOutTime,
                restHours: $0.restHours,
                workDate: $0.workDate,
                transportFee: $0.transportFee,
                hourlyRate: $0.hourlyRate,
                workSessionID: $0.workSessionId,
                isWorkOutTimeSet: $0.isWorkOutTimeSet
            )
        }
    }

    func restoredEvent(calendarID: UUID) -> CalendarEvent {
        CalendarEvent(
            id: id,
            calendarID: calendarID,
            title: title,
            note: note,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            categoryID: categoryID,
            recurrenceRule: RecurrenceRule(rawValue: recurrenceRule) ?? .none,
            reminderTemplateID: reminderTemplateID,
            reminderOffsetMinutes: reminderOffsetMinutes,
            notificationID: nil,
            importSource: restoredImportSource,
            createdAt: createdAt,
            updatedAt: updatedAt,
            shiftTemplateID: restoredShiftTemplateID,
            workInfo: workInfo.map {
                WorkInfo(
                    workInTime: $0.workInTime,
                    workOutTime: $0.workOutTime,
                    restHours: $0.restHours,
                    workDate: $0.workDate,
                    transportFee: $0.transportFee,
                    hourlyRate: $0.hourlyRate,
                    workSessionId: $0.workSessionID,
                    isWorkOutTimeSet: $0.isWorkOutTimeSet
                )
            }
        )
    }

    private var restoredImportSource: ImportSource? {
        guard let importSource,
              let sourceType = ImportSourceType(rawValue: importSource.sourceType) else {
            return nil
        }
        return ImportSource(
            sourceType: sourceType,
            externalEventIdentifier: importSource.externalEventIdentifier,
            externalCalendarIdentifier: importSource.externalCalendarIdentifier,
            externalCalendarTitle: importSource.externalCalendarTitle,
            importedAt: importSource.importedAt
        )
    }

    private var restoredShiftTemplateID: ShiftTimeTemplateID? {
        switch shiftTemplate?.kind {
        case "day":
            return .day
        case "night":
            return .night
        case "custom":
            return shiftTemplate?.customID.map(ShiftTimeTemplateID.custom)
        default:
            return nil
        }
    }
}

struct TimeNestBackupSettings: Codable, Equatable {
    struct ShiftTemplate: Codable, Equatable {
        let kind: String
        let customID: UUID?
        let displayName: String
        let note: String
        let colorHex: String
        let startTime: String
        let endTime: String
        let enabled: Bool
        let usesLocalizedDefaultName: Bool
    }

    struct HolidaySubscriptionSetting: Codable, Equatable {
        let id: UUID
        let region: String
        let urlString: String
        let isEnabled: Bool
    }

    let weekStart: String?
    let themeMode: String?
    let languageCode: String?
    let eventBackgroundColorHex: String?
    let workRecordBackgroundColorHex: String?
    let shiftTemplates: [ShiftTemplate]
    let holidaySubscriptions: [HolidaySubscriptionSetting]

    static func capture(from defaults: UserDefaults) -> TimeNestBackupSettings {
        TimeNestBackupSettings(
            weekStart: defaults.string(forKey: "weekStart"),
            themeMode: defaults.string(forKey: "themeMode"),
            languageCode: defaults.string(forKey: "preferredLanguageCode"),
            eventBackgroundColorHex: defaults.string(
                forKey: CalendarItemColorSettings.eventBackgroundColorKey
            ),
            workRecordBackgroundColorHex: defaults.string(
                forKey: CalendarItemColorSettings.workRecordBackgroundColorKey
            ),
            shiftTemplates: ShiftTimeTemplate.all(from: defaults).map { template in
                let kind: String
                let customID: UUID?
                switch template.id {
                case .day:
                    kind = "day"
                    customID = nil
                case .night:
                    kind = "night"
                    customID = nil
                case .custom(let id):
                    kind = "custom"
                    customID = id
                }
                return ShiftTemplate(
                    kind: kind,
                    customID: customID,
                    displayName: template.displayName,
                    note: template.note,
                    colorHex: template.colorHex,
                    startTime: template.startTime,
                    endTime: template.endTime,
                    enabled: template.enabled,
                    usesLocalizedDefaultName: template.usesLocalizedDefaultName
                )
            },
            holidaySubscriptions: capturedHolidaySubscriptions(from: defaults)
        )
    }

    func restore(to defaults: UserDefaults) {
        set(weekStart, forKey: "weekStart", defaults: defaults)
        set(themeMode, forKey: "themeMode", defaults: defaults)
        set(languageCode, forKey: "preferredLanguageCode", defaults: defaults)
        set(
            eventBackgroundColorHex,
            forKey: CalendarItemColorSettings.eventBackgroundColorKey,
            defaults: defaults
        )
        set(
            workRecordBackgroundColorHex,
            forKey: CalendarItemColorSettings.workRecordBackgroundColorKey,
            defaults: defaults
        )

        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("shiftTime.") || key.hasPrefix("shiftTemplate.deleted.") {
            defaults.removeObject(forKey: key)
        }

        let restoredKinds = Set(shiftTemplates.map(\.kind))
        if !restoredKinds.contains("day") {
            defaults.set(true, forKey: "shiftTemplate.deleted.day")
        }
        if !restoredKinds.contains("night") {
            defaults.set(true, forKey: "shiftTemplate.deleted.night")
        }

        for template in shiftTemplates {
            guard let id = templateID(for: template) else { continue }
            if case .custom(let uuid) = id {
                defaults.set(uuid.uuidString, forKey: id.uuidStorageKey)
            }
            if !template.usesLocalizedDefaultName || template.kind == "custom" {
                defaults.set(template.displayName, forKey: id.displayNameKey)
                defaults.set(true, forKey: id.displayNameCustomizedKey)
            }
            defaults.set(template.note, forKey: id.noteKey)
            defaults.set(template.colorHex, forKey: id.colorHexKey)
            defaults.set(template.startTime, forKey: id.startTimeKey)
            defaults.set(template.endTime, forKey: id.endTimeKey)
            defaults.set(template.enabled, forKey: id.enabledKey)
        }

        let subscriptions = holidaySubscriptions.compactMap { item -> HolidaySubscription? in
            guard let region = HolidayRegion(rawValue: item.region) else { return nil }
            return HolidaySubscription(
                id: item.id,
                region: region,
                displayNameKey: region.localizedKey,
                urlString: item.urlString,
                isEnabled: item.isEnabled,
                lastUpdatedAt: nil,
                syncStatus: .neverSynced,
                errorMessage: nil
            )
        }
        if let data = try? JSONEncoder().encode(subscriptions),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: "holidaySubscriptions")
        }
    }

    private func templateID(for template: ShiftTemplate) -> ShiftTimeTemplateID? {
        switch template.kind {
        case "day":
            return .day
        case "night":
            return .night
        case "custom":
            return template.customID.map(ShiftTimeTemplateID.custom)
        default:
            return nil
        }
    }

    private func set(_ value: String?, forKey key: String, defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func capturedHolidaySubscriptions(
        from defaults: UserDefaults
    ) -> [HolidaySubscriptionSetting] {
        guard let json = defaults.string(forKey: "holidaySubscriptions"),
              let data = json.data(using: .utf8),
              let subscriptions = try? JSONDecoder().decode(
                [HolidaySubscription].self,
                from: data
              ) else {
            return []
        }
        return subscriptions.map {
            HolidaySubscriptionSetting(
                id: $0.id,
                region: $0.region.rawValue,
                urlString: $0.urlString,
                isEnabled: $0.isEnabled
            )
        }
    }
}

enum TimeNestBackupValidator {
    static func validate(_ document: TimeNestBackupDocument) throws {
        guard document.appIdentifier == TimeNestBackupDocument.appIdentifier else {
            throw TimeNestBackupError.invalidAppIdentifier
        }
        guard document.formatVersion == TimeNestBackupDocument.currentFormatVersion else {
            throw TimeNestBackupError.unsupportedFormatVersion(document.formatVersion)
        }

        let calendarIDs = document.data.calendars.map(\.id)
        guard Set(calendarIDs).count == calendarIDs.count else {
            throw TimeNestBackupError.duplicateCalendarID
        }
        let eventIDs = document.data.allEvents.map(\.id)
        guard Set(eventIDs).count == eventIDs.count else {
            throw TimeNestBackupError.duplicateEventID
        }
        let calendarIDSet = Set(calendarIDs)
        for event in document.data.allEvents {
            guard calendarIDSet.contains(event.calendarID) else {
                throw TimeNestBackupError.missingCalendarRelationship
            }
            guard event.endDate >= event.startDate else {
                throw TimeNestBackupError.invalidEventDateRange
            }
            guard RecurrenceRule(rawValue: event.recurrenceRule) != nil else {
                throw TimeNestBackupError.invalidRecurrenceRule
            }
            if let workInfo = event.workInfo,
               !workInfo.restHours.isFinite || workInfo.restHours < 0 {
                throw TimeNestBackupError.invalidWorkInfo
            }
        }

        let subscriptions = document.data.settings.holidaySubscriptions
        guard Set(subscriptions.map(\.id)).count == subscriptions.count,
              Set(subscriptions.map(\.region)).count == subscriptions.count,
              subscriptions.allSatisfy({ HolidayRegion(rawValue: $0.region) != nil }) else {
            throw TimeNestBackupError.invalidSettings
        }
    }
}

@MainActor
struct TimeNestRestoreNotificationSummary: Equatable {
    var scheduledCount = 0
    var pastEventCount = 0
    var expiredReminderCount = 0
    var deniedCount = 0
    var failedCount = 0

    var hasWarnings: Bool {
        deniedCount > 0 || failedCount > 0
    }
}

@MainActor
struct TimeNestBackupService {
    let modelContext: ModelContext
    let defaults: UserDefaults
    var beforeSaveForTesting: (() throws -> Void)?
    private let notificationCleaner: ([String]) -> Void
    private let notificationScheduler: any LocalNotificationScheduling
    private let now: () -> Date

    init(
        modelContext: ModelContext,
        defaults: UserDefaults = .standard,
        beforeSaveForTesting: (() throws -> Void)? = nil,
        notificationCleaner: (([String]) -> Void)? = nil,
        notificationScheduler: any LocalNotificationScheduling = LocalNotificationService(),
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.defaults = defaults
        self.beforeSaveForTesting = beforeSaveForTesting
        self.notificationCleaner = notificationCleaner ?? { identifiers in
            guard !identifiers.isEmpty else { return }
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
        self.notificationScheduler = notificationScheduler
        self.now = now
    }

    func makeDocument(
        createdAt: Date = Date(),
        appVersion: String
    ) throws -> TimeNestBackupDocument {
        let calendarEntities = try modelContext.fetch(
            FetchDescriptor<SwiftDataCalendarEntity>(sortBy: [SortDescriptor(\.createdAt)])
        )
        var calendars = calendarEntities.compactMap { entity -> TimeNestBackupCalendar? in
            guard let kind = TimeNestCalendarKind(rawValue: entity.kindRawValue),
                  kind != .sharedReceived else {
                return nil
            }
            return TimeNestBackupCalendar(
                id: entity.id,
                name: entity.name,
                sourceKind: kind == .sharedOwned ? .sharedOwned : .personal,
                createdAt: entity.createdAt,
                updatedAt: entity.updatedAt
            )
        }
        if !calendars.contains(where: { $0.id == TimeNestCalendar.personalID }) {
            calendars.append(
                TimeNestBackupCalendar(
                    id: TimeNestCalendar.personalID,
                    name: LocalizationManager.shared.localized(.calendarSharingMyCalendar),
                    sourceKind: .personal,
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
            )
        }

        let receivedCalendarIDs = Set(
            calendarEntities.compactMap { entity in
                TimeNestCalendarKind(rawValue: entity.kindRawValue) == .sharedReceived
                    ? entity.id
                    : nil
            }
        )
        let allEvents = try modelContext.fetch(
            FetchDescriptor<SwiftDataCalendarEventEntity>(sortBy: [SortDescriptor(\.startDate)])
        )
        .map(SwiftDataEventMapper.makeDomainModel)
        .filter { !receivedCalendarIDs.contains($0.calendarID) }

        let ordinaryEvents = allEvents.filter {
            $0.shiftTemplateID == nil && $0.workClockKind == nil
        }
        let shifts = allEvents.filter { $0.shiftTemplateID != nil }
        let workRecords = allEvents.filter {
            $0.shiftTemplateID == nil && $0.workClockKind != nil
        }

        let document = TimeNestBackupDocument(
            formatVersion: TimeNestBackupDocument.currentFormatVersion,
            appIdentifier: TimeNestBackupDocument.appIdentifier,
            createdAt: createdAt,
            appVersion: appVersion,
            data: TimeNestBackupData(
                calendars: calendars,
                events: ordinaryEvents.map(TimeNestBackupEvent.init(event:)),
                shifts: shifts.map(TimeNestBackupEvent.init(event:)),
                workRecords: workRecords.map(TimeNestBackupEvent.init(event:)),
                settings: TimeNestBackupSettings.capture(from: defaults)
            )
        )
        try TimeNestBackupValidator.validate(document)
        return document
    }

    func restore(
        _ document: TimeNestBackupDocument
    ) async throws -> TimeNestRestoreNotificationSummary {
        try TimeNestBackupValidator.validate(document)
        _ = try makeDocument(appVersion: document.appVersion)
        var supersededNotificationIDs = Set<String>()

        do {
            for reminder in try modelContext.fetch(FetchDescriptor<SwiftDataReminderEntity>()) {
                if let identifier = reminder.systemNotificationID {
                    supersededNotificationIDs.insert(identifier)
                }
                modelContext.delete(reminder)
            }
            for event in try modelContext.fetch(FetchDescriptor<SwiftDataCalendarEventEntity>()) {
                if let identifier = event.notificationID {
                    supersededNotificationIDs.insert(identifier)
                }
                modelContext.delete(event)
            }
            for calendar in try modelContext.fetch(FetchDescriptor<SwiftDataCalendarEntity>()) {
                modelContext.delete(calendar)
            }

            let sourcePersonal = document.data.calendars.first {
                $0.sourceKind == .personal
            }
            let now = Date()
            modelContext.insert(
                SwiftDataCalendarEntity(
                    id: TimeNestCalendar.personalID,
                    name: sourcePersonal?.name
                        ?? LocalizationManager.shared.localized(.calendarSharingMyCalendar),
                    kindRawValue: TimeNestCalendarKind.personal.rawValue,
                    createdAt: sourcePersonal?.createdAt ?? now,
                    updatedAt: now
                )
            )

            for item in document.data.allEvents {
                let event = item.restoredEvent(calendarID: TimeNestCalendar.personalID)
                modelContext.insert(SwiftDataEventMapper.makeEntity(from: event))
            }

            try beforeSaveForTesting?()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        notificationCleaner(supersededNotificationIDs.sorted())
        document.data.settings.restore(to: defaults)
        CalendarSelectionPersistence(defaults: defaults).save(.mine)
        return await rebuildRestoredEventNotifications()
    }

    private func rebuildRestoredEventNotifications() async -> TimeNestRestoreNotificationSummary {
        var summary = TimeNestRestoreNotificationSummary()
        let entities: [SwiftDataCalendarEventEntity]
        do {
            entities = try modelContext.fetch(
                FetchDescriptor<SwiftDataCalendarEventEntity>(sortBy: [SortDescriptor(\.startDate)])
            )
        } catch {
            summary.failedCount = 1
            return summary
        }

        let currentDate = now()
        for entity in entities {
            var event = SwiftDataEventMapper.makeDomainModel(from: entity)
            guard let reminderOffsetMinutes = event.reminderOffsetMinutes else { continue }
            guard event.startDate > currentDate else {
                summary.pastEventCount += 1
                continue
            }
            let triggerDate = event.startDate.addingTimeInterval(
                TimeInterval(-reminderOffsetMinutes * 60)
            )
            guard triggerDate > currentDate else {
                summary.expiredReminderCount += 1
                continue
            }

            event.notificationID = Self.restoredNotificationIdentifier(for: event.id)
            switch await notificationScheduler.scheduleEventNotificationResult(event: event) {
            case .scheduled(let identifier):
                entity.notificationID = identifier
                summary.scheduledCount += 1
            case .triggerDateInPast:
                summary.expiredReminderCount += 1
            case .denied:
                summary.deniedCount += 1
            case .failed, .failedWithCause:
                summary.failedCount += 1
            case .noReminder:
                break
            }
        }

        // The replacement transaction has already committed. Persisting device-local
        // notification IDs is best-effort and must never turn notification failure into
        // a failed data restore.
        do {
            try modelContext.save()
        } catch {
            summary.failedCount += 1
        }
        return summary
    }

    static func restoredNotificationIdentifier(for eventID: UUID) -> String {
        "TimeNest.restoredEvent.\(eventID.uuidString)"
    }
}
