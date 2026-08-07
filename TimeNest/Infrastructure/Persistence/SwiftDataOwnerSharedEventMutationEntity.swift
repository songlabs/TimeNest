import Foundation
import SwiftData

@Model
final class SwiftDataOwnerSharedEventMutationEntity {
    @Attribute(.unique) var id: UUID
    var calendarID: UUID
    var eventID: UUID
    var operationRawValue: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var updatedAt: Date
    var isDeleted: Bool
    var deletedAt: Date?
    var createdAt: Date
    var sequence: Int64
    var statusRawValue: String
    var retryCount: Int
    var lastErrorCode: String?

    init(
        id: UUID,
        calendarID: UUID,
        eventID: UUID,
        operationRawValue: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        updatedAt: Date,
        isDeleted: Bool,
        deletedAt: Date?,
        createdAt: Date,
        sequence: Int64,
        statusRawValue: String,
        retryCount: Int,
        lastErrorCode: String?
    ) {
        self.id = id
        self.calendarID = calendarID
        self.eventID = eventID
        self.operationRawValue = operationRawValue
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.sequence = sequence
        self.statusRawValue = statusRawValue
        self.retryCount = retryCount
        self.lastErrorCode = lastErrorCode
    }
}
