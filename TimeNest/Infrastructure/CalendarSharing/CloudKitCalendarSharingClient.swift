import CloudKit
import Foundation
import OSLog

struct ReceivedSharedCalendarPayload {
    let calendar: SharedCalendarDescriptor
    let events: [SharedEventSnapshot]
    let shifts: [SharedShiftSnapshot]
    let workRecords: [SharedWorkRecordSnapshot]
}

struct SharedZoneRecordCollection {
    private(set) var recordsByID: [CKRecord.ID: CKRecord] = [:]

    mutating func apply(_ records: [CKRecord]) {
        for record in records {
            recordsByID[record.recordID] = record
        }
    }

    mutating func remove(_ recordID: CKRecord.ID) {
        recordsByID.removeValue(forKey: recordID)
    }

    func records(ofType recordType: CKRecord.RecordType) -> [CKRecord] {
        recordsByID.values
            .filter { $0.recordType == recordType }
            .sorted { $0.recordID.recordName < $1.recordID.recordName }
    }
}

enum ReceivedSharedCalendarPayloadAssembler {
    static func makePayload(
        zoneID: CKRecordZone.ID,
        records: SharedZoneRecordCollection
    ) -> ReceivedSharedCalendarPayload? {
        guard let calendarRecord = records.records(
            ofType: CalendarSharingCloudSchema.calendarRecordType
        ).first else {
            return nil
        }
        let content = CalendarSharingCloudSchema.contentConfiguration(from: calendarRecord)
        let share = records.records(ofType: CKRecord.SystemType.share).first as? CKShare

        return ReceivedSharedCalendarPayload(
            calendar: SharedCalendarDescriptor(
                id: CalendarSharingCloudSchema.identity(for: zoneID),
                zoneName: zoneID.zoneName,
                ownerName: zoneID.ownerName,
                displayName: calendarRecord[CalendarSharingCloudSchema.CalendarField.displayName] as? String,
                calendarName: calendarRecord[CalendarSharingCloudSchema.CalendarField.calendarName] as? String,
                participantCount: share.map(participantCount(in:)) ?? 0,
                contentConfiguration: content
            ),
            events: content.sharesEvents
                ? records.records(ofType: CalendarSharingCloudSchema.eventRecordType).compactMap(decodeEvent)
                : [],
            shifts: content.sharesShifts
                ? records.records(ofType: CalendarSharingCloudSchema.shiftRecordType).compactMap(decodeShift)
                : [],
            workRecords: content.sharesWorkRecords
                ? records.records(ofType: CalendarSharingCloudSchema.workRecordType).compactMap(decodeWorkRecord)
                : []
        )
    }

    private static func decodeEvent(_ record: CKRecord) -> SharedEventSnapshot? {
        guard let idValue = record[CalendarSharingCloudSchema.EventField.eventID] as? String,
              let id = UUID(uuidString: idValue),
              let title = record[CalendarSharingCloudSchema.EventField.title] as? String,
              let startDate = record[CalendarSharingCloudSchema.EventField.startDate] as? Date,
              let endDate = record[CalendarSharingCloudSchema.EventField.endDate] as? Date,
              let allDayNumber = record[CalendarSharingCloudSchema.EventField.isAllDay] as? NSNumber,
              let updatedAt = record[CalendarSharingCloudSchema.EventField.updatedAt] as? Date else {
            return nil
        }
        return SharedEventSnapshot(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: allDayNumber.boolValue,
            updatedAt: updatedAt
        )
    }

    private static func decodeShift(_ record: CKRecord) -> SharedShiftSnapshot? {
        guard let idValue = record[CalendarSharingCloudSchema.ShiftField.shiftID] as? String,
              let id = UUID(uuidString: idValue),
              let registeredDate = record[CalendarSharingCloudSchema.ShiftField.registeredDate] as? Date,
              let displayName = record[CalendarSharingCloudSchema.ShiftField.displayName] as? String,
              let startDate = record[CalendarSharingCloudSchema.ShiftField.startDate] as? Date,
              let endDate = record[CalendarSharingCloudSchema.ShiftField.endDate] as? Date,
              let spansMidnight = record[CalendarSharingCloudSchema.ShiftField.spansMidnight] as? NSNumber,
              let colorHex = record[CalendarSharingCloudSchema.ShiftField.colorHex] as? String,
              let updatedAt = record[CalendarSharingCloudSchema.ShiftField.updatedAt] as? Date else {
            return nil
        }
        return SharedShiftSnapshot(
            id: id,
            registeredDate: registeredDate,
            displayName: displayName,
            startDate: startDate,
            endDate: endDate,
            spansMidnight: spansMidnight.boolValue,
            colorHex: colorHex,
            updatedAt: updatedAt
        )
    }

    private static func decodeWorkRecord(_ record: CKRecord) -> SharedWorkRecordSnapshot? {
        guard let idValue = record[CalendarSharingCloudSchema.WorkRecordField.workRecordID] as? String,
              let id = UUID(uuidString: idValue),
              let workDate = record[CalendarSharingCloudSchema.WorkRecordField.workDate] as? Date,
              let isWorkOutTimeSet = record[
                CalendarSharingCloudSchema.WorkRecordField.isWorkOutTimeSet
              ] as? NSNumber,
              let restHours = record[CalendarSharingCloudSchema.WorkRecordField.restHours] as? NSNumber,
              let updatedAt = record[CalendarSharingCloudSchema.WorkRecordField.updatedAt] as? Date else {
            return nil
        }
        return SharedWorkRecordSnapshot(
            id: id,
            workDate: workDate,
            workInTime: record[CalendarSharingCloudSchema.WorkRecordField.workInTime] as? Date,
            workOutTime: record[CalendarSharingCloudSchema.WorkRecordField.workOutTime] as? Date,
            isWorkOutTimeSet: isWorkOutTimeSet.boolValue,
            restHours: restHours.doubleValue,
            updatedAt: updatedAt
        )
    }

    private static func participantCount(in share: CKShare) -> Int {
        share.participants.filter {
            $0.role != .owner && $0.acceptanceStatus != .removed
        }.count
    }
}

