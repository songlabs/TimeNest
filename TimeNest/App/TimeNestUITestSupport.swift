#if DEBUG
import CloudKit
import Foundation
import SwiftData

@MainActor
enum TimeNestUITestSupport {
    private static let arguments = ProcessInfo.processInfo.arguments

    static var isEnabled: Bool {
        arguments.contains("-uiTesting")
    }

    static var suppressesStartupSideEffects: Bool {
        isEnabled || arguments.contains("-liveCloudKitTesting")
    }

    static var shouldSeedDataManagementScenario: Bool {
        arguments.contains("-seedDataManagementScenario")
    }

    static var shouldSeedShiftBatchScenario: Bool {
        arguments.contains("-seedShiftBatchScenario")
    }

    static var preserveExportedTestFile: Bool {
        arguments.contains("-preserveExportedTestFile")
    }

    static var shouldSimulateRestoreFailure: Bool {
        arguments.contains("-simulateRestoreFailure")
    }

    static var mockSharingScenario: String? {
        value(after: "-mockSharingScenario")
    }

    static func configureDefaults() {
        guard isEnabled else { return }
        let defaults = UserDefaults.standard
        if arguments.contains("-resetUITestData") {
            for key in [
                "weekStart",
                "themeMode",
                "preferredLanguageCode",
                "holidaySubscriptions",
                ShiftTemplateFavoritesStore.storageKey,
                CalendarSharingSyncMetadataPersistence.defaultKey
            ] {
                defaults.removeObject(forKey: key)
            }
            for key in defaults.dictionaryRepresentation().keys where
                key.hasPrefix("shiftTime.") || key.hasPrefix("shiftTemplate.deleted.") {
                defaults.removeObject(forKey: key)
            }
        }
        if arguments.contains("-seedInvalidShiftTemplateFavorite") {
            defaults.set(["missing-shift-template"], forKey: ShiftTemplateFavoritesStore.storageKey)
        }
        defaults.set("sunday", forKey: "weekStart")
        if let language = value(after: "-uiTestLanguage") {
            defaults.set(language, forKey: "preferredLanguageCode")
        }
        if let theme = value(after: "-uiTestTheme") {
            defaults.set(theme, forKey: "themeMode")
        }
    }

