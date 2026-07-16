import Foundation
import SwiftData

@Model
final class SwiftDataCalendarEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRawValue: String
    var zoneName: String?
    var ownerName: String?
    var rootRecordName: String?
    var shareRecordName: String?
    var stopPhaseRawValue: String = TimeNestCalendarStopPhase.active.rawValue
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        name: String,
        kindRawValue: String,
        zoneName: String? = nil,
        ownerName: String? = nil,
        rootRecordName: String? = nil,
        shareRecordName: String? = nil,
        stopPhaseRawValue: String = TimeNestCalendarStopPhase.active.rawValue,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.kindRawValue = kindRawValue
        self.zoneName = zoneName
        self.ownerName = ownerName
        self.rootRecordName = rootRecordName
        self.shareRecordName = shareRecordName
        self.stopPhaseRawValue = stopPhaseRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
