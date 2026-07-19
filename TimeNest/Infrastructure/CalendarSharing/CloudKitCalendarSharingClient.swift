import CloudKit
import CryptoKit
import Foundation
import OSLog

enum CalendarSharingPersonNameFormatter {
    static func displayName(
        from components: PersonNameComponents?,
        locale: Locale = .current
    ) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.locale = locale
        formatter.style = .default
        let value = formatter.string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

@MainActor
struct CloudKitCurrentUserDisplayNameProvider {
    private let fetchNameComponents: () async throws -> PersonNameComponents?

    init(container: CKContainer) {
        fetchNameComponents = {
            let recordID = try await container.userRecordID()
            let participant = try await container.shareParticipant(forUserRecordID: recordID)
            return participant.userIdentity.nameComponents
        }
    }

    init(fetchNameComponents: @escaping () async throws -> PersonNameComponents?) {
        self.fetchNameComponents = fetchNameComponents
    }

    func displayName(locale: Locale = .current) async -> String? {
        do {
            return CalendarSharingPersonNameFormatter.displayName(
                from: try await fetchNameComponents(),
                locale: locale
            )
        } catch {
            return nil
        }
    }
}

struct AcceptedSharedCalendarCloudResult {
    let zoneName: String
    let ownerDisplayName: String?
}

struct ReceivedSharedCalendarPayload {
    let calendar: SharedCalendarDescriptor
    let events: [SharedEventSnapshot]
    let shifts: [SharedShiftSnapshot]
    let workRecords: [SharedWorkRecordSnapshot]
}

struct SharedZoneRecordCollection {
    private(set) var recordsByID: [CKRecord.ID: CKRecord] = [:]

    mutating func apply(_ records: [CKRecord]) {
        records.forEach { recordsByID[$0.recordID] = $0 }
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
        let share = records.records(ofType: CKRecord.SystemType.share).first as? CKShare
        guard let root = records.records(
            ofType: CalendarSharingCloudSchema.calendarRecordType
        ).first,
        let calendar = CalendarSharingCloudSchema.receivedDescriptor(
            from: root,
            zoneID: zoneID,
            ownerDisplayName: CalendarSharingPersonNameFormatter.displayName(
                from: share?.owner.userIdentity.nameComponents
            ),
            participantCount: share.map(participantCount(in:)) ?? 0
        ) else {
            return nil
        }

        return ReceivedSharedCalendarPayload(
            calendar: calendar,
            events: records.records(ofType: CalendarSharingCloudSchema.eventRecordType)
                .compactMap(decodeEvent),
            shifts: records.records(ofType: CalendarSharingCloudSchema.shiftRecordType)
                .compactMap(decodeShift),
            workRecords: records.records(ofType: CalendarSharingCloudSchema.workRecordType)
                .compactMap(decodeWorkRecord)
        )
    }

    static func decodeEvent(_ record: CKRecord) -> SharedEventSnapshot? {
        guard let idValue = record[CalendarSharingCloudSchema.EventField.eventID] as? String,
              let id = UUID(uuidString: idValue),
              let title = record[CalendarSharingCloudSchema.EventField.title] as? String,
              let startDate = record[CalendarSharingCloudSchema.EventField.startDate] as? Date,
              let endDate = record[CalendarSharingCloudSchema.EventField.endDate] as? Date,
              let allDay = record[CalendarSharingCloudSchema.EventField.isAllDay] as? NSNumber,
              let updatedAt = record[CalendarSharingCloudSchema.EventField.updatedAt] as? Date else {
            return nil
        }
        return SharedEventSnapshot(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: allDay.boolValue,
            updatedAt: updatedAt
        )
    }

    static func decodeShift(_ record: CKRecord) -> SharedShiftSnapshot? {
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

    static func decodeWorkRecord(_ record: CKRecord) -> SharedWorkRecordSnapshot? {
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
            $0.role != .owner && $0.acceptanceStatus == .accepted
        }.count
    }
}

struct OwnedSharedCalendarCloudState {
    let calendar: OwnedSharedCalendarDescriptor
    let share: CKShare
    let participants: [SharedCalendarParticipantSnapshot]
}

struct OwnedSharingInvitationResult {
    let state: OwnedSharedCalendarCloudState
    let invitationURL: URL?
    let participantID: CKShare.Participant.ID
}

enum OwnedSharingInvitationResultFactory {
    static func make(
        state: OwnedSharedCalendarCloudState,
        invitation: OneTimeSharingInvitation,
        resolveURL: (CKShare, CKShare.Participant.ID) -> URL? = {
            $0.__oneTimeURL(forParticipantID: $1)
        }
    ) -> OwnedSharingInvitationResult {
        OwnedSharingInvitationResult(
            state: state,
            invitationURL: resolveURL(state.share, invitation.participantID),
            participantID: invitation.participantID
        )
    }
}

struct CalendarSharingInvitation: Identifiable {
    let id: String
    let calendarID: UUID
    let url: URL
}

enum SharingInvitationActivityOutcome: Equatable {
    case completed
    case cancelled
    case activityError
}

struct OneTimeSharingInvitation {
    let participantID: CKShare.Participant.ID

    static func prepare(on share: CKShare) -> OneTimeSharingInvitation {
        share.publicPermission = .none
        let participant = CKShare.Participant.oneTimeURLParticipant()
        participant.permission = .readOnly
        share.addParticipant(participant)
        return OneTimeSharingInvitation(participantID: participant.participantID)
    }

    func url(in savedShare: CKShare) -> URL? {
        savedShare.__oneTimeURL(forParticipantID: participantID)
    }
}

enum OwnedCalendarParticipantSnapshotAssembler {
    static func make(from share: CKShare) -> [SharedCalendarParticipantSnapshot] {
        share.participants.compactMap { participant in
            guard participant.role != .owner else { return nil }
            let name = CalendarSharingPersonNameFormatter.displayName(
                from: participant.userIdentity.nameComponents
            )
            let email = participant.userIdentity.lookupInfo?.emailAddress
            let isAccepted = participant.acceptanceStatus == .accepted
            return SharedCalendarParticipantSnapshot(
                id: participantSnapshotID(participant.participantID),
                displayName: normalized(name) ?? normalized(email),
                isAccepted: isAccepted,
                permission: permission(participant.permission),
                revocationToken: isAccepted ? nil : participant.participantID
            )
        }
    }