    static func makeModelPreparation(schema: Schema) throws -> ModelContainerPreparation {
        let configuration = ModelConfiguration(
            "TimeNestUITests",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return ModelContainerPreparation(
            container: try ModelContainer(for: schema, configurations: [configuration]),
            legacyMigrationOutcome: .legacyStoreMissing
        )
    }

    static func seedDataManagementScenario(in container: ModelContainer) throws {
        guard isEnabled, shouldSeedDataManagementScenario || shouldSeedShiftBatchScenario else { return }
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let existingEvents = try context.fetch(FetchDescriptor<SwiftDataCalendarEventEntity>())
        for event in existingEvents { context.delete(event) }
        let existingReminders = try context.fetch(FetchDescriptor<SwiftDataReminderEntity>())
        for reminder in existingReminders { context.delete(reminder) }
        let existingCalendars = try context.fetch(FetchDescriptor<SwiftDataCalendarEntity>())
        for calendar in existingCalendars { context.delete(calendar) }

        let now = Date()
        let secondCalendarID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let usesSharedCalendar = mockSharingScenario != nil
        let sharedZoneName = CalendarSharingCloudSchema.zoneName(for: secondCalendarID)
        context.insert(
            SwiftDataCalendarEntity(
                id: TimeNestCalendar.personalID,
                name: LocalizationManager.shared.localized(.calendarSharingMyCalendar),
                kindRawValue: TimeNestCalendarKind.personal.rawValue,
                createdAt: now,
                updatedAt: now
            )
        )
        context.insert(
            SwiftDataCalendarEntity(
                id: secondCalendarID,
                name: "UI Test Calendar 多言語",
                kindRawValue: usesSharedCalendar
                    ? TimeNestCalendarKind.sharedOwned.rawValue
                    : TimeNestCalendarKind.personal.rawValue,
                zoneName: usesSharedCalendar ? sharedZoneName : nil,
                ownerName: usesSharedCalendar ? CKCurrentUserDefaultName : nil,
                rootRecordName: usesSharedCalendar
                    ? CalendarSharingCloudSchema.calendarRecordName
                    : nil,
                shareRecordName: usesSharedCalendar ? CKRecordNameZoneWideShare : nil,
                stopPhaseRawValue: mockSharingScenario == "stopped"
                    ? TimeNestCalendarStopPhase.cloudDeletionPending.rawValue
                    : TimeNestCalendarStopPhase.active.rawValue,
                createdAt: now,
                updatedAt: now
            )
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let futureStart = now.addingTimeInterval(3_600)
        let pastStart = now.addingTimeInterval(-3_600)
        let ordinaryEvents = [
            event(
                id: "10000000-0000-0000-0000-000000000001",
                calendarID: TimeNestCalendar.personalID,
                title: "予定, \"重要\"\n다음",
                note: "备注,メモ\nNote",
                start: calendar.date(byAdding: .day, value: 2, to: monthStart)!,
                reminderOffsetMinutes: nil
            ),
            event(
                id: "10000000-0000-0000-0000-000000000002",
                calendarID: secondCalendarID,
                title: "Future reminder",
                note: "日本語 简体中文 繁體中文 English 한국어",
                start: futureStart,
                reminderOffsetMinutes: 10
            ),
            event(
                id: "10000000-0000-0000-0000-000000000003",
                calendarID: TimeNestCalendar.personalID,
                title: "Past reminder",
                note: nil,
                start: pastStart,
                reminderOffsetMinutes: 10
            )
        ]

        var shiftEvents = [
            event(
                id: "20000000-0000-0000-0000-000000000001",
                calendarID: TimeNestCalendar.personalID,
                title: "Day shift",
                note: nil,
                start: calendar.date(byAdding: .day, value: 4, to: monthStart)!,
                reminderOffsetMinutes: nil,
                shiftTemplateID: .day
            ),
            event(
                id: "20000000-0000-0000-0000-000000000002",
                calendarID: secondCalendarID,
                title: "Night shift",
                note: nil,
                start: calendar.date(byAdding: .day, value: 6, to: monthStart)!,
                reminderOffsetMinutes: nil,
                shiftTemplateID: .night
            )
        ]

        if shouldSeedShiftBatchScenario {
            let today = calendar.startOfDay(for: now)
            shiftEvents += [
                event(
                    id: "20000000-0000-0000-0000-000000000003",
                    calendarID: TimeNestCalendar.personalID,
                    title: "Previous day shift",
                    note: "Batch copy source",
                    start: calendar.date(byAdding: .day, value: -1, to: today)!,
                    reminderOffsetMinutes: nil,
                    shiftTemplateID: .day
                ),
                event(
                    id: "20000000-0000-0000-0000-000000000004",
                    calendarID: TimeNestCalendar.personalID,
                    title: "Existing shift",
                    note: nil,
                    start: today,
                    reminderOffsetMinutes: nil,
                    shiftTemplateID: .night
                )
            ]
        }

        let workEvents = [
            workSession(dayOffset: 8, startHour: 9, endHour: 17, restHours: 1, monthStart: monthStart, calendar: calendar, suffix: "1"),
            workSession(dayOffset: 10, startHour: 22, endHour: 6, restHours: 1, monthStart: monthStart, calendar: calendar, suffix: "2"),
            workSession(dayOffset: 12, startHour: 8, endHour: 16, restHours: 0.5, monthStart: monthStart, calendar: calendar, suffix: "3")
        ].flatMap { [$0.clockIn, $0.clockOut] }

        for event in ordinaryEvents + shiftEvents + workEvents {
            context.insert(SwiftDataEventMapper.makeEntity(from: event))
        }
        try context.save()
    }

    static func makeCalendarSharingClient() -> any CalendarSharingClientProtocol {
        TimeNestUITestCalendarSharingClient(
            status: mockICloudStatus,
            scenario: mockSharingScenario
        )
    }

    private static var mockICloudStatus: CalendarSharingICloudStatus {
        switch value(after: "-mockCloudKitState") {
        case "available": .available
        case "noAccount": .noAccount
        case "restricted": .restricted
        case "temporarilyUnavailable": .temporarilyUnavailable
        case "networkError": .requestFailed(.networkUnavailable)
        case "permissionDenied": .requestFailed(.permissionDenied)
        case "unknown": .couldNotDetermine
        default: .available
        }
    }

    private static func value(after key: String) -> String? {
        guard let index = arguments.firstIndex(of: key),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func event(
        id: String,
        calendarID: UUID,
        title: String,
        note: String?,
        start: Date,
        reminderOffsetMinutes: Int?,
        shiftTemplateID: ShiftTimeTemplateID? = nil,
        workInfo: WorkInfo? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID(uuidString: id)!,
            calendarID: calendarID,
            title: title,
            note: note,
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: reminderOffsetMinutes,
            notificationID: nil,
            importSource: nil,
            createdAt: start,
            updatedAt: start,
            shiftTemplateID: shiftTemplateID,
            workInfo: workInfo
        )
    }

    private static func workSession(
        dayOffset: Int,
        startHour: Int,
        endHour: Int,
        restHours: Double,
        monthStart: Date,
        calendar: Calendar,
        suffix: String
    ) -> (clockIn: CalendarEvent, clockOut: CalendarEvent) {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!
        let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day)!
        var end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: day)!
        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end)!
        }
        let sessionID = UUID(uuidString: "30000000-0000-0000-0000-00000000000\(suffix)")!
        let clockIn = event(
            id: "40000000-0000-0000-0000-00000000000\(suffix)",
            calendarID: TimeNestCalendar.personalID,
            title: LocalizationManager.shared.localized(.editorWorkIn),
            note: suffix == "1" ? "CSV, \"quoted\"\nline" : nil,
            start: start,
            reminderOffsetMinutes: nil,
            workInfo: WorkInfo(
                workInTime: start,
                restHours: restHours,
                workDate: day,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        )
        let clockOut = event(
            id: "50000000-0000-0000-0000-00000000000\(suffix)",
            calendarID: TimeNestCalendar.personalID,
            title: LocalizationManager.shared.localized(.editorWorkOut),
            note: nil,
            start: end,
            reminderOffsetMinutes: nil,
            workInfo: WorkInfo(
                workOutTime: end,
                restHours: restHours,
                workDate: day,
                workSessionId: sessionID,
                isWorkOutTimeSet: true
            )
        )
        return (clockIn, clockOut)
    }
}