struct OwnedSharedCalendarCloudState {
    let calendar: OwnedSharedCalendarDescriptor
    let share: CKShare
}

struct CalendarSharingContentReconciliationPlan {
    let content: SharedContentConfiguration

    var deletesAllEventRecords: Bool { !content.sharesEvents }
    var deletesAllShiftRecords: Bool { !content.sharesShifts }
    var deletesAllWorkRecords: Bool { !content.sharesWorkRecords }

    func eventsToSave(_ snapshots: [SharedEventSnapshot]) -> [SharedEventSnapshot] {
        content.sharesEvents ? snapshots : []
    }

    func shiftsToSave(_ snapshots: [SharedShiftSnapshot]) -> [SharedShiftSnapshot] {
        content.sharesShifts ? snapshots : []
    }

    func workRecordsToSave(_ snapshots: [SharedWorkRecordSnapshot]) -> [SharedWorkRecordSnapshot] {
        content.sharesWorkRecords ? snapshots : []
    }
}

@MainActor
protocol CalendarSharingClientProtocol {
    func ownedCalendarState() async throws -> OwnedSharedCalendarCloudState?
    func createShare(
        displayName: String,
        calendarName: String,
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharedCalendarCloudState
    func ownedShareForPresentation() async throws -> CKShare
    func synchronizeOwnedContent(
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws
    func updateOwnedSharing(
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharedCalendarCloudState
    func fetchReceivedCalendars() async throws -> [ReceivedSharedCalendarPayload]
    func accept(metadata: CKShare.Metadata) async throws -> String
    func leaveSharedCalendar(_ calendar: SharedCalendarDescriptor) async throws
    func stopOwnedSharing(plan: OwnedSharingStopPlan) async throws
}

enum CalendarSharingErrorContext: Equatable {
    case general
    case creatingShare
}

enum CalendarSharingDiagnostics {
#if DEBUG
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.song.TimeNest",
        category: "CalendarSharing"
    )
#endif

    static func debug(
        operation: String,
        stage: String,
        database: String,
        details: @autoclosure () -> String = ""
    ) {
#if DEBUG
        let detailText = details()
        logger.debug(
            "operation=\(operation, privacy: .public) stage=\(stage, privacy: .public) database=\(database, privacy: .public) \(detailText, privacy: .public)"
        )
#endif
    }

    static func error(
        operation: String,
        stage: String,
        database: String,
        error: Error,
        details: @autoclosure () -> String = ""
    ) {
#if DEBUG
        let errorDetails = CalendarSharingErrorMapper.diagnosticSummary(error)
        let contextualDetails = details()
        logger.error(
            "operation=\(operation, privacy: .public) stage=\(stage, privacy: .public) database=\(database, privacy: .public) \(contextualDetails, privacy: .public) \(errorDetails, privacy: .public)"
        )
#endif
    }
}

enum CalendarSharingCloudSchema {
    static let zoneName = "TimeNestSharedCalendar"
    static let calendarRecordType = "SharedCalendar"
    static let eventRecordType = "SharedEvent"
    static let shiftRecordType = "SharedShift"
    static let workRecordType = "SharedWorkRecord"
    static let calendarRecordName = "calendar"

    enum CalendarField {
        static let displayName = "displayName"
        static let calendarName = "calendarName"
        static let updatedAt = "updatedAt"
        static let sharesEvents = "sharesEvents"
        static let sharesShifts = "sharesShifts"
        static let sharesWorkRecords = "sharesWorkRecords"
        static let schemaVersion = "schemaVersion"
    }

    enum EventField {
        static let eventID = "eventID"
        static let title = "title"
        static let startDate = "startDate"
        static let endDate = "endDate"
        static let isAllDay = "isAllDay"
        static let updatedAt = "updatedAt"
    }

    enum ShiftField {
        static let shiftID = "shiftID"
        static let registeredDate = "registeredDate"
        static let displayName = "displayName"
        static let startDate = "startDate"
        static let endDate = "endDate"
        static let spansMidnight = "spansMidnight"
        static let colorHex = "colorHex"
        static let updatedAt = "updatedAt"
    }

    enum WorkRecordField {
        static let workRecordID = "workRecordID"
        static let workDate = "workDate"
        static let workInTime = "workInTime"
        static let workOutTime = "workOutTime"
        static let isWorkOutTimeSet = "isWorkOutTimeSet"
        static let restHours = "restHours"
        static let updatedAt = "updatedAt"
    }

    static func contentConfiguration(from record: CKRecord) -> SharedContentConfiguration {
        SharedContentConfiguration(
            sharesEvents: (record[CalendarField.sharesEvents] as? NSNumber)?.boolValue ?? true,
            sharesShifts: (record[CalendarField.sharesShifts] as? NSNumber)?.boolValue ?? false,
            sharesWorkRecords: (record[CalendarField.sharesWorkRecords] as? NSNumber)?.boolValue ?? false,
            schemaVersion: (record[CalendarField.schemaVersion] as? NSNumber)?.intValue ?? 1
        )
    }

    static func apply(_ content: SharedContentConfiguration, to record: CKRecord) {
        record[CalendarField.sharesEvents] = NSNumber(value: content.sharesEvents)
        record[CalendarField.sharesShifts] = NSNumber(value: content.sharesShifts)
        record[CalendarField.sharesWorkRecords] = NSNumber(value: content.sharesWorkRecords)
        record[CalendarField.schemaVersion] = NSNumber(value: content.schemaVersion)
    }

    static func identity(for zoneID: CKRecordZone.ID) -> String {
        Data("\(zoneID.ownerName)\u{1F}\(zoneID.zoneName)".utf8).base64EncodedString()
    }
}

enum CalendarSharingErrorMapper {
    static func map(
        _ error: Error,
        context: CalendarSharingErrorContext = .general
    ) -> CalendarSharingError {
        let codes = cloudErrors(in: error).map(\.code)
        guard !codes.isEmpty else {
            return context == .creatingShare ? .shareCreationFailed : .syncFailed
        }

        if codes.contains(.missingEntitlement) || codes.contains(.badContainer)
            || codes.contains(.managedAccountRestricted) {
            return .iCloudRestricted
        }
        if codes.contains(.notAuthenticated) {
            return .noICloudAccount
        }
        if codes.contains(.accountTemporarilyUnavailable)
            || codes.contains(.networkUnavailable)
            || codes.contains(.networkFailure)
            || codes.contains(.serviceUnavailable)
            || codes.contains(.requestRateLimited)
            || codes.contains(.zoneBusy)
            || codes.contains(.serverResponseLost) {
            return .networkUnavailable
        }
        if codes.contains(.participantMayNeedVerification) {
            return .invitationPending
        }
        if codes.contains(.permissionFailure) {
            return .permissionDenied
        }
        return context == .creatingShare ? .shareCreationFailed : .syncFailed
    }

    static func map(
        code: CKError.Code,
        context: CalendarSharingErrorContext = .general
    ) -> CalendarSharingError {
        switch code {
        case .notAuthenticated:
            return .noICloudAccount
        case .managedAccountRestricted, .missingEntitlement, .badContainer:
            return .iCloudRestricted
        case .accountTemporarilyUnavailable, .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy, .serverResponseLost:
            return .networkUnavailable
        case .participantMayNeedVerification:
            return .invitationPending
        case .permissionFailure:
            return .permissionDenied
        default:
            return context == .creatingShare ? .shareCreationFailed : .syncFailed
        }
    }

    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || cloudErrors(in: error).contains { $0.code == .operationCancelled }
    }

    static func isMissingOrInaccessibleSharedZone(_ error: Error) -> Bool {
        let leafCodes = cloudErrors(in: error)
            .map(\.code)
            .filter { $0 != .partialFailure }
        guard !leafCodes.isEmpty else { return false }
        return leafCodes.allSatisfy {
            $0 == .unknownItem || $0 == .userDeletedZone
        }
    }

    static func shouldTreatMissingQueriedRecordTypeAsEmpty(_ error: Error) -> Bool {
        let leafCodes = cloudErrors(in: error)
            .map(\.code)
            .filter { $0 != .partialFailure }
        return !leafCodes.isEmpty && leafCodes.allSatisfy { $0 == .unknownItem }
    }

    static func cloudErrorCodeSummary(_ error: Error) -> String {
        let codes = cloudErrors(in: error).map {
            "\(cloudErrorCodeName($0.code))(\($0.code.rawValue))"
        }
        return codes.isEmpty ? "none" : Array(Set(codes)).sorted().joined(separator: ",")
    }

    static func cloudErrorCodes(in error: Error) -> [CKError.Code] {
        cloudErrors(in: error).map(\.code)
    }

    static func cloudErrorCodeName(_ code: CKError.Code) -> String {
        switch code {
        case .internalError: "internalError"
        case .partialFailure: "partialFailure"
        case .networkUnavailable: "networkUnavailable"
        case .networkFailure: "networkFailure"
        case .badContainer: "badContainer"
        case .serviceUnavailable: "serviceUnavailable"
        case .requestRateLimited: "requestRateLimited"
        case .missingEntitlement: "missingEntitlement"
        case .notAuthenticated: "notAuthenticated"
        case .permissionFailure: "permissionFailure"
        case .unknownItem: "unknownItem"
        case .invalidArguments: "invalidArguments"
        case .resultsTruncated: "resultsTruncated"
        case .serverRecordChanged: "serverRecordChanged"
        case .serverRejectedRequest: "serverRejectedRequest"
        case .assetFileNotFound: "assetFileNotFound"
        case .assetFileModified: "assetFileModified"
        case .incompatibleVersion: "incompatibleVersion"
        case .constraintViolation: "constraintViolation"
        case .operationCancelled: "operationCancelled"
        case .changeTokenExpired: "changeTokenExpired"
        case .batchRequestFailed: "batchRequestFailed"
        case .zoneBusy: "zoneBusy"
        case .badDatabase: "badDatabase"
        case .quotaExceeded: "quotaExceeded"
        case .zoneNotFound: "zoneNotFound"
        case .limitExceeded: "limitExceeded"
        case .userDeletedZone: "userDeletedZone"
        case .tooManyParticipants: "tooManyParticipants"
        case .alreadyShared: "alreadyShared"
        case .referenceViolation: "referenceViolation"
        case .managedAccountRestricted: "managedAccountRestricted"
        case .participantMayNeedVerification: "participantMayNeedVerification"
        case .serverResponseLost: "serverResponseLost"
        case .assetNotAvailable: "assetNotAvailable"
        case .accountTemporarilyUnavailable: "accountTemporarilyUnavailable"
        case .participantAlreadyInvited: "participantAlreadyInvited"
        @unknown default: "unknown"
        }
    }

    static func diagnosticSummary(_ error: Error) -> String {
        let cloudErrors = cloudErrors(in: error)
        let rootDomain = (error as NSError).domain
        let domains = Set(cloudErrors.map { ($0 as NSError).domain })
        let leafCodes = cloudErrors
            .filter { $0.code != .partialFailure }
            .map { "\(cloudErrorCodeName($0.code))(\($0.code.rawValue))" }
        let messages = ([error] + cloudErrors).flatMap(sanitizedMessages)

        return [
            "errorDomain=\(rootDomain)",
            "errorDomains=\(domains.sorted().joined(separator: ","))",
            "ckErrorCodes=\(cloudErrorCodeSummary(error))",
            "leafErrorCodes=\(leafCodes.isEmpty ? "none" : Array(Set(leafCodes)).sorted().joined(separator: ","))",
            "serverMessage=\(messages.isEmpty ? "none" : Array(Set(messages)).joined(separator: " | "))"
        ].joined(separator: " ")
    }

    static func shouldRestartZoneChangesFromBeginning(_ error: Error, alreadyRetried: Bool) -> Bool {
        !alreadyRetried && cloudErrorCodes(in: error).contains(.changeTokenExpired)
    }

    private static func cloudErrors(in error: Error) -> [CKError] {
        guard let cloudError = error as? CKError else { return [] }
        guard cloudError.code == .partialFailure,
              let partialErrors = cloudError.userInfo[CKPartialErrorsByItemIDKey]
                as? [AnyHashable: Error] else {
            return [cloudError]
        }
        return [cloudError] + partialErrors.values.flatMap(cloudErrors(in:))
    }

    private static func sanitizedMessages(_ error: Error) -> [String] {
        let nsError = error as NSError
        let userInfoMessages = nsError.userInfo.compactMap { key, value -> String? in
            let normalizedKey = String(describing: key).lowercased()
            guard normalizedKey.contains("description") || normalizedKey.contains("message"),
                  let message = value as? String,
                  !message.isEmpty else {
                return nil
            }
            return message
        }
        return ([nsError.localizedDescription] + userInfoMessages)
            .filter { !$0.isEmpty }
            .map(redactIdentifiers)
    }

    private static func redactIdentifiers(in text: String) -> String {
        let patterns = [
            #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#,
            #"[A-Za-z0-9_+/=-]{17,}"#
        ]
        return patterns.reduce(String(text.prefix(512))) { partial, pattern in
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return partial }
            let range = NSRange(partial.startIndex..., in: partial)
            return expression.stringByReplacingMatches(
                in: partial,
                range: range,
                withTemplate: "<redacted>"
            )
        }
    }
}