    static func participantSnapshotID(_ participantID: CKShare.Participant.ID) -> String {
        SHA256.hash(data: Data(participantID.utf8))
            .prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static func normalized(_ value: String?) -> String? {
        let value = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private static func permission(
        _ value: CKShare.ParticipantPermission
    ) -> SharedCalendarParticipantPermission {
        switch value {
        case .unknown: .unknown
        case .none: .none
        case .readOnly: .readOnly
        case .readWrite: .readWrite
        @unknown default: .unknown
        }
    }
}

struct CalendarSharingContentRecordPlan {
    let recordType: CKRecord.RecordType
    let legacyRecordIDsToDelete: [CKRecord.ID]
    let recordsToRecreate: [CKRecord]
    let recordsToSave: [CKRecord]
    let ordinaryRecordIDsToDelete: [CKRecord.ID]

    init<Snapshot>(
        recordType: CKRecord.RecordType,
        existingRecords: [CKRecord],
        snapshots: [Snapshot],
        recordID: (Snapshot) -> CKRecord.ID,
        makeRecord: (Snapshot, CKRecord.ID, CKRecord?) -> CKRecord
    ) {
        self.recordType = recordType
        let snapshotsByID = Dictionary(
            snapshots.map { (recordID($0), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let existingByID = Dictionary(
            existingRecords.map { ($0.recordID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let desiredIDs = Set(snapshotsByID.keys)

        legacyRecordIDsToDelete = existingRecords.filter { $0.parent != nil }.map(\.recordID)
        ordinaryRecordIDsToDelete = existingRecords
            .filter { $0.parent == nil && !desiredIDs.contains($0.recordID) }
            .map(\.recordID)
        recordsToRecreate = desiredIDs.compactMap { id in
            guard existingByID[id]?.parent != nil, let snapshot = snapshotsByID[id] else { return nil }
            return makeRecord(snapshot, id, nil)
        }
        recordsToSave = desiredIDs.compactMap { id in
            guard existingByID[id]?.parent == nil, let snapshot = snapshotsByID[id] else { return nil }
            return makeRecord(snapshot, id, existingByID[id])
        }
    }
}

@MainActor
protocol CalendarSharingContentRecordDatabase {
    func save(_ records: [CKRecord]) async throws
    func delete(_ recordIDs: [CKRecord.ID]) async throws
}

@MainActor
private struct CloudKitContentRecordDatabase: CalendarSharingContentRecordDatabase {
    let database: CKDatabase

    func save(_ records: [CKRecord]) async throws {
        var pending = records
        var attempt = 0
        while !pending.isEmpty {
            attempt += 1
            do {
                let result = try await database.modifyRecords(
                    saving: pending,
                    deleting: [],
                    savePolicy: .changedKeys,
                    atomically: false
                )
                let pendingByID = Dictionary(uniqueKeysWithValues: pending.map { ($0.recordID, $0) })
                var retry: [CKRecord] = []
                for (recordID, result) in result.saveResults {
                    do {
                        _ = try result.get()
                    } catch where CalendarSharingErrorMapper.isRetryable(error) && attempt < 3 {
                        if let record = pendingByID[recordID] { retry.append(record) }
                    } catch {
                        throw error
                    }
                }
                pending = retry
            } catch where CalendarSharingErrorMapper.isRetryable(error) && attempt < 3 {
                // Retry the still-pending batch. CloudKit operations are idempotent by Record ID.
            }
            if !pending.isEmpty {
                try await Task.sleep(for: .milliseconds(250 * attempt))
            }
        }
    }

    func delete(_ recordIDs: [CKRecord.ID]) async throws {
        var pending = recordIDs
        var attempt = 0
        while !pending.isEmpty {
            attempt += 1
            do {
                let result = try await database.modifyRecords(
                    saving: [],
                    deleting: pending,
                    savePolicy: .ifServerRecordUnchanged,
                    atomically: false
                )
                var retry: [CKRecord.ID] = []
                for (recordID, result) in result.deleteResults {
                    do {
                        _ = try result.get()
                    } catch let error as CKError where error.code == .unknownItem {
                        continue
                    } catch where CalendarSharingErrorMapper.isRetryable(error) && attempt < 3 {
                        retry.append(recordID)
                    } catch {
                        throw error
                    }
                }
                pending = retry
            } catch where CalendarSharingErrorMapper.isRetryable(error) && attempt < 3 {
                // Retry the still-pending IDs.
            }
            if !pending.isEmpty {
                try await Task.sleep(for: .milliseconds(250 * attempt))
            }
        }
    }
}

@MainActor
struct CalendarSharingContentRecordPlanExecutor {
    let database: any CalendarSharingContentRecordDatabase

    func execute(_ plan: CalendarSharingContentRecordPlan) async throws {
        for batch in plan.legacyRecordIDsToDelete.chunked(maxCount: 200) {
            try await database.delete(batch)
        }
        for batch in plan.recordsToRecreate.chunked(maxCount: 200) {
            try await database.save(batch)
        }
        for batch in plan.recordsToSave.chunked(maxCount: 200) {
            try await database.save(batch)
        }
        for batch in plan.ordinaryRecordIDsToDelete.chunked(maxCount: 200) {
            try await database.delete(batch)
        }
    }
}

@MainActor
protocol CalendarSharingClientProtocol {
    func iCloudAccountStatus() async -> CalendarSharingICloudStatus
    func currentUserDisplayName() async -> String?
    func fetchShareMetadata(
        from url: URL
    ) async throws -> any CalendarSharingShareMetadata
    func fetchOwnedCalendars() async throws -> [OwnedSharedCalendarCloudState]
    func createShare(
        calendarID: UUID,
        calendarName: String,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharingInvitationResult
    func createInvitation(for calendar: OwnedSharedCalendarDescriptor) async throws -> OwnedSharingInvitationResult
    func revokePendingInvitation(
        for calendar: OwnedSharedCalendarDescriptor,
        participantID: CKShare.Participant.ID
    ) async throws -> OwnedSharedCalendarCloudState
    func synchronizeOwnedContent(
        calendar: OwnedSharedCalendarDescriptor,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws
    func renameOwnedCalendar(_ calendar: OwnedSharedCalendarDescriptor, name: String) async throws
    func fetchReceivedCalendars() async throws -> [ReceivedSharedCalendarPayload]
    func accept(
        metadata: any CalendarSharingShareMetadata
    ) async throws -> AcceptedSharedCalendarCloudResult
    func leaveSharedCalendar(_ calendar: SharedCalendarDescriptor) async throws
    func stopOwnedSharing(_ calendar: OwnedSharedCalendarDescriptor) async throws
}

extension CalendarSharingClientProtocol {
    func iCloudAccountStatus() async -> CalendarSharingICloudStatus {
        .available
    }
}

protocol CalendarSharingShareMetadata {
    var containerIdentifier: String { get }
    var participantStatus: CKShare.ParticipantAcceptanceStatus { get }
    var share: CKShare { get }
    var ownerNameComponents: PersonNameComponents? { get }
}

extension CKShare.Metadata: CalendarSharingShareMetadata {
    var ownerNameComponents: PersonNameComponents? {
        ownerIdentity.nameComponents
    }
}

enum CalendarSharingContainerValidator {
    static func validate(
        metadataContainerIdentifier: String,
        configuredContainerIdentifier: String?
    ) throws {
        guard let configuredContainerIdentifier,
              metadataContainerIdentifier == configuredContainerIdentifier else {
            throw CalendarSharingError.cloudEnvironmentMismatch
        }
    }
}

enum CalendarSharingParticipantStatusValidator {
    static func error(
        for status: CKShare.ParticipantAcceptanceStatus
    ) -> CalendarSharingError? {
        switch status {
        case .accepted, .pending:
            nil
        case .removed:
            .invitationRevoked
        case .unknown:
            .invitationInvalid
        @unknown default:
            .invitationInvalid
        }
    }
}

enum CalendarSharingErrorContext: Equatable {
    case general
    case creatingShare
    case creatingInvitation
    case fetchingInvitationMetadata
    case acceptingInvitation
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
        let detailText = details()
        let errorText = CalendarSharingErrorMapper.diagnosticSummary(error)
        logger.error(
            "operation=\(operation, privacy: .public) stage=\(stage, privacy: .public) database=\(database, privacy: .public) \(detailText, privacy: .public) \(errorText, privacy: .public)"
        )
#endif
    }

    static func identifierHash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func recordHash(_ recordID: CKRecord.ID) -> String {
        return identifierHash(
            [
                recordID.recordName,
                recordID.zoneID.zoneName,
                recordID.zoneID.ownerName
            ].joined(separator: "|")
        )
    }

    static func metadataHash(_ metadata: any CalendarSharingShareMetadata) -> String {
        let participantIDs = metadata.share.participants
            .map(\.participantID)
            .sorted()
            .joined(separator: "|")
        return identifierHash(
            [
                metadata.containerIdentifier,
                metadata.share.recordID.recordName,
                metadata.share.recordID.zoneID.zoneName,
                metadata.share.recordID.zoneID.ownerName,
                participantIDs
            ].joined(separator: "|")
        )
    }

    static func urlHash(_ url: URL) -> String {
        identifierHash(url.absoluteString)
    }
}

enum CalendarSharingCloudSchema {
    static let zoneNamePrefix = "TimeNestSharedCalendar."
    static let calendarRecordType = "SharedCalendar"
    static let eventRecordType = "SharedEvent"
    static let shiftRecordType = "SharedShift"
    static let workRecordType = "SharedWorkRecord"
    static let calendarRecordName = "calendar"
    static let schemaVersion = 3

    enum CalendarField {
        static let calendarID = "calendarID"
        static let calendarName = "calendarName"
        static let updatedAt = "updatedAt"
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

    static func zoneName(for calendarID: UUID) -> String {
        zoneNamePrefix + calendarID.uuidString.lowercased()
    }

    static func calendarID(from zoneName: String) -> UUID? {
        guard zoneName.hasPrefix(zoneNamePrefix) else { return nil }
        return UUID(uuidString: String(zoneName.dropFirst(zoneNamePrefix.count)))
    }

    static func apply(calendarID: UUID, name: String, to record: CKRecord) {
        record[CalendarField.calendarID] = calendarID.uuidString as CKRecordValue
        record[CalendarField.calendarName] = name as CKRecordValue
        record[CalendarField.updatedAt] = Date() as CKRecordValue
        record[CalendarField.schemaVersion] = NSNumber(value: schemaVersion)
    }

    static func receivedDescriptor(
        from root: CKRecord,
        zoneID: CKRecordZone.ID,
        ownerDisplayName: String?,
        participantCount: Int
    ) -> SharedCalendarDescriptor? {
        guard let idValue = root[CalendarField.calendarID] as? String,
              let id = UUID(uuidString: idValue),
              let name = normalizedName(root[CalendarField.calendarName] as? String) else {
            return nil
        }
        return SharedCalendarDescriptor(
            id: id,
            zoneName: zoneID.zoneName,
            ownerName: zoneID.ownerName,
            ownerDisplayName: ownerDisplayName,
            calendarName: name,
            participantCount: participantCount,
            kind: .sharedReceived,
            rootRecordName: root.recordID.recordName,
            shareRecordName: CKRecordNameZoneWideShare
        )
    }

    static func normalizedName(_ value: String?) -> String? {
        let value = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}

enum CalendarSharingCloudRecordFactory {
    static func makeEventRecord(
        snapshot: SharedEventSnapshot,
        recordID: CKRecord.ID,
        existingRecord: CKRecord? = nil
    ) -> CKRecord {
        let record = contentRecord(
            type: CalendarSharingCloudSchema.eventRecordType,
            id: recordID,
            existing: existingRecord
        )
        record[CalendarSharingCloudSchema.EventField.eventID] = snapshot.id.uuidString as CKRecordValue
        record[CalendarSharingCloudSchema.EventField.title] = snapshot.title as CKRecordValue
        record[CalendarSharingCloudSchema.EventField.startDate] = snapshot.startDate as CKRecordValue
        record[CalendarSharingCloudSchema.EventField.endDate] = snapshot.endDate as CKRecordValue
        record[CalendarSharingCloudSchema.EventField.isAllDay] = NSNumber(value: snapshot.isAllDay)
        record[CalendarSharingCloudSchema.EventField.updatedAt] = snapshot.updatedAt as CKRecordValue
        return record
    }

    static func makeShiftRecord(
        snapshot: SharedShiftSnapshot,
        recordID: CKRecord.ID,
        existingRecord: CKRecord? = nil
    ) -> CKRecord {
        let record = contentRecord(
            type: CalendarSharingCloudSchema.shiftRecordType,
            id: recordID,
            existing: existingRecord
        )
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

    static func makeWorkRecord(
        snapshot: SharedWorkRecordSnapshot,
        recordID: CKRecord.ID,
        existingRecord: CKRecord? = nil
    ) -> CKRecord {
        let record = contentRecord(
            type: CalendarSharingCloudSchema.workRecordType,
            id: recordID,
            existing: existingRecord
        )
        record[CalendarSharingCloudSchema.WorkRecordField.workRecordID] = snapshot.id.uuidString as CKRecordValue
        record[CalendarSharingCloudSchema.WorkRecordField.workDate] = snapshot.workDate as CKRecordValue
        record[CalendarSharingCloudSchema.WorkRecordField.workInTime] = snapshot.workInTime as CKRecordValue?
        record[CalendarSharingCloudSchema.WorkRecordField.workOutTime] = snapshot.workOutTime as CKRecordValue?
        record[CalendarSharingCloudSchema.WorkRecordField.isWorkOutTimeSet] = NSNumber(value: snapshot.isWorkOutTimeSet)
        record[CalendarSharingCloudSchema.WorkRecordField.restHours] = NSNumber(value: snapshot.restHours)
        record[CalendarSharingCloudSchema.WorkRecordField.updatedAt] = snapshot.updatedAt as CKRecordValue
        return record
    }

    static func makeZoneWideShare(recordZoneID: CKRecordZone.ID) -> CKShare {
        CKShare(recordZoneID: recordZoneID)
    }

    private static func contentRecord(
        type: CKRecord.RecordType,
        id: CKRecord.ID,
        existing: CKRecord?
    ) -> CKRecord {
        guard let existing,
              existing.recordID == id,
              existing.recordType == type,
              existing.parent == nil else {
            return CKRecord(recordType: type, recordID: id)
        }
        return existing
    }
}

enum CalendarSharingErrorMapper {
    static func map(
        _ error: Error,
        context: CalendarSharingErrorContext = .general
    ) -> CalendarSharingError {
        let codes = cloudErrors(in: error).map(\.code)
        if codes.contains(.notAuthenticated) { return .noICloudAccount }
        if codes.contains(.missingEntitlement) || codes.contains(.badContainer)
            || codes.contains(.managedAccountRestricted) { return .iCloudRestricted }
        if codes.contains(.permissionFailure) { return .permissionDenied }
        if codes.contains(.participantMayNeedVerification) { return .invitationPending }
        if context == .fetchingInvitationMetadata {
            if codes.contains(where: invitationUnavailableCodes.contains) {
                return .invitationUnavailable
            }
            if codes.contains(where: networkCodes.contains) {
                return .networkUnavailable
            }
            if codes.contains(where: serviceUnavailableCodes.contains) {
                return .serviceTemporarilyUnavailable
            }
            return .metadataFetchFailed
        }
        if codes.contains(where: networkCodes.contains) { return .networkUnavailable }
        if codes.contains(where: serviceUnavailableCodes.contains) {
            return .serviceTemporarilyUnavailable
        }
        if context == .acceptingInvitation,
           codes.contains(where: { $0 == .unknownItem || $0 == .userDeletedZone || $0 == .zoneNotFound }) {
            return .invitationRevoked
        }
        switch context {
        case .general: return .syncFailed
        case .creatingShare: return .shareCreationFailed
        case .creatingInvitation: return .invitationCreationFailed
        case .fetchingInvitationMetadata: return .metadataFetchFailed
        case .acceptingInvitation: return .invitationAcceptanceFailed
        }
    }

    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || cloudErrors(in: error).contains { $0.code == .operationCancelled }
    }

    static func isRetryable(_ error: Error) -> Bool {
        cloudErrors(in: error).contains { retryableCodes.contains($0.code) }
    }

    static func isMissingOrInaccessibleSharedZone(_ error: Error) -> Bool {
        let codes = cloudErrors(in: error).map(\.code).filter { $0 != .partialFailure }
        return !codes.isEmpty && codes.allSatisfy { $0 == .unknownItem || $0 == .userDeletedZone || $0 == .zoneNotFound }
    }

    static func cloudErrorCodes(in error: Error) -> [CKError.Code] {
        cloudErrors(in: error).map(\.code)
    }

    static func shouldRestartZoneChangesFromBeginning(_ error: Error, alreadyRetried: Bool) -> Bool {
        !alreadyRetried && cloudErrorCodes(in: error).contains(.changeTokenExpired)
    }

    static func diagnosticSummary(_ error: Error) -> String {
        let nsError = error as NSError
        let codes = Set(cloudErrorCodes(in: error).map(\.rawValue)).sorted()
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        let underlyingDomain = underlying?.domain ?? "none"
        let underlyingCode = underlying?.code ?? 0
        let retryAfter = cloudErrors(in: error)
            .compactMap { $0.userInfo[CKErrorRetryAfterKey] as? NSNumber }
            .map(\.doubleValue)
            .first
        let retryAfterText = retryAfter.map { String($0) } ?? "none"
        return "errorDomain=\(nsError.domain) errorCode=\(nsError.code) "
            + "underlyingErrorDomain=\(underlyingDomain) underlyingErrorCode=\(underlyingCode) "
            + "ckErrorCodes=\(codes) retryAfterSeconds=\(retryAfterText) serverMessage=omitted"
    }

    private static let invitationUnavailableCodes: Set<CKError.Code> = [
        .unknownItem, .userDeletedZone, .zoneNotFound
    ]

    private static let networkCodes: Set<CKError.Code> = [
        .networkUnavailable, .networkFailure, .serverResponseLost
    ]

    private static let serviceUnavailableCodes: Set<CKError.Code> = [
        .accountTemporarilyUnavailable, .serviceUnavailable,
        .requestRateLimited, .zoneBusy
    ]

    private static let retryableCodes = networkCodes.union(serviceUnavailableCodes)

    private static func cloudErrors(in error: Error) -> [CKError] {
        guard let cloudError = error as? CKError else { return [] }
        guard cloudError.code == .partialFailure,
              let partial = cloudError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] else {
            return [cloudError]
        }
        return [cloudError] + partial.values.flatMap(cloudErrors(in:))
    }
}

@MainActor
final class CloudKitCalendarSharingClient: CalendarSharingClientProtocol {
    let container: CKContainer
    private let currentUserDisplayNameProvider: CloudKitCurrentUserDisplayNameProvider
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private var sharedDatabase: CKDatabase { container.sharedCloudDatabase }

    init(container: CKContainer = .default()) {
        self.container = container
        currentUserDisplayNameProvider = CloudKitCurrentUserDisplayNameProvider(
            container: container
        )
    }

    func iCloudAccountStatus() async -> CalendarSharingICloudStatus {
        do {
            switch try await container.accountStatus() {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .restricted
            case .temporarilyUnavailable:
                return .temporarilyUnavailable
            case .couldNotDetermine:
                return .couldNotDetermine
            @unknown default:
                return .couldNotDetermine
            }
        } catch {
            return .requestFailed(CalendarSharingErrorMapper.map(error))
        }
    }

    func currentUserDisplayName() async -> String? {
        let displayName = await currentUserDisplayNameProvider.displayName()
        CalendarSharingDiagnostics.debug(
            operation: "currentUserDisplayName",
            stage: "completed",
            database: "container",
            details: "result=\(displayName == nil ? "unavailable" : "available")"
        )
        return displayName
    }

    func fetchShareMetadata(
        from url: URL
    ) async throws -> any CalendarSharingShareMetadata {
        let urlHash = CalendarSharingDiagnostics.urlHash(url)
        CalendarSharingDiagnostics.debug(
            operation: "fetchShareMetadata",
            stage: "started",
            database: "shared",
            details: "urlHash=\(urlHash)"
        )
        do {
            let defaultContainer = CKContainer.default()
            let metadata = try await defaultContainer.shareMetadata(for: url)
            do {
                try CalendarSharingContainerValidator.validate(
                    metadataContainerIdentifier: metadata.containerIdentifier,
                    configuredContainerIdentifier: defaultContainer.containerIdentifier
                )
            } catch CalendarSharingError.cloudEnvironmentMismatch {
                throw CalendarSharingError.invitationContainerMismatch
            }
            CalendarSharingDiagnostics.debug(
                operation: "fetchShareMetadata",
                stage: "completed",
                database: "shared",
                details: "urlHash=\(urlHash) "
                    + "metadataHash=\(CalendarSharingDiagnostics.metadataHash(metadata))"
            )
            return metadata
        } catch let error as CalendarSharingError {
            CalendarSharingDiagnostics.error(
                operation: "fetchShareMetadata",
                stage: "failed",
                database: "shared",
                error: error,
                details: "urlHash=\(urlHash)"
            )
            throw error
        } catch {
            CalendarSharingDiagnostics.error(
                operation: "fetchShareMetadata",
                stage: "failed",
                database: "shared",
                error: error,
                details: "urlHash=\(urlHash)"
            )
            throw CalendarSharingErrorMapper.map(
                error,
                context: .fetchingInvitationMetadata
            )
        }
    }

    func fetchOwnedCalendars() async throws -> [OwnedSharedCalendarCloudState] {
        try await verifyAccountAvailability()
        let zones = try await privateDatabase.allRecordZones()
        var states: [OwnedSharedCalendarCloudState] = []
        for zone in zones where CalendarSharingCloudSchema.calendarID(from: zone.zoneID.zoneName) != nil {
            if let state = try await ownedState(zoneID: zone.zoneID) {
                states.append(state)
            }
        }
        return states.sorted {
            $0.calendar.calendarName.localizedCaseInsensitiveCompare($1.calendar.calendarName) == .orderedAscending
        }
    }

    func createShare(
        calendarID: UUID,
        calendarName: String,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws -> OwnedSharingInvitationResult {
        try await verifyAccountAvailability()
        let zoneID = ownedZoneID(calendarID: calendarID)
        do {
            try await ensureZone(zoneID)
            let rootID = CKRecord.ID(
                recordName: CalendarSharingCloudSchema.calendarRecordName,
                zoneID: zoneID
            )
            let root = CKRecord(
                recordType: CalendarSharingCloudSchema.calendarRecordType,
                recordID: rootID
            )
            CalendarSharingCloudSchema.apply(calendarID: calendarID, name: calendarName, to: root)
            _ = try await save([root], in: privateDatabase, atomically: true)
            try await replaceContent(
                zoneID: zoneID,
                events: events,
                shifts: shifts,
                workRecords: workRecords
            )

            let share = CalendarSharingCloudRecordFactory.makeZoneWideShare(recordZoneID: zoneID)
            share[CKShare.SystemFieldKey.title] = calendarName as CKRecordValue
            let invitation = OneTimeSharingInvitation.prepare(on: share)
            CalendarSharingDiagnostics.debug(
                operation: "invite",
                stage: "participant-created",
                database: "private",
                details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(calendarID.uuidString)) "
                    + "zoneHash=\(CalendarSharingDiagnostics.identifierHash(zoneID.zoneName)) "
                    + "shareHash=\(CalendarSharingDiagnostics.recordHash(share.recordID)) "
                    + "participantHash=\(CalendarSharingDiagnostics.identifierHash(invitation.participantID))"
            )
            _ = try await save([share], in: privateDatabase, atomically: true)
            CalendarSharingDiagnostics.debug(
                operation: "invite",
                stage: "share-saved",
                database: "private",
                details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(calendarID.uuidString)) "
                    + "zoneHash=\(CalendarSharingDiagnostics.identifierHash(zoneID.zoneName)) "
                    + "shareHash=\(CalendarSharingDiagnostics.recordHash(share.recordID))"
            )
            guard let state = try await ownedState(zoneID: zoneID) else {
                throw CalendarSharingError.shareCreationFailed
            }
            let result = OwnedSharingInvitationResultFactory.make(
                state: state,
                invitation: invitation
            )
            CalendarSharingDiagnostics.debug(
                operation: "invite",
                stage: "share-refetched",
                database: "private",
                details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(calendarID.uuidString)) "
                    + "zoneHash=\(CalendarSharingDiagnostics.identifierHash(zoneID.zoneName)) "
                    + "shareHash=\(CalendarSharingDiagnostics.recordHash(state.share.recordID)) "
                    + "participantHash=\(CalendarSharingDiagnostics.identifierHash(invitation.participantID)) "
                    + "shareURLAvailable=\(result.invitationURL != nil)"
            )
            return result
        } catch {
            try? await deleteZone(zoneID)
            if CalendarSharingErrorMapper.isCancellation(error) { throw CancellationError() }
            if let error = error as? CalendarSharingError { throw error }
            throw CalendarSharingErrorMapper.map(error, context: .creatingShare)
        }
    }

    func createInvitation(
        for calendar: OwnedSharedCalendarDescriptor
    ) async throws -> OwnedSharingInvitationResult {
        try await verifyAccountAvailability()
        let zoneID = CKRecordZone.ID(zoneName: calendar.zoneName, ownerName: calendar.ownerName)
        let shareID = CKRecord.ID(recordName: calendar.shareRecordName, zoneID: zoneID)
        do {
            guard let share = try await optionalRecord(shareID, database: privateDatabase) as? CKShare else {
                throw CalendarSharingError.shareUnavailable
            }
            CalendarSharingDiagnostics.debug(
                operation: "invite",
                stage: "share-fetched",
                database: "private",
                details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(calendar.id.uuidString)) "
                    + "zoneHash=\(CalendarSharingDiagnostics.identifierHash(zoneID.zoneName)) "
                    + "shareHash=\(CalendarSharingDiagnostics.recordHash(share.recordID))"
            )
            let invitation = OneTimeSharingInvitation.prepare(on: share)
            CalendarSharingDiagnostics.debug(
                operation: "invite",
                stage: "participant-created",
                database: "private",
                details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(calendar.id.uuidString)) "
                    + "zoneHash=\(CalendarSharingDiagnostics.identifierHash(zoneID.zoneName)) "
                    + "shareHash=\(CalendarSharingDiagnostics.recordHash(share.recordID)) "
                    + "participantHash=\(CalendarSharingDiagnostics.identifierHash(invitation.participantID))"
            )
            _ = try await save([share], in: privateDatabase, atomically: true)
            CalendarSharingDiagnostics.debug(
                operation: "invite",
                stage: "share-saved",
                database: "private",
                details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(calendar.id.uuidString)) "
                    + "zoneHash=\(CalendarSharingDiagnostics.identifierHash(zoneID.zoneName)) "
                    + "shareHash=\(CalendarSharingDiagnostics.recordHash(share.recordID))"
            )
            guard let state = try await ownedState(zoneID: zoneID) else {
                throw CalendarSharingError.shareUnavailable
            }
            let result = OwnedSharingInvitationResultFactory.make(
                state: state,
                invitation: invitation
            )
            CalendarSharingDiagnostics.debug(
                operation: "invite",
                stage: "share-refetched",
                database: "private",
                details: "calendarHash=\(CalendarSharingDiagnostics.identifierHash(calendar.id.uuidString)) "
                    + "zoneHash=\(CalendarSharingDiagnostics.identifierHash(zoneID.zoneName)) "
                    + "shareHash=\(CalendarSharingDiagnostics.recordHash(state.share.recordID)) "
                    + "participantHash=\(CalendarSharingDiagnostics.identifierHash(invitation.participantID)) "
                    + "shareURLAvailable=\(result.invitationURL != nil)"
            )
            return result
        } catch {
            if let error = error as? CalendarSharingError { throw error }
            throw CalendarSharingErrorMapper.map(error, context: .creatingInvitation)
        }
    }

    func synchronizeOwnedContent(
        calendar: OwnedSharedCalendarDescriptor,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws {
        try await verifyAccountAvailability()
        let zoneID = CKRecordZone.ID(zoneName: calendar.zoneName, ownerName: calendar.ownerName)
        try await replaceContent(
            zoneID: zoneID,
            events: events,
            shifts: shifts,
            workRecords: workRecords
        )
    }

    func revokePendingInvitation(
        for calendar: OwnedSharedCalendarDescriptor,
        participantID: CKShare.Participant.ID
    ) async throws -> OwnedSharedCalendarCloudState {
        let zoneID = CKRecordZone.ID(zoneName: calendar.zoneName, ownerName: calendar.ownerName)
        let shareID = CKRecord.ID(recordName: calendar.shareRecordName, zoneID: zoneID)
        guard let share = try await optionalRecord(shareID, database: privateDatabase) as? CKShare else {
            throw CalendarSharingError.shareUnavailable
        }
        guard let participant = share.participants.first(where: {
            $0.participantID == participantID && $0.role != .owner
        }) else {
            guard let state = try await ownedState(zoneID: zoneID) else {
                throw CalendarSharingError.shareUnavailable
            }
            return state
        }
        guard participant.acceptanceStatus != .accepted else {
            throw CalendarSharingError.permissionDenied
        }
        share.removeParticipant(participant)
        _ = try await save([share], in: privateDatabase, atomically: true)
        guard let state = try await ownedState(zoneID: zoneID) else {
            throw CalendarSharingError.shareUnavailable
        }
        return state
    }

    func renameOwnedCalendar(
        _ calendar: OwnedSharedCalendarDescriptor,
        name: String
    ) async throws {
        let zoneID = CKRecordZone.ID(zoneName: calendar.zoneName, ownerName: calendar.ownerName)
        let rootID = CKRecord.ID(recordName: calendar.rootRecordName, zoneID: zoneID)
        guard let root = try await optionalRecord(rootID, database: privateDatabase) else {
            throw CalendarSharingError.shareUnavailable
        }
        CalendarSharingCloudSchema.apply(calendarID: calendar.id, name: name, to: root)
        let shareID = CKRecord.ID(recordName: calendar.shareRecordName, zoneID: zoneID)
        let share = try await optionalRecord(shareID, database: privateDatabase) as? CKShare
        share?[CKShare.SystemFieldKey.title] = name as CKRecordValue
        _ = try await save([root] + (share.map { [$0] } ?? []), in: privateDatabase, atomically: true)
    }

    func fetchReceivedCalendars() async throws -> [ReceivedSharedCalendarPayload] {
        try await verifyAccountAvailability()
        let zones = try await sharedDatabase.allRecordZones()
        var payloads: [ReceivedSharedCalendarPayload] = []
        for zone in zones where zone.zoneID.zoneName != CKRecordZone.default().zoneID.zoneName {
            do {
                let records = try await allRecordsFromZoneChanges(
                    zoneID: zone.zoneID,
                    database: sharedDatabase
                )
                if let payload = ReceivedSharedCalendarPayloadAssembler.makePayload(
                    zoneID: zone.zoneID,
                    records: records
                ) {
                    payloads.append(payload)
                }
            } catch where CalendarSharingErrorMapper.isMissingOrInaccessibleSharedZone(error) {
                continue
            }
        }
        return payloads.sorted {
            $0.calendar.calendarName.localizedCaseInsensitiveCompare($1.calendar.calendarName) == .orderedAscending
        }
    }

    func accept(
        metadata: any CalendarSharingShareMetadata
    ) async throws -> AcceptedSharedCalendarCloudResult {
        let containerIdentifierMatched = metadata.containerIdentifier == container.containerIdentifier
        CalendarSharingDiagnostics.debug(
            operation: "acceptShare",
            stage: "metadata-validated",
            database: "shared",
            details: "metadataHash=\(CalendarSharingDiagnostics.metadataHash(metadata)) "
                + "containerIdentifierMatched=\(containerIdentifierMatched) "
                + "shareHash=\(CalendarSharingDiagnostics.recordHash(metadata.share.recordID))"
        )
        do {
            try CalendarSharingContainerValidator.validate(
                metadataContainerIdentifier: metadata.containerIdentifier,
                configuredContainerIdentifier: container.containerIdentifier
            )
        } catch {
            CalendarSharingDiagnostics.error(
                operation: "acceptShare",
                stage: "container-mismatch",
                database: "shared",
                error: error,
                details: "metadataHash=\(CalendarSharingDiagnostics.metadataHash(metadata)) "
                    + "containerIdentifierMatched=false"
            )
            throw error
        }
        if let statusError = CalendarSharingParticipantStatusValidator.error(
            for: metadata.participantStatus
        ) {
            CalendarSharingDiagnostics.debug(
                operation: "acceptShare",
                stage: "metadata-rejected",
                database: "shared",
                details: "metadataHash=\(CalendarSharingDiagnostics.metadataHash(metadata)) "
                    + "shareHash=\(CalendarSharingDiagnostics.recordHash(metadata.share.recordID)) "
                    + "reason=\(String(describing: statusError))"
            )
            throw statusError
        }

        try await verifyAccountAvailability()
        let shareHash = CalendarSharingDiagnostics.recordHash(metadata.share.recordID)
        let ownerDisplayName = CalendarSharingPersonNameFormatter.displayName(
            from: metadata.ownerNameComponents
        )
        switch metadata.participantStatus {
        case .accepted:
            CalendarSharingDiagnostics.debug(
                operation: "acceptShare",
                stage: "already-accepted",
                database: "shared",
                details: "metadataHash=\(CalendarSharingDiagnostics.metadataHash(metadata)) "
                    + "shareHash=\(shareHash)"
            )
            return AcceptedSharedCalendarCloudResult(
                zoneName: metadata.share.recordID.zoneID.zoneName,
                ownerDisplayName: ownerDisplayName
            )
        case .pending:
            guard let cloudKitMetadata = metadata as? CKShare.Metadata else {
                throw CalendarSharingError.invitationInvalid
            }
            let acceptanceContainer = CKContainer(identifier: metadata.containerIdentifier)
            CalendarSharingDiagnostics.debug(
                operation: "acceptShare",
                stage: "accept-started",
                database: "shared",
                details: "metadataHash=\(CalendarSharingDiagnostics.metadataHash(metadata)) "
                    + "shareHash=\(shareHash)"
            )
            do {
                let results = try await acceptanceContainer.accept([cloudKitMetadata])
                guard let result = results[cloudKitMetadata] else {
                    throw CalendarSharingError.invitationInvalid
                }
                let acceptedShare = try result.get()
                CalendarSharingDiagnostics.debug(
                    operation: "acceptShare",
                    stage: "accept-completed",
                    database: "shared",
                    details: "metadataHash=\(CalendarSharingDiagnostics.metadataHash(metadata)) "
                        + "shareHash=\(CalendarSharingDiagnostics.recordHash(acceptedShare.recordID))"
                )
                return AcceptedSharedCalendarCloudResult(
                    zoneName: acceptedShare.recordID.zoneID.zoneName,
                    ownerDisplayName: ownerDisplayName
                )
            } catch let error as CalendarSharingError {
                throw error
            } catch {
                throw CalendarSharingErrorMapper.map(error, context: .acceptingInvitation)
            }
        case .removed:
            throw CalendarSharingError.invitationRevoked
        case .unknown:
            throw CalendarSharingError.invitationInvalid
        @unknown default:
            throw CalendarSharingError.invitationInvalid
        }
    }

    func leaveSharedCalendar(_ calendar: SharedCalendarDescriptor) async throws {
        let zoneID = CKRecordZone.ID(zoneName: calendar.zoneName, ownerName: calendar.ownerName)
        let shareID = CKRecord.ID(recordName: calendar.shareRecordName, zoneID: zoneID)
        let result = try await sharedDatabase.modifyRecords(
            saving: [],
            deleting: [shareID],
            savePolicy: .ifServerRecordUnchanged,
            atomically: true
        )
        try validate(result.deleteResults)
    }

    func stopOwnedSharing(_ calendar: OwnedSharedCalendarDescriptor) async throws {
        let zoneID = CKRecordZone.ID(zoneName: calendar.zoneName, ownerName: calendar.ownerName)
        do {
            try await deleteZone(zoneID)
        } catch where CalendarSharingErrorMapper.isMissingOrInaccessibleSharedZone(error) {
            // Idempotent success is intentionally limited to the persisted stopping workflow.
        }
    }

    private func ownedState(zoneID: CKRecordZone.ID) async throws -> OwnedSharedCalendarCloudState? {
        guard let calendarID = CalendarSharingCloudSchema.calendarID(from: zoneID.zoneName) else {
            return nil
        }
        let rootID = CKRecord.ID(recordName: CalendarSharingCloudSchema.calendarRecordName, zoneID: zoneID)
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        guard let root = try await optionalRecord(rootID, database: privateDatabase),
              let share = try await optionalRecord(shareID, database: privateDatabase) as? CKShare,
              let name = CalendarSharingCloudSchema.normalizedName(
                root[CalendarSharingCloudSchema.CalendarField.calendarName] as? String
              ) else {
            return nil
        }
        let participants = OwnedCalendarParticipantSnapshotAssembler.make(from: share)
        return OwnedSharedCalendarCloudState(
            calendar: OwnedSharedCalendarDescriptor(
                id: calendarID,
                zoneName: zoneID.zoneName,
                ownerName: zoneID.ownerName,
                calendarName: name,
                participantCount: participants.count,
                rootRecordName: root.recordID.recordName,
                shareRecordName: share.recordID.recordName
            ),
            share: share,
            participants: participants
        )
    }

    private func replaceContent(
        zoneID: CKRecordZone.ID,
        events: [SharedEventSnapshot],
        shifts: [SharedShiftSnapshot],
        workRecords: [SharedWorkRecordSnapshot]
    ) async throws {
        let records = try await allRecordsFromZoneChanges(
            zoneID: zoneID,
            database: privateDatabase
        )
        let executor = CalendarSharingContentRecordPlanExecutor(
            database: CloudKitContentRecordDatabase(database: privateDatabase)
        )
        try await executor.execute(
            CalendarSharingContentRecordPlan(
                recordType: CalendarSharingCloudSchema.eventRecordType,
                existingRecords: records.records(ofType: CalendarSharingCloudSchema.eventRecordType),
                snapshots: events,
                recordID: { CKRecord.ID(recordName: "event-\($0.id.uuidString.lowercased())", zoneID: zoneID) },
                makeRecord: CalendarSharingCloudRecordFactory.makeEventRecord
            )
        )
        try await executor.execute(
            CalendarSharingContentRecordPlan(
                recordType: CalendarSharingCloudSchema.shiftRecordType,
                existingRecords: records.records(ofType: CalendarSharingCloudSchema.shiftRecordType),
                snapshots: shifts,
                recordID: { CKRecord.ID(recordName: "shift-\($0.id.uuidString.lowercased())", zoneID: zoneID) },
                makeRecord: CalendarSharingCloudRecordFactory.makeShiftRecord
            )
        )
        try await executor.execute(
            CalendarSharingContentRecordPlan(
                recordType: CalendarSharingCloudSchema.workRecordType,
                existingRecords: records.records(ofType: CalendarSharingCloudSchema.workRecordType),
                snapshots: workRecords,
                recordID: { CKRecord.ID(recordName: "work-\($0.id.uuidString.lowercased())", zoneID: zoneID) },
                makeRecord: CalendarSharingCloudRecordFactory.makeWorkRecord
            )
        )
    }

    private func allRecordsFromZoneChanges(
        zoneID: CKRecordZone.ID,
        database: CKDatabase
    ) async throws -> SharedZoneRecordCollection {
        var collection = SharedZoneRecordCollection()
        var token: CKServerChangeToken?
        var restarted = false
        while true {
            do {
                let response = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: token
                )
                collection.apply(try response.modificationResultsByID.values.map { try $0.get().record })
                response.deletions.forEach { collection.remove($0.recordID) }
                token = response.changeToken
                if !response.moreComing { return collection }
            } catch {
                if CalendarSharingErrorMapper.shouldRestartZoneChangesFromBeginning(
                    error,
                    alreadyRetried: restarted
                ) {
                    restarted = true
                    token = nil
                    collection = SharedZoneRecordCollection()
                    continue
                }
                throw error
            }
        }
    }

    private func verifyAccountAvailability() async throws {
        switch try await container.accountStatus() {
        case .available: return
        case .noAccount: throw CalendarSharingError.noICloudAccount
        case .restricted: throw CalendarSharingError.iCloudRestricted
        case .temporarilyUnavailable:
            throw CalendarSharingError.serviceTemporarilyUnavailable
        case .couldNotDetermine:
            throw CalendarSharingError.iCloudStatusUnavailable
        @unknown default: throw CalendarSharingError.iCloudStatusUnavailable
        }
    }

    private func ownedZoneID(calendarID: UUID) -> CKRecordZone.ID {
        CKRecordZone.ID(
            zoneName: CalendarSharingCloudSchema.zoneName(for: calendarID),
            ownerName: CKCurrentUserDefaultName
        )
    }

    private func ensureZone(_ zoneID: CKRecordZone.ID) async throws {
        let zones = try await privateDatabase.allRecordZones()
        guard !zones.contains(where: { $0.zoneID == zoneID }) else { return }
        let result = try await privateDatabase.modifyRecordZones(
            saving: [CKRecordZone(zoneID: zoneID)],
            deleting: []
        )
        try validate(result.saveResults)
    }

    private func deleteZone(_ zoneID: CKRecordZone.ID) async throws {
        let result = try await privateDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
        try validate(result.deleteResults)
    }

    private func save(
        _ records: [CKRecord],
        in database: CKDatabase,
        atomically: Bool
    ) async throws -> [CKRecord] {
        let result = try await database.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .changedKeys,
            atomically: atomically
        )
        try validate(result.saveResults)
        return try result.saveResults.values.map { try $0.get() }
    }

    private func optionalRecord(_ id: CKRecord.ID, database: CKDatabase) async throws -> CKRecord? {
        do {
            let results = try await database.records(for: [id])
            return try results[id]?.get()
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }

    private func validate<Key, Value>(_ results: [Key: Result<Value, Error>]) throws {
        for result in results.values { _ = try result.get() }
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
