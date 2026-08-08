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

    static var shouldSeedUnifiedEntryScenario: Bool {
        arguments.contains("-seedUnifiedEntryScenario")
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

    static var initialCalendarDate: Date? {
        guard isEnabled,
              let value = value(after: "-uiTestCalendarDate") else {
            return nil
        }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: parts[0],
                month: parts[1],
                day: parts[2],
                hour: 12
            )
        )
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
                TraditionalCalendarPreferences.showLunarCalendarKey,
                TraditionalCalendarPreferences.showRokuyoKey,
                TraditionalCalendarPreferences.showSolarTermsKey,
                MonthSecondaryDisplayMode.storageKey,
                CalendarWeatherStore.enabledKey,
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
        if arguments.contains("-emptyShiftTemplates") {
            defaults.set(true, forKey: "shiftTemplate.deleted.day")
            defaults.set(true, forKey: "shiftTemplate.deleted.night")
        }
        defaults.set("sunday", forKey: "weekStart")
        if let language = value(after: "-uiTestLanguage") {
            defaults.set(language, forKey: "preferredLanguageCode")
        }
        if let theme = value(after: "-uiTestTheme") {
            defaults.set(theme, forKey: "themeMode")
        }
        if arguments.contains("-uiTestShowLunarCalendar") {
            defaults.set(true, forKey: TraditionalCalendarPreferences.showLunarCalendarKey)
        }
        if arguments.contains("-uiTestShowRokuyo") {
            defaults.set(true, forKey: TraditionalCalendarPreferences.showRokuyoKey)
        }
        if arguments.contains("-uiTestShowSolarTerms") {
            defaults.set(true, forKey: TraditionalCalendarPreferences.showSolarTermsKey)
        }
        if let rawMode = value(after: "-uiTestMonthSecondaryMode"),
           let mode = MonthSecondaryDisplayMode(rawValue: rawMode) {
            MonthSecondaryDisplayMode.save(mode, defaults: defaults)
            if mode == .weather {
                defaults.set(true, forKey: CalendarWeatherStore.enabledKey)
            }
        }
        if arguments.contains("-uiTestWeatherEnabled") {
            defaults.set(true, forKey: CalendarWeatherStore.enabledKey)
        }
    }

    static func makeWeatherStore() -> CalendarWeatherStore {
        let referenceDate = initialCalendarDate ?? Date()
        let location = WeatherLocation(
            latitude: 35.68,
            longitude: 139.76,
            fetchedAt: referenceDate
        )
        let snapshot = makeWeatherSnapshot(location: location, referenceDate: referenceDate)
        let shouldFail = arguments.contains("-uiTestWeatherUnavailable")
        return CalendarWeatherStore(
            locationProvider: TimeNestUITestLocationProvider(location: location),
            weatherProvider: TimeNestUITestWeatherProvider(
                snapshot: shouldFail ? nil : snapshot
            ),
            cache: TimeNestUITestWeatherCache(
                snapshot: shouldFail ? nil : snapshot
            ),
            now: { referenceDate }
        )
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
        guard isEnabled, shouldSeedDataManagementScenario else { return }
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

        let shiftEvents = [
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

    static func seedUnifiedEntryScenario(in container: ModelContainer) throws {
        guard isEnabled, shouldSeedUnifiedEntryScenario else { return }
        let context = ModelContext(container)
        context.autosaveEnabled = false

        for event in try context.fetch(FetchDescriptor<SwiftDataCalendarEventEntity>()) {
            context.delete(event)
        }
        for reminder in try context.fetch(FetchDescriptor<SwiftDataReminderEntity>()) {
            context.delete(reminder)
        }
        for calendar in try context.fetch(FetchDescriptor<SwiftDataCalendarEntity>()) {
            context.delete(calendar)
        }

        let now = Date()
        context.insert(
            SwiftDataCalendarEntity(
                id: TimeNestCalendar.personalID,
                name: LocalizationManager.shared.localized(.calendarSharingMyCalendar),
                kindRawValue: TimeNestCalendarKind.personal.rawValue,
                createdAt: now,
                updatedAt: now
            )
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let workDate = calendar.startOfDay(for: now)
        let eventStart = calendar.date(
            bySettingHour: 10,
            minute: 0,
            second: 0,
            of: workDate
        )!
        let clockInDate = calendar.date(
            bySettingHour: 22,
            minute: 0,
            second: 0,
            of: workDate
        )!
        let nextWorkDate = calendar.date(
            byAdding: .day,
            value: 1,
            to: workDate
        )!
        let clockOutDate = calendar.date(
            bySettingHour: 6,
            minute: 0,
            second: 0,
            of: nextWorkDate
        )!
        let unifiedEntryID = UUID(
            uuidString: "60000000-0000-0000-0000-000000000001"
        )!
        let workSessionID = UUID(
            uuidString: "70000000-0000-0000-0000-000000000001"
        )!
        let standaloneUnifiedEntryID = UUID(
            uuidString: "60000000-0000-0000-0000-000000000002"
        )!
        let standaloneWorkSessionID = UUID(
            uuidString: "70000000-0000-0000-0000-000000000002"
        )!
        let standaloneClockInDate = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: nextWorkDate
        )!
        let standaloneClockOutDate = calendar.date(
            bySettingHour: 17,
            minute: 0,
            second: 0,
            of: nextWorkDate
        )!
        let seededEvents = [
            event(
                id: "61000000-0000-0000-0000-000000000001",
                unifiedEntryID: unifiedEntryID,
                calendarID: TimeNestCalendar.personalID,
                title: "Linked UI Event",
                note: "Linked UI note",
                start: eventStart,
                reminderOffsetMinutes: nil
            ),
            event(
                id: "62000000-0000-0000-0000-000000000001",
                unifiedEntryID: unifiedEntryID,
                calendarID: TimeNestCalendar.personalID,
                title: LocalizationManager.shared.localized(.editorWorkIn),
                note: nil,
                start: clockInDate,
                reminderOffsetMinutes: nil,
                workInfo: WorkInfo(
                    workInTime: clockInDate,
                    restHours: 1,
                    workDate: workDate,
                    transportFee: 500,
                    hourlyRate: 2_000,
                    workSessionId: workSessionID,
                    isWorkOutTimeSet: true
                )
            ),
            event(
                id: "63000000-0000-0000-0000-000000000001",
                unifiedEntryID: unifiedEntryID,
                calendarID: TimeNestCalendar.personalID,
                title: LocalizationManager.shared.localized(.editorWorkOut),
                note: nil,
                start: clockOutDate,
                reminderOffsetMinutes: nil,
                workInfo: WorkInfo(
                    workOutTime: clockOutDate,
                    restHours: 1,
                    workDate: workDate,
                    transportFee: 500,
                    hourlyRate: 2_000,
                    workSessionId: workSessionID,
                    isWorkOutTimeSet: true
                )
            ),
            event(
                id: "64000000-0000-0000-0000-000000000001",
                unifiedEntryID: standaloneUnifiedEntryID,
                calendarID: TimeNestCalendar.personalID,
                title: LocalizationManager.shared.localized(.editorWorkIn),
                note: nil,
                start: standaloneClockInDate,
                reminderOffsetMinutes: nil,
                workInfo: WorkInfo(
                    workInTime: standaloneClockInDate,
                    restHours: 1,
                    workDate: nextWorkDate,
                    transportFee: 500,
                    hourlyRate: 2_000,
                    workSessionId: standaloneWorkSessionID,
                    isWorkOutTimeSet: true
                )
            ),
            event(
                id: "65000000-0000-0000-0000-000000000001",
                unifiedEntryID: standaloneUnifiedEntryID,
                calendarID: TimeNestCalendar.personalID,
                title: LocalizationManager.shared.localized(.editorWorkOut),
                note: nil,
                start: standaloneClockOutDate,
                reminderOffsetMinutes: nil,
                workInfo: WorkInfo(
                    workOutTime: standaloneClockOutDate,
                    restHours: 1,
                    workDate: nextWorkDate,
                    transportFee: 500,
                    hourlyRate: 2_000,
                    workSessionId: standaloneWorkSessionID,
                    isWorkOutTimeSet: true
                )
            )
        ]
        for event in seededEvents {
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
        unifiedEntryID: UUID? = nil,
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
            unifiedEntryID: unifiedEntryID,
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

    private static func makeWeatherSnapshot(
        location: WeatherLocation,
        referenceDate: Date
    ) -> WeatherSnapshot {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let dailySymbols = [
            "sun.max.fill",
            "cloud.sun.fill",
            "cloud.rain.fill",
            "cloud.snow.fill"
        ]
        let daily = (0..<10).compactMap { offset -> DailyWeatherSnapshot? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfDay) else {
                return nil
            }
            return DailyWeatherSnapshot(
                date: date,
                symbolName: dailySymbols[offset % dailySymbols.count],
                highTemperatureCelsius: 28 + Double(offset % 3),
                lowTemperatureCelsius: 19 + Double(offset % 2),
                precipitationChance: Double(offset % 4) * 0.1,
                windSpeedMetersPerSecond: 3
            )
        }
        let hourly = (0..<24).compactMap { hour -> HourlyWeatherSnapshot? in
            guard let date = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else {
                return nil
            }
            return HourlyWeatherSnapshot(
                date: date,
                symbolName: hour < 18 ? "sun.max.fill" : "moon.stars.fill",
                temperatureCelsius: 20 + Double(hour % 8),
                precipitationChance: Double(hour % 3) * 0.1,
                windSpeedMetersPerSecond: 2.5
            )
        }
        let attribution = WeatherAttributionSnapshot(
            serviceName: "Apple Weather",
            combinedMarkLightURL: URL(string: "https://example.invalid/apple-weather-light.svg")!,
            combinedMarkDarkURL: URL(string: "https://example.invalid/apple-weather-dark.svg")!,
            squareMarkURL: value(after: "-uiTestWeatherSquareMarkURL")
                .flatMap(URL.init(string:))
                ?? URL(string: "https://example.invalid/apple-weather-square.svg")!,
            legalPageURL: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
        )
        return WeatherSnapshot(
            location: location,
            fetchedAt: referenceDate,
            expirationDate: referenceDate.addingTimeInterval(2 * 60 * 60),
            current: CurrentWeatherSnapshot(
                date: referenceDate,
                symbolName: "cloud.bolt.rain.fill",
                temperatureCelsius: 27,
                windSpeedMetersPerSecond: 3
            ),
            daily: daily,
            hourly: hourly,
            attribution: attribution
        )
    }
}

@MainActor
private final class TimeNestUITestLocationProvider: LocationProviding {
    let authorizationState: LocationAuthorizationState = .authorized
    private let location: WeatherLocation

    init(location: WeatherLocation) {
        self.location = location
    }

    func cachedLocation(maxAge: TimeInterval, now: Date) -> WeatherLocation? {
        location
    }

    func requestLocation() async throws -> WeatherLocation {
        location
    }
}

private actor TimeNestUITestWeatherProvider: WeatherProviding {
    private enum MockError: Error {
        case unavailable
    }

    let snapshot: WeatherSnapshot?

    init(snapshot: WeatherSnapshot?) {
        self.snapshot = snapshot
    }

    func weather(for location: WeatherLocation) async throws -> WeatherSnapshot {
        guard let snapshot else { throw MockError.unavailable }
        return snapshot
    }
}

private actor TimeNestUITestWeatherCache: WeatherCacheProviding {
    private var snapshot: WeatherSnapshot?

    init(snapshot: WeatherSnapshot?) {
        self.snapshot = snapshot
    }

    func load() async -> WeatherSnapshot? {
        snapshot
    }

    func save(_ snapshot: WeatherSnapshot) async throws {
        self.snapshot = snapshot
    }

    func clear() async throws {
        snapshot = nil
    }
}

@MainActor
private final class TimeNestUITestCalendarSharingClient: CalendarSharingClientProtocol {
    let status: CalendarSharingICloudStatus
    let scenario: String?
    private var receivedRecords: [UUID: SharedEventEnvelope] = [:]

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
        case let value? where value.hasPrefix("received"):
            return []
        case nil:
            return []
        default:
            break
        }
        let isEditable = scenario == "acceptedEditable"
        return [ownedState(
            isAccepted: scenario == "accepted" || isEditable,
            isEditable: isEditable
        )]
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
    func fetchReceivedCalendars() async throws -> [ReceivedSharedCalendarPayload] {
        scenario?.hasPrefix("received") == true
            ? [receivedPayload()]
            : []
    }
    func createReceivedSharedEvent(
        _ snapshot: SharedEventSnapshot,
        mutationID: UUID,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope {
        try validateEditable(calendar)
        try await injectEditableWriteOutcomeIfNeeded()
        if receivedRecords[snapshot.id]?.isDeleted == true {
            throw CalendarSharingError.sharedEventDeleted
        }
        let envelope = makeEnvelope(
            snapshot: snapshot,
            mutationID: mutationID,
            calendar: calendar
        )
        receivedRecords[snapshot.id] = envelope
        return envelope
    }
    func updateReceivedSharedEvent(
        _ snapshot: SharedEventSnapshot,
        mutationID: UUID,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope {
        try validateEditable(calendar)
        try await injectEditableWriteOutcomeIfNeeded()
        guard receivedRecords[snapshot.id]?.isDeleted == false else {
            throw CalendarSharingError.sharedEventDeleted
        }
        let envelope = makeEnvelope(
            snapshot: snapshot,
            mutationID: mutationID,
            calendar: calendar
        )
        receivedRecords[snapshot.id] = envelope
        return envelope
    }
    func deleteReceivedSharedEvent(
        eventID: UUID,
        mutationID: UUID,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope? {
        try validateEditable(calendar)
        try await injectEditableWriteOutcomeIfNeeded()
        guard let existing = receivedRecords[eventID] else { return nil }
        if existing.isDeleted { return existing }
        let now = Date()
        let deleted = SharedEventSnapshot(
            id: existing.snapshot.id,
            title: existing.snapshot.title,
            startDate: existing.snapshot.startDate,
            endDate: existing.snapshot.endDate,
            isAllDay: existing.snapshot.isAllDay,
            updatedAt: now,
            isDeleted: true,
            deletedAt: now
        )
        let envelope = makeEnvelope(
            snapshot: deleted,
            mutationID: mutationID,
            calendar: calendar
        )
        receivedRecords[eventID] = envelope
        return envelope
    }
    func fetchReceivedSharedEvent(
        eventID: UUID,
        in calendar: SharedCalendarDescriptor
    ) async throws -> SharedEventEnvelope? {
        receivedRecords[eventID]
    }
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

    private func ownedState(
        isAccepted: Bool,
        isEditable: Bool = false
    ) -> OwnedSharedCalendarCloudState {
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
                shareRecordName: CKRecordNameZoneWideShare,
                eventEditingAllowed: isEditable,
                collaborationProtocolVersion: isEditable ? 1 : 0
            ),
            share: CalendarSharingCloudRecordFactory.makeZoneWideShare(recordZoneID: zoneID),
            participants: [participant]
        )
    }

    private func receivedPayload() -> ReceivedSharedCalendarPayload {
        let calendarID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let isEditable = scenario?.hasPrefix("receivedEditable") == true
        let descriptor = SharedCalendarDescriptor(
            id: calendarID,
            zoneName: CalendarSharingCloudSchema.zoneName(for: calendarID),
            ownerName: "ui-test-owner",
            ownerDisplayName: "UI Test Owner",
            calendarName: "Received UI Test Calendar",
            participantCount: 1,
            kind: .sharedReceived,
            rootRecordName: CalendarSharingCloudSchema.calendarRecordName,
            shareRecordName: CKRecordNameZoneWideShare,
            eventEditingAllowed: isEditable,
            collaborationProtocolVersion: isEditable ? 1 : 0,
            participantPermission: isEditable ? .readWrite : .readOnly
        )
        let envelopes = Array(receivedRecords.values)
        return ReceivedSharedCalendarPayload(
            calendar: descriptor,
            events: envelopes.filter { !$0.isDeleted }.map(\.snapshot),
            shifts: [],
            workRecords: [],
            eventEnvelopes: envelopes
        )
    }

    private func validateEditable(_ calendar: SharedCalendarDescriptor) throws {
        guard scenario?.hasPrefix("receivedEditable") == true,
              calendar.eventEditingAllowed,
              calendar.participantPermission == .readWrite,
              calendar.collaborationProtocolVersion >= 1 else {
            throw CalendarSharingError.sharedEventPermissionRevoked
        }
    }

    private func injectEditableWriteOutcomeIfNeeded() async throws {
        switch scenario {
        case "receivedEditableSaving":
            try await Task.sleep(for: .seconds(30))
        case "receivedEditablePending":
            throw CalendarSharingError.networkUnavailable
        case "receivedEditableFailed":
            throw CalendarSharingError.syncFailed
        case "receivedEditablePermissionRevoked":
            throw CalendarSharingError.permissionDenied
        case "receivedEditableDeletedRemotely":
            throw CalendarSharingError.sharedEventDeleted
        default:
            break
        }
    }

    private func makeEnvelope(
        snapshot: SharedEventSnapshot,
        mutationID: UUID,
        calendar: SharedCalendarDescriptor
    ) -> SharedEventEnvelope {
        SharedEventEnvelope(
            calendarID: calendar.id,
            zoneName: calendar.zoneName,
            ownerName: calendar.ownerName,
            recordName: "collaborative-event-\(snapshot.id.uuidString.lowercased())",
            snapshot: snapshot,
            recordChangeTag: UUID().uuidString,
            modificationDate: Date(),
            creatorIdentifierHash: "ui-test-creator",
            lastModifierIdentifierHash: "ui-test-modifier",
            syncStatus: snapshot.isDeleted ? .deletedRemotely : .synced,
            pendingMutationID: nil,
            lastMutationID: mutationID
        )
    }
}
#endif