@MainActor
final class CloudKitCalendarSharingClient: CalendarSharingClientProtocol {
    let container: CKContainer
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private var sharedDatabase: CKDatabase { container.sharedCloudDatabase }

    init(container: CKContainer = .default()) {
        self.container = container
    }

    func verifyAccountAvailability() async throws {
        do {
            let status = try await container.accountStatus()
            CalendarSharingDiagnostics.debug(
                operation: "accountStatus",
                stage: "completed",
                database: "container",
                details: "accountStatus=\(accountStatusName(status))"
            )
            switch status {
            case .available:
                return
            case .noAccount:
                throw CalendarSharingError.noICloudAccount
            case .temporarilyUnavailable, .couldNotDetermine:
                throw CalendarSharingError.networkUnavailable
            case .restricted:
                throw CalendarSharingError.iCloudRestricted
            @unknown default:
                throw CalendarSharingError.syncFailed
            }
        } catch let error as CalendarSharingError {
            throw error
        } catch {
            if CalendarSharingErrorMapper.isCancellation(error) {
                throw CancellationError()
            }
            CalendarSharingDiagnostics.error(
                operation: "accountStatus",
                stage: "failed",
                database: "container",
                error: error
            )
            throw CalendarSharingErrorMapper.map(error)
        }
    }

