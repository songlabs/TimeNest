import Foundation
import SwiftData

@ModelActor
actor SwiftDataReminderRepository: ReminderRepository {
    func save(_ reminder: ScheduledReminder) async throws {
        do {
            if let existingEntity = try entity(id: reminder.id) {
                SwiftDataReminderMapper.update(existingEntity, from: reminder)
            } else {
                modelContext.insert(SwiftDataReminderMapper.makeEntity(from: reminder))
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            SwiftDataRepositoryLogger.log("save reminder", error: error)
            throw error
        }
    }

    func reminders(for eventID: UUID) async throws -> [ScheduledReminder] {
        do {
            let descriptor = FetchDescriptor<SwiftDataReminderEntity>(
                predicate: #Predicate { $0.eventID == eventID },
                sortBy: [SortDescriptor(\.scheduledDate)]
            )
            return try modelContext.fetch(descriptor).map(SwiftDataReminderMapper.makeDomainModel)
        } catch {
            SwiftDataRepositoryLogger.log("fetch reminders for event", error: error)
            throw error
        }
    }

    func reminders(in range: DateInterval) async throws -> [ScheduledReminder] {
        do {
            let start = range.start
            let end = range.end
            let descriptor = FetchDescriptor<SwiftDataReminderEntity>(
                predicate: #Predicate { $0.scheduledDate >= start && $0.scheduledDate <= end },
                sortBy: [SortDescriptor(\.scheduledDate)]
            )
            return try modelContext.fetch(descriptor).map(SwiftDataReminderMapper.makeDomainModel)
        } catch {
            SwiftDataRepositoryLogger.log("fetch reminders in range", error: error)
            throw error
        }
    }

    func deleteByEventID(_ eventID: UUID) async throws {
        do {
            let descriptor = FetchDescriptor<SwiftDataReminderEntity>(
                predicate: #Predicate { $0.eventID == eventID }
            )
            for reminder in try modelContext.fetch(descriptor) {
                modelContext.delete(reminder)
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            SwiftDataRepositoryLogger.log("delete reminders for event", error: error)
            throw error
        }
    }

    private func entity(id: UUID) throws -> SwiftDataReminderEntity? {
        let descriptor = FetchDescriptor<SwiftDataReminderEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}
