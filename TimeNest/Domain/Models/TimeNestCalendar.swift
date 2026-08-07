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
    /// Owner-controlled business capability stored on the SharedCalendar root record.
    /// Missing legacy values decode as false so existing shares stay read-only.
    var eventEditingAllowed: Bool
    var collaborationProtocolVersion: Int
    /// The current participant's real CKShare permission. Owners do not depend on this value.
    var participantPermission: SharedCalendarParticipantPermission
    var stopPhase: TimeNestCalendarStopPhase
    let createdAt: Date
    var updatedAt: Date

    var isReadOnly: Bool { kind == .sharedReceived && !canEditSharedEvents }
    /// Generic content editing intentionally remains unavailable to received calendars.
    /// SharedEvent editing uses the event-specific capabilities below.
    var canEditContent: Bool { kind != .sharedReceived && !stopPhase.isStopping }
    var canCreateSharedEvent: Bool { canEditSharedEvents }
    var canEditSharedEvent: Bool { canEditSharedEvents }
    var canDeleteSharedEvent: Bool { canEditSharedEvents }
    var canManageShare: Bool { kind == .sharedOwned && !stopPhase.isStopping }
    var canManageParticipants: Bool { kind == .sharedOwned && !stopPhase.isStopping }

    private var canEditSharedEvents: Bool {
        guard !stopPhase.isStopping else { return false }
        switch kind {
        case .personal, .sharedOwned:
            return true
        case .sharedReceived:
            return collaborationProtocolVersion >= 1
                && eventEditingAllowed
                && participantPermission == .readWrite
        }
    }

    static func personal(name: String, now: Date = Date()) -> TimeNestCalendar {
        TimeNestCalendar(
            id: personalID,
            name: name,
            kind: .personal,
            zoneName: nil,
            ownerName: nil,
            rootRecordName: nil,
            shareRecordName: nil,
            eventEditingAllowed: false,
            collaborationProtocolVersion: 0,
            participantPermission: .none,
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
        eventEditingAllowed: Bool = false,
        collaborationProtocolVersion: Int = 0,
        participantPermission: SharedCalendarParticipantPermission = .unknown,
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
        self.eventEditingAllowed = eventEditingAllowed
        self.collaborationProtocolVersion = collaborationProtocolVersion
        self.participantPermission = participantPermission
        self.stopPhase = stopPhase
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case zoneName
        case ownerName
        case rootRecordName
        case shareRecordName
        case eventEditingAllowed
        case collaborationProtocolVersion
        case participantPermission
        case stopPhase
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            kind: try container.decode(TimeNestCalendarKind.self, forKey: .kind),
            zoneName: try container.decodeIfPresent(String.self, forKey: .zoneName),
            ownerName: try container.decodeIfPresent(String.self, forKey: .ownerName),
            rootRecordName: try container.decodeIfPresent(String.self, forKey: .rootRecordName),
            shareRecordName: try container.decodeIfPresent(String.self, forKey: .shareRecordName),
            eventEditingAllowed: try container.decodeIfPresent(
                Bool.self,
                forKey: .eventEditingAllowed
            ) ?? false,
            collaborationProtocolVersion: try container.decodeIfPresent(
                Int.self,
                forKey: .collaborationProtocolVersion
            ) ?? 0,
            participantPermission: try container.decodeIfPresent(
                SharedCalendarParticipantPermission.self,
                forKey: .participantPermission
            ) ?? .unknown,
            stopPhase: try container.decodeIfPresent(
                TimeNestCalendarStopPhase.self,
                forKey: .stopPhase
            ) ?? .active,
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt)
        )
    }
}