    func ownedCalendarState() async throws -> OwnedSharedCalendarCloudState? {
        try await verifyAccountAvailability()
        let zoneID = ownedZoneID
        let calendarID = CKRecord.ID(
            recordName: CalendarSharingCloudSchema.calendarRecordName,
            zoneID: zoneID
        )
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)

        do {
            guard let calendarRecord = try await optionalRecord(calendarID, database: privateDatabase),
                  let share = try await optionalRecord(shareID, database: privateDatabase) as? CKShare else {
                CalendarSharingDiagnostics.debug(
                    operation: "refreshOwnedCalendar",
                    stage: "completed",
                    database: "private",
                    details: "rootSaved=false shareSaved=false"
                )
                return nil
            }
            let state = OwnedSharedCalendarCloudState(
                calendar: OwnedSharedCalendarDescriptor(
                    displayName: calendarRecord[CalendarSharingCloudSchema.CalendarField.displayName] as? String ?? "",
                    calendarName: calendarRecord[CalendarSharingCloudSchema.CalendarField.calendarName] as? String ?? "",
                    participantCount: participantCount(in: share),
                    contentConfiguration: CalendarSharingCloudSchema.contentConfiguration(from: calendarRecord)
                ),
                share: share
            )
            CalendarSharingDiagnostics.debug(
                operation: "refreshOwnedCalendar",
                stage: "completed",
                database: "private",
                details: "rootSaved=true shareSaved=true"
            )
            return state
        } catch {
            if CalendarSharingErrorMapper.isCancellation(error) {
                throw CancellationError()
            }
            CalendarSharingDiagnostics.error(
                operation: "refreshOwnedCalendar",
                stage: "fetch_records",
                database: "private",
                error: error
            )
            throw CalendarSharingErrorMapper.map(error)
        }
    }

    func createShare(
        displayName: String,
        calendarName: String,
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharedCalendarCloudState {
        guard content.hasSelectedContent else {
            throw CalendarSharingError.contentSelectionRequired
        }
        try await verifyAccountAvailability()
        var stage = "ensure_zone"
        do {
            try await ensureOwnedZone()
            CalendarSharingDiagnostics.debug(
                operation: "createShare",
                stage: stage,
                database: "private",
                details: "zoneReady=true"
            )

            stage = "save_root"
            let calendarID = CKRecord.ID(
                recordName: CalendarSharingCloudSchema.calendarRecordName,
                zoneID: ownedZoneID
            )
            let calendarRecord = try await optionalRecord(calendarID, database: privateDatabase)
                ?? CKRecord(recordType: CalendarSharingCloudSchema.calendarRecordType, recordID: calendarID)
            let existingDisplayName = (
                calendarRecord[CalendarSharingCloudSchema.CalendarField.displayName] as? String
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            let internalDisplayName = existingDisplayName.flatMap { $0.isEmpty ? nil : $0 }
                ?? displayName
            calendarRecord[CalendarSharingCloudSchema.CalendarField.displayName] = internalDisplayName as CKRecordValue
            calendarRecord[CalendarSharingCloudSchema.CalendarField.calendarName] = calendarName as CKRecordValue
            calendarRecord[CalendarSharingCloudSchema.CalendarField.updatedAt] = Date() as CKRecordValue
            CalendarSharingCloudSchema.apply(content, to: calendarRecord)

            let calendarResult = try await privateDatabase.modifyRecords(
                saving: [calendarRecord],
                deleting: [],
                savePolicy: .changedKeys,
                atomically: true
            )
            try validate(calendarResult.saveResults)
            CalendarSharingDiagnostics.debug(
                operation: "createShare",
                stage: stage,
                database: "private",
                details: "rootSaved=true"
            )

            stage = "save_content"
            try await replaceOwnedContent(
                content: content,
                events: events,
                shifts: shifts,
                workRecords: workRecords
            )
            CalendarSharingDiagnostics.debug(
                operation: "createShare",
                stage: stage,
                database: "private",
                details: "events=\(events.count) shifts=\(shifts.count) workRecords=\(workRecords.count)"
            )

            stage = "save_share"
            let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: ownedZoneID)
            let share = (try await optionalRecord(shareID, database: privateDatabase) as? CKShare)
                ?? CKShare(recordZoneID: ownedZoneID)
            share.publicPermission = .none
            for participant in share.participants where participant.role != .owner {
                participant.permission = .readOnly
            }
            share[CKShare.SystemFieldKey.title] = calendarName as CKRecordValue

            let result = try await privateDatabase.modifyRecords(
                saving: [share],
                deleting: [],
                savePolicy: .changedKeys,
                atomically: true
            )
            try validate(result.saveResults)
            guard let saved = try result.saveResults[share.recordID]?.get() as? CKShare else {
                throw CalendarSharingError.shareCreationFailed
            }
            let state = OwnedSharedCalendarCloudState(
                calendar: OwnedSharedCalendarDescriptor(
                    displayName: internalDisplayName,
                    calendarName: calendarName,
                    participantCount: participantCount(in: saved),
                    contentConfiguration: content
                ),
                share: saved
            )
            CalendarSharingDiagnostics.debug(
                operation: "createShare",
                stage: stage,
                database: "private",
                details: "shareSaved=true participantCount=\(state.calendar.participantCount)"
            )
            return state
        } catch let error as CalendarSharingError {
            throw error
        } catch {
            if CalendarSharingErrorMapper.isCancellation(error) {
                throw CancellationError()
            }
            CalendarSharingDiagnostics.error(
                operation: "createShare",
                stage: stage,
                database: "private",
                error: error
            )
            throw CalendarSharingErrorMapper.map(error, context: .creatingShare)
        }
    }

    func ownedShareForPresentation() async throws -> CKShare {
        guard let state = try await ownedCalendarState() else {
            throw CalendarSharingError.syncFailed
        }
        return state.share
    }

    func synchronizeOwnedContent(
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws {
        try await verifyAccountAvailability()
        guard try await ownedCalendarState() != nil else { return }

        do {
            try await replaceOwnedContent(
                content: content,
                events: events,
                shifts: shifts,
                workRecords: workRecords
            )
            CalendarSharingDiagnostics.debug(
                operation: "synchronizeOwnedContent",
                stage: "completed",
                database: "private",
                details: "events=\(events.count) shifts=\(shifts.count) workRecords=\(workRecords.count)"
            )
        } catch let error as CalendarSharingError {
            throw error
        } catch {
            if CalendarSharingErrorMapper.isCancellation(error) {
                throw CancellationError()
            }
            CalendarSharingDiagnostics.error(
                operation: "synchronizeOwnedContent",
                stage: "save_content",
                database: "private",
                error: error
            )
            throw CalendarSharingErrorMapper.map(error)
        }
    }

    func updateOwnedSharing(
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharedCalendarCloudState {
        guard content.hasSelectedContent else {
            throw CalendarSharingError.contentSelectionRequired
        }
        try await verifyAccountAvailability()
        guard let currentState = try await ownedCalendarState() else {
            throw CalendarSharingError.shareUnavailable
        }

        do {
            // Content records are reconciled before the root flags become visible to recipients.
            // If a partial deletion fails, the saved configuration and local data stay unchanged.
            try await replaceOwnedContent(
                content: content,
                events: events,
                shifts: shifts,
                workRecords: workRecords
            )
            let calendarID = CKRecord.ID(
                recordName: CalendarSharingCloudSchema.calendarRecordName,
                zoneID: ownedZoneID
            )
            guard let calendarRecord = try await optionalRecord(calendarID, database: privateDatabase) else {
                throw CalendarSharingError.shareUnavailable
            }
            CalendarSharingCloudSchema.apply(content, to: calendarRecord)
            calendarRecord[CalendarSharingCloudSchema.CalendarField.updatedAt] = Date() as CKRecordValue
            let result = try await privateDatabase.modifyRecords(
                saving: [calendarRecord],
                deleting: [],
                savePolicy: .changedKeys,
                atomically: true
            )
            try validate(result.saveResults)

            var calendar = currentState.calendar
            calendar.contentConfiguration = content
            return OwnedSharedCalendarCloudState(calendar: calendar, share: currentState.share)
        } catch let error as CalendarSharingError {
            throw error
        } catch {
            if CalendarSharingErrorMapper.isCancellation(error) {
                throw CancellationError()
            }
            CalendarSharingDiagnostics.error(
                operation: "updateOwnedSharing",
                stage: "reconcile_content",
                database: "private",
                error: error
            )
            throw CalendarSharingErrorMapper.map(error)
        }
    }

    func fetchReceivedCalendars() async throws -> [ReceivedSharedCalendarPayload] {
        try await verifyAccountAvailability()
        do {
            let zones: [CKRecordZone]
            CalendarSharingDiagnostics.debug(
                operation: "refreshSharedCalendars",
                stage: "fetch_zones_started",
                database: "shared"
            )
            do {
                zones = try await sharedDatabase.allRecordZones()
                CalendarSharingDiagnostics.debug(
                    operation: "refreshSharedCalendars",
                    stage: "fetch_zones_completed",
                    database: "shared",
                    details: "sharedZoneCount=\(zones.count)"
                )
            } catch {
                CalendarSharingDiagnostics.error(
                    operation: "refreshSharedCalendars",
                    stage: "fetch_zones_failed",
                    database: "shared",
                    error: error
                )
                throw error
            }
            var payloads: [ReceivedSharedCalendarPayload] = []

            for zone in zones where zone.zoneID.zoneName != CKRecordZone.default().zoneID.zoneName {
                do {
                    let records = try await allSharedRecordsFromZoneChanges(zoneID: zone.zoneID)
                    logSharedRecordClassification(records, zoneID: zone.zoneID)
                    guard let payload = ReceivedSharedCalendarPayloadAssembler.makePayload(
                        zoneID: zone.zoneID,
                        records: records
                    ) else {
                        CalendarSharingDiagnostics.debug(
                            operation: "refreshSharedCalendars",
                            stage: "fetch_shared_calendar_failed",
                            database: "shared",
                            details: "recordType=\(CalendarSharingCloudSchema.calendarRecordType) recordCount=0 zone=\(zone.zoneID.zoneName) reason=missing_root"
                        )
                        continue
                    }
                    payloads.append(payload)
                } catch {
                    if CalendarSharingErrorMapper.isMissingOrInaccessibleSharedZone(error)
                        || CalendarSharingErrorMapper.cloudErrorCodes(in: error).contains(.zoneNotFound) {
                        CalendarSharingDiagnostics.error(
                            operation: "refreshSharedCalendars",
                            stage: "skip_unavailable_zone",
                            database: "shared",
                            error: error,
                            details: "zone=\(zone.zoneID.zoneName)"
                        )
                        continue
                    }
                    throw error
                }
            }

            let sortedPayloads = payloads.sorted {
                ($0.calendar.calendarName ?? "").localizedCaseInsensitiveCompare($1.calendar.calendarName ?? "") == .orderedAscending
            }
            CalendarSharingDiagnostics.debug(
                operation: "refreshSharedCalendars",
                stage: "completed",
                database: "shared",
                details: "receivedCount=\(sortedPayloads.count)"
            )
            return sortedPayloads
        } catch let error as CalendarSharingError {
            throw error
        } catch {
            if CalendarSharingErrorMapper.isCancellation(error) {
                throw CancellationError()
            }
            CalendarSharingDiagnostics.error(
                operation: "refreshSharedCalendars",
                stage: "failed",
                database: "shared",
                error: error
            )
            throw CalendarSharingErrorMapper.map(error)
        }
    }

    func accept(metadata: CKShare.Metadata) async throws -> String {
        try await verifyAccountAvailability()
        do {
            let results = try await container.accept([metadata])
            guard let result = results[metadata] else {
                throw CalendarSharingError.invitationPending
            }
            let share = try result.get()
            return CalendarSharingCloudSchema.identity(for: share.recordID.zoneID)
        } catch let error as CalendarSharingError {
            throw error
        } catch {
            if CalendarSharingErrorMapper.isCancellation(error) {
                throw CancellationError()
            }
            throw CalendarSharingErrorMapper.map(error)
        }
    }

    func leaveSharedCalendar(_ calendar: SharedCalendarDescriptor) async throws {
        try await verifyAccountAvailability()
        let zoneID = CKRecordZone.ID(zoneName: calendar.zoneName, ownerName: calendar.ownerName)
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        do {
            let result = try await sharedDatabase.modifyRecords(
                saving: [],
                deleting: [shareID],
                savePolicy: .ifServerRecordUnchanged,
                atomically: true
            )
            try validate(result.deleteResults)
        } catch {
            if CalendarSharingErrorMapper.isCancellation(error) {
                throw CancellationError()
            }
            throw CalendarSharingErrorMapper.map(error)
        }
    }

    func stopOwnedSharing(plan: OwnedSharingStopPlan = OwnedSharingStopPlan()) async throws {
        precondition(plan.deletesShareRecord && !plan.deletesRecordZone && !plan.deletesLocalEvents)
        try await verifyAccountAvailability()
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: ownedZoneID)
        do {
            let result = try await privateDatabase.modifyRecords(
                saving: [],
                deleting: [shareID],
                savePolicy: .ifServerRecordUnchanged,
                atomically: true
            )
            try validate(result.deleteResults)
        } catch {
            if CalendarSharingErrorMapper.isCancellation(error) {
                throw CancellationError()
            }
            throw CalendarSharingErrorMapper.map(error)
        }
    }

    private var ownedZoneID: CKRecordZone.ID {
        CKRecordZone.ID(
            zoneName: CalendarSharingCloudSchema.zoneName,
            ownerName: CKCurrentUserDefaultName
        )
    }

    private func ensureOwnedZone() async throws {
        let zones = try await privateDatabase.allRecordZones()
        if zones.contains(where: { $0.zoneID == ownedZoneID }) {
            return
        }
        let zone = CKRecordZone(zoneID: ownedZoneID)
        let result = try await privateDatabase.modifyRecordZones(saving: [zone], deleting: [])
        try validate(result.saveResults)
    }

    private func replaceOwnedContent(
        content: SharedContentConfiguration,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws {
        let plan = CalendarSharingContentReconciliationPlan(content: content)
        try await replaceOwnedEventRecords(plan.eventsToSave(events))
        try await replaceOwnedShiftRecords(plan.shiftsToSave(shifts))
        try await replaceOwnedWorkRecords(plan.workRecordsToSave(workRecords))
    }

    private func replaceOwnedEventRecords(_ snapshots: [SharedEventSnapshot]) async throws {
        let existingRecords = try await recordsAllowingMissingRecordType(
            recordType: CalendarSharingCloudSchema.eventRecordType,
            queryStage: "query_owned_events",
            zoneID: ownedZoneID,
            database: privateDatabase
        )
        let existingByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.recordID, $0) })
        let calendarID = CKRecord.ID(
            recordName: CalendarSharingCloudSchema.calendarRecordName,
            zoneID: ownedZoneID
        )

        let recordsToSave = snapshots.map { snapshot -> CKRecord in
            let recordID = sharedEventRecordID(snapshot.id, zoneID: ownedZoneID)
            let record = existingByID[recordID]
                ?? CKRecord(recordType: CalendarSharingCloudSchema.eventRecordType, recordID: recordID)
            record.parent = CKRecord.Reference(recordID: calendarID, action: .none)
            record[CalendarSharingCloudSchema.EventField.eventID] = snapshot.id.uuidString as CKRecordValue
            record[CalendarSharingCloudSchema.EventField.title] = snapshot.title as CKRecordValue
            record[CalendarSharingCloudSchema.EventField.startDate] = snapshot.startDate as CKRecordValue
            record[CalendarSharingCloudSchema.EventField.endDate] = snapshot.endDate as CKRecordValue
            record[CalendarSharingCloudSchema.EventField.isAllDay] = NSNumber(value: snapshot.isAllDay)
            record[CalendarSharingCloudSchema.EventField.updatedAt] = snapshot.updatedAt as CKRecordValue
            return record
        }

        let desiredRecordIDs = Set(recordsToSave.map(\.recordID))
        let recordIDsToDelete = existingRecords
            .map(\.recordID)
            .filter { !desiredRecordIDs.contains($0) }

        for batch in recordsToSave.chunked(maxCount: 200) {
            let result = try await privateDatabase.modifyRecords(
                saving: batch,
                deleting: [],
                savePolicy: .changedKeys,
                atomically: false
            )
            try validate(result.saveResults)
        }
        for batch in recordIDsToDelete.chunked(maxCount: 200) {
            let result = try await privateDatabase.modifyRecords(
                saving: [],
                deleting: batch,
                savePolicy: .ifServerRecordUnchanged,
                atomically: false
            )
            try validate(result.deleteResults)
        }
    }

    private func replaceOwnedShiftRecords(_ snapshots: [SharedShiftSnapshot]) async throws {
        let existingRecords = try await recordsAllowingMissingRecordType(
            recordType: CalendarSharingCloudSchema.shiftRecordType,
            queryStage: "query_owned_shifts",
            zoneID: ownedZoneID,
            database: privateDatabase
        )
        let existingByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.recordID, $0) })
        let calendarID = CKRecord.ID(
            recordName: CalendarSharingCloudSchema.calendarRecordName,
            zoneID: ownedZoneID
        )
        let recordsToSave = snapshots.map { snapshot -> CKRecord in
            let recordID = sharedShiftRecordID(snapshot.id, zoneID: ownedZoneID)
            let record = existingByID[recordID]
                ?? CKRecord(recordType: CalendarSharingCloudSchema.shiftRecordType, recordID: recordID)
            record.parent = CKRecord.Reference(recordID: calendarID, action: .none)
            record[CalendarSharingCloudSchema.ShiftField.shiftID] = snapshot.id.uuidString as CKRecordValue
            record[CalendarSharingCloudSchema.ShiftField.registeredDate] = snapshot.registeredDate as CKRecordValue
            record[CalendarSharingCloudSchema.ShiftField.displayName] = snapshot.displayName as CKRecordValue
            record[CalendarSharingCloudSchema.ShiftField.startDate] = snapshot.startDate as CKRecordValue
            record[CalendarSharingCloudSchema.ShiftField.endDate] = snapshot.endDate as CKRecordValue
            record[CalendarSharingCloudSchema.ShiftField.spansMidnight] = NSNumber(value: snapshot.spansMidnight)
            record[CalendarSharingCloudSchema.ShiftField.colorHex] = snapshot.colorHex as CKRecordValue
            record[CalendarSharingCloudSchema.ShiftField.updatedAt] = snapshot.updatedAt as CKRecordValue
            return record
        }
        try await saveAndDelete(recordsToSave: recordsToSave, existingRecords: existingRecords)
    }

    private func replaceOwnedWorkRecords(_ snapshots: [SharedWorkRecordSnapshot]) async throws {
        let existingRecords = try await recordsAllowingMissingRecordType(
            recordType: CalendarSharingCloudSchema.workRecordType,
            queryStage: "query_owned_work_records",
            zoneID: ownedZoneID,
            database: privateDatabase
        )
        let existingByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.recordID, $0) })
        let calendarID = CKRecord.ID(
            recordName: CalendarSharingCloudSchema.calendarRecordName,
            zoneID: ownedZoneID
        )
        let recordsToSave = snapshots.map { snapshot -> CKRecord in
            let recordID = sharedWorkRecordID(snapshot.id, zoneID: ownedZoneID)
            let record = existingByID[recordID]
                ?? CKRecord(recordType: CalendarSharingCloudSchema.workRecordType, recordID: recordID)
            record.parent = CKRecord.Reference(recordID: calendarID, action: .none)
            record[CalendarSharingCloudSchema.WorkRecordField.workRecordID] = snapshot.id.uuidString as CKRecordValue
            record[CalendarSharingCloudSchema.WorkRecordField.workDate] = snapshot.workDate as CKRecordValue
            record[CalendarSharingCloudSchema.WorkRecordField.workInTime] = snapshot.workInTime as CKRecordValue?
            record[CalendarSharingCloudSchema.WorkRecordField.workOutTime] = snapshot.workOutTime as CKRecordValue?
            record[CalendarSharingCloudSchema.WorkRecordField.isWorkOutTimeSet] = NSNumber(value: snapshot.isWorkOutTimeSet)
            record[CalendarSharingCloudSchema.WorkRecordField.restHours] = NSNumber(value: snapshot.restHours)
            record[CalendarSharingCloudSchema.WorkRecordField.updatedAt] = snapshot.updatedAt as CKRecordValue
            return record
        }
        try await saveAndDelete(recordsToSave: recordsToSave, existingRecords: existingRecords)
    }

    private func saveAndDelete(
        recordsToSave: [CKRecord],
        existingRecords: [CKRecord]
    ) async throws {
        let desiredRecordIDs = Set(recordsToSave.map(\.recordID))
        let recordIDsToDelete = existingRecords
            .map(\.recordID)
            .filter { !desiredRecordIDs.contains($0) }

        for batch in recordsToSave.chunked(maxCount: 200) {
            let result = try await privateDatabase.modifyRecords(
                saving: batch,
                deleting: [],
                savePolicy: .changedKeys,
                atomically: false
            )
            try validate(result.saveResults)
        }
        for batch in recordIDsToDelete.chunked(maxCount: 200) {
            let result = try await privateDatabase.modifyRecords(
                saving: [],
                deleting: batch,
                savePolicy: .ifServerRecordUnchanged,
                atomically: false
            )
            try validate(result.deleteResults)
        }
    }

    private func accountStatusName(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: "available"
        case .noAccount: "noAccount"
        case .restricted: "restricted"
        case .couldNotDetermine: "couldNotDetermine"
        case .temporarilyUnavailable: "temporarilyUnavailable"
        @unknown default: "unknown"
        }
    }

    private func optionalRecord(_ id: CKRecord.ID, database: CKDatabase) async throws -> CKRecord? {
        do {
            let results = try await database.records(for: [id])
            guard let result = results[id] else { return nil }
            return try result.get()
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }

    private func allRecords(
        recordType: String,
        zoneID: CKRecordZone.ID,
        database: CKDatabase
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        var response = try await database.records(matching: query, inZoneWith: zoneID)
        var records = try response.matchResults.map { try $0.1.get() }

        while let cursor = response.queryCursor {
            response = try await database.records(continuingMatchFrom: cursor)
            records.append(contentsOf: try response.matchResults.map { try $0.1.get() })
        }
        return records
    }

    private func allSharedRecordsFromZoneChanges(
        zoneID: CKRecordZone.ID
    ) async throws -> SharedZoneRecordCollection {
        var records = SharedZoneRecordCollection()
        var changeToken: CKServerChangeToken?
        var restartedAfterExpiredToken = false

        CalendarSharingDiagnostics.debug(
            operation: "refreshSharedCalendars",
            stage: "fetch_zone_changes_started",
            database: "shared",
            details: "zone=\(zoneID.zoneName) previousToken=false"
        )

        while true {
            do {
                let response = try await sharedDatabase.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: changeToken
                )
                let changedRecords = try response.modificationResultsByID.values.map {
                    try $0.get().record
                }
                records.apply(changedRecords)
                for deletion in response.deletions {
                    records.remove(deletion.recordID)
                }
                changeToken = response.changeToken

                CalendarSharingDiagnostics.debug(
                    operation: "refreshSharedCalendars",
                    stage: "fetch_zone_changes_completed",
                    database: "shared",
                    details: "zone=\(zoneID.zoneName) changed=\(changedRecords.count) deleted=\(response.deletions.count) recordCount=\(records.recordsByID.count) moreComing=\(response.moreComing)"
                )
                if !response.moreComing {
                    return records
                }
            } catch {
                if CalendarSharingErrorMapper.shouldRestartZoneChangesFromBeginning(
                    error,
                    alreadyRetried: restartedAfterExpiredToken
                ) {
                    restartedAfterExpiredToken = true
                    changeToken = nil
                    records = SharedZoneRecordCollection()
                    CalendarSharingDiagnostics.error(
                        operation: "refreshSharedCalendars",
                        stage: "fetch_zone_changes_restart",
                        database: "shared",
                        error: error,
                        details: "zone=\(zoneID.zoneName) restartFromBeginning=true"
                    )
                    continue
                }
                CalendarSharingDiagnostics.error(
                    operation: "refreshSharedCalendars",
                    stage: "fetch_zone_changes_failed",
                    database: "shared",
                    error: error,
                    details: "zone=\(zoneID.zoneName)"
                )
                throw error
            }
        }
    }

    private func logSharedRecordClassification(
        _ records: SharedZoneRecordCollection,
        zoneID: CKRecordZone.ID
    ) {
        let stages: [(String, CKRecord.RecordType)] = [
            ("fetch_shared_calendar", CalendarSharingCloudSchema.calendarRecordType),
            ("fetch_shared_events", CalendarSharingCloudSchema.eventRecordType),
            ("fetch_shared_shifts", CalendarSharingCloudSchema.shiftRecordType),
            ("fetch_shared_work_records", CalendarSharingCloudSchema.workRecordType),
            ("fetch_zone_share", CKRecord.SystemType.share)
        ]
        for (stage, recordType) in stages {
            CalendarSharingDiagnostics.debug(
                operation: "refreshSharedCalendars",
                stage: "\(stage)_started",
                database: "shared",
                details: "recordType=\(recordType) zone=\(zoneID.zoneName)"
            )
            CalendarSharingDiagnostics.debug(
                operation: "refreshSharedCalendars",
                stage: "\(stage)_completed",
                database: "shared",
                details: "recordType=\(recordType) recordCount=\(records.records(ofType: recordType).count) zone=\(zoneID.zoneName)"
            )
        }
    }

    private func recordsAllowingMissingRecordType(
        recordType: String,
        queryStage: String,
        zoneID: CKRecordZone.ID,
        database: CKDatabase
    ) async throws -> [CKRecord] {
        do {
            return try await allRecords(recordType: recordType, zoneID: zoneID, database: database)
        } catch where CalendarSharingErrorMapper.shouldTreatMissingQueriedRecordTypeAsEmpty(error) {
            CalendarSharingDiagnostics.debug(
                operation: queryStage,
                stage: "missing_record_type",
                database: database.databaseScope == .shared ? "shared" : "private",
                details: "recordType=\(recordType) treatedAsEmpty=true"
            )
            return []
        }
    }

    private func sharedEventRecordID(_ id: UUID, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "event-\(id.uuidString.lowercased())", zoneID: zoneID)
    }

    private func sharedShiftRecordID(_ id: UUID, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "shift-\(id.uuidString.lowercased())", zoneID: zoneID)
    }

    private func sharedWorkRecordID(_ id: UUID, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "work-\(id.uuidString.lowercased())", zoneID: zoneID)
    }

    private func participantCount(in share: CKShare) -> Int {
        share.participants.filter {
            $0.role != .owner && $0.acceptanceStatus != .removed
        }.count
    }

    private func validate<Key, Value>(_ results: [Key: Result<Value, Error>]) throws {
        for result in results.values {
            _ = try result.get()
        }
    }
}

private extension Array {
    func chunked(maxCount: Int) -> [[Element]] {
        guard !isEmpty else { return [] }
        return stride(from: 0, to: count, by: maxCount).map { start in
            Array(self[start..<Swift.min(start + maxCount, count)])
        }
    }
}
