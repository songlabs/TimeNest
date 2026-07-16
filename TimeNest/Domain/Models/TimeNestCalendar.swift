import Foundation

enum TimeNestCalendarKind: String, Codable, CaseIterable, Hashable {
    case personal
    case sharedOwned
    case sharedReceived

    var isReadOnly: Bool {
        self == .sharedReceived
    }

    var isCloudBacked: Bool {
        self != .personal
    }
}

enum TimeNestCalendarStopPhase: String, Codable, Hashable {
    case active
    case localReassignmentPending
    case cloudDeletionPending

    var isStopping: Bool { self != .active }
}

struct TimeNestCalendar: Identifiable, Codable, Hashable {
    /// Stable across upgrades so legacy rows can deterministically fall back to My Calendar.
    static let personalID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    let id: UUID
    var name: String
    var kind: TimeNestCalendarKind
    var zoneName: String?
    var ownerName: String?
    var rootRecordName: String?
    var shareRecordName: String?
    var stopPhase: TimeNestCalendarStopPhase
    let createdAt: Date
    var updatedAt: Date

    var isReadOnly: Bool { kind.isReadOnly }
    var canEditContent: Bool { !isReadOnly && !stopPhase.isStopping }
    var canManageParticipants: Bool { kind == .sharedOwned && !stopPhase.isStopping }

    static func personal(name: String, now: Date = Date()) -> TimeNestCalendar {
        TimeNestCalendar(
            id: personalID,
            name: name,
            kind: .personal,
            zoneName: nil,
            ownerName: nil,
            rootRecordName: nil,
            shareRecordName: nil,
            stopPhase: .active,
            createdAt: now,
            updatedAt: now
        )
    }

    init(
        id: UUID,
        name: String,
        kind: TimeNestCalendarKind,
        zoneName: String?,
        ownerName: String?,
        rootRecordName: String?,
        shareRecordName: String?,
        stopPhase: TimeNestCalendarStopPhase = .active,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.zoneName = zoneName
        self.ownerName = ownerName
        self.rootRecordName = rootRecordName
        self.shareRecordName = shareRecordName
        self.stopPhase = stopPhase
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