@MainActor
private final class TimeNestUITestCalendarSharingClient: CalendarSharingClientProtocol {
    let status: CalendarSharingICloudStatus
    let scenario: String?

    init(status: CalendarSharingICloudStatus, scenario: String?) {
        self.status = status
        self.scenario = scenario
    }

    func iCloudAccountStatus() async -> CalendarSharingICloudStatus { status }
    func currentUserDisplayName() async -> String? { nil }
    func fetchShareMetadata(from url: URL) async throws -> any CalendarSharingShareMetadata {
        throw CalendarSharingError.metadataFetchFailed
    }
    func fetchOwnedCalendars() async throws -> [OwnedSharedCalendarCloudState] {
        switch scenario {
        case "syncFailure":
            throw CalendarSharingError.syncFailed
        case "syncing":
            try await Task.sleep(nanoseconds: 30_000_000_000)
        case nil:
            return []
        default:
            break
        }
        return [ownedState(isAccepted: scenario == "accepted")]
    }
    func createShare(
        calendarID: UUID,
        calendarName: String,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharingInvitationResult {
        throw CalendarSharingError.shareCreationFailed
    }
    func createInvitation(
        for calendar: OwnedSharedCalendarDescriptor
    ) async throws -> OwnedSharingInvitationResult {
        throw CalendarSharingError.invitationCreationFailed
    }
    func revokePendingInvitation(
        for calendar: OwnedSharedCalendarDescriptor,
        participantID: CKShare.Participant.ID
    ) async throws -> OwnedSharedCalendarCloudState {
        throw CalendarSharingError.invitationCancellationFailed
    }
    func synchronizeOwnedContent(
        calendar: OwnedSharedCalendarDescriptor,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws {
        if scenario == "syncFailure" {
            throw CalendarSharingError.syncFailed
        }
    }
    func renameOwnedCalendar(
        _ calendar: OwnedSharedCalendarDescriptor,
        name: String
    ) async throws {
        throw CalendarSharingError.syncFailed
    }
    func fetchReceivedCalendars() async throws -> [ReceivedSharedCalendarPayload] { [] }
    func accept(
        metadata: any CalendarSharingShareMetadata
    ) async throws -> AcceptedSharedCalendarCloudResult {
        throw CalendarSharingError.invitationAcceptanceFailed
    }
    func leaveSharedCalendar(_ calendar: SharedCalendarDescriptor) async throws {
        throw CalendarSharingError.syncFailed
    }
    func stopOwnedSharing(_ calendar: OwnedSharedCalendarDescriptor) async throws {
        throw CalendarSharingError.syncFailed
    }

    private func ownedState(isAccepted: Bool) -> OwnedSharedCalendarCloudState {
        let calendarID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let zoneID = CKRecordZone.ID(
            zoneName: CalendarSharingCloudSchema.zoneName(for: calendarID),
            ownerName: CKCurrentUserDefaultName
        )
        let participant = SharedCalendarParticipantSnapshot(
            id: "ui-test-participant",
            displayName: isAccepted ? "UI Test Participant" : nil,
            isAccepted: isAccepted,
            permission: .readOnly,
            revocationToken: isAccepted ? nil : "ui-test-revocation-token"
        )
        return OwnedSharedCalendarCloudState(
            calendar: OwnedSharedCalendarDescriptor(
                id: calendarID,
                zoneName: zoneID.zoneName,
                ownerName: zoneID.ownerName,
                calendarName: "UI Test Calendar 多言語",
                participantCount: isAccepted ? 1 : 0,
                rootRecordName: CalendarSharingCloudSchema.calendarRecordName,
                shareRecordName: CKRecordNameZoneWideShare
            ),
            share: CalendarSharingCloudRecordFactory.makeZoneWideShare(recordZoneID: zoneID),
            participants: [participant]
        )
    }
}
#endif
