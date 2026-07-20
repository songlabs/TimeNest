import Foundation

enum ShiftBatchOperationError: Error, Equatable {
    case invalidPlan
    case stalePlan
}

final class ShiftBatchOperationUseCase {
    private let eventUseCase: EventUseCase
    private let calendar: Calendar
    private let now: () -> Date
    private let makeID: () -> UUID

    init(
        eventUseCase: EventUseCase,
        calendar: Calendar = Calendar(identifier: .gregorian),
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.eventUseCase = eventUseCase
        var businessCalendar = Calendar(identifier: .gregorian)
        businessCalendar.timeZone = calendar.timeZone
        businessCalendar.firstWeekday = calendar.firstWeekday
        self.calendar = businessCalendar
        self.now = now
        self.makeID = makeID
    }

    func makePlan(for request: ShiftBatchRequest) async throws -> ShiftBatchOperationPlan {
        let dates = normalizedUniqueDates(request.dates)
        guard !dates.isEmpty else {
            return ShiftBatchOperationPlan(
                calendarID: request.calendarID,
                mode: request.mode,
                items: [],
                issues: [.emptySelection]
            )
        }

        let sourceOffset = sourceDayOffset(for: request.mode)
        let sourceDates = sourceOffset.map { offset in
            dates.compactMap { calendar.date(byAdding: .day, value: offset, to: $0) }
        } ?? []
        let relevantDates = dates + sourceDates
        let allEvents = try await events(
            covering: relevantDates,
            calendarID: request.calendarID
        )
        let templatesByID = Dictionary(
            uniqueKeysWithValues: request.templates.map { ($0.id, $0) }
        )
        let requiredTemplates = requiredTemplateIDs(for: request.mode).compactMap {
            templatesByID[$0]
        }
        var issues = Set<ShiftBatchPlanIssue>()

        if case .rotation(let rotationItems, _) = request.mode, rotationItems.isEmpty {
            issues.insert(.emptyRotation)
        }

        let items = dates.enumerated().map { index, targetDate in
            let targetShifts = shiftEvents(
                on: targetDate,
                in: allEvents,
                templates: request.templates
            )

            switch request.mode {
            case .template(let templateID):
                guard let template = templatesByID[templateID], isValid(template) else {
                    issues.insert(.invalidTemplate)
                    return ShiftBatchOperationItem(
                        targetDate: targetDate,
                        status: .invalidTemplate
                    )
                }
                if !targetShifts.isEmpty {
                    return ShiftBatchOperationItem(
                        targetDate: targetDate,
                        displayName: template.displayName,
                        status: .conflict
                    )
                }
                return ShiftBatchOperationItem(
                    targetDate: targetDate,
                    displayName: template.displayName,
                    status: .create,
                    eventDrafts: [makeEvent(from: template, on: targetDate, calendarID: request.calendarID)]
                )

            case .copyPreviousDay, .copyPreviousWeek:
                let dayOffset = sourceDayOffset(for: request.mode) ?? 0
                guard let sourceDate = calendar.date(byAdding: .day, value: dayOffset, to: targetDate) else {
                    return ShiftBatchOperationItem(
                        targetDate: targetDate,
                        status: .noSource
                    )
                }
                let sourceShifts = shiftEvents(
                    on: sourceDate,
                    in: allEvents,
                    templates: request.templates
                )
                guard let source = sourceShifts.first else {
                    return ShiftBatchOperationItem(
                        targetDate: targetDate,
                        sourceDate: sourceDate,
                        status: .noSource
                    )
                }
                if !targetShifts.isEmpty {
                    return ShiftBatchOperationItem(
                        targetDate: targetDate,
                        sourceDate: sourceDate,
                        displayName: source.title,
                        status: .conflict,
                        sourceEventSnapshots: [source]
                    )
                }
                guard let event = copy(source, to: targetDate, templates: request.templates) else {
                    return ShiftBatchOperationItem(
                        targetDate: targetDate,
                        sourceDate: sourceDate,
                        status: .noSource
                    )
                }
                return ShiftBatchOperationItem(
                    targetDate: targetDate,
                    sourceDate: sourceDate,
                    displayName: source.title,
                    status: .create,
                    eventDrafts: [event],
                    sourceEventSnapshots: [source]
                )

            case .rotation(let rotationItems, let startOffset):
                guard !rotationItems.isEmpty else {
                    return ShiftBatchOperationItem(
                        targetDate: targetDate,
                        status: .invalidTemplate
                    )
                }
                let normalizedOffset = ((startOffset % rotationItems.count) + rotationItems.count) % rotationItems.count
                let rotationItem = rotationItems[(index + normalizedOffset) % rotationItems.count]
                switch rotationItem.selection {
                case .restDay:
                    return ShiftBatchOperationItem(
                        targetDate: targetDate,
                        status: targetShifts.isEmpty ? .restDay : .conflict,
                        isRestDay: true
                    )
                case .template(let templateID):
                    guard let template = templatesByID[templateID], isValid(template) else {
                        issues.insert(.invalidTemplate)
                        return ShiftBatchOperationItem(
                            targetDate: targetDate,
                            status: .invalidTemplate
                        )
                    }
                    if !targetShifts.isEmpty {
                        return ShiftBatchOperationItem(
                            targetDate: targetDate,
                            displayName: template.displayName,
                            status: .conflict
                        )
                    }
                    return ShiftBatchOperationItem(
                        targetDate: targetDate,
                        displayName: template.displayName,
                        status: .create,
                        eventDrafts: [makeEvent(from: template, on: targetDate, calendarID: request.calendarID)]
                    )
                }
            }
        }

        if requiredTemplates.count != requiredTemplateIDs(for: request.mode).count {
            issues.insert(.invalidTemplate)
        }

        return ShiftBatchOperationPlan(
            calendarID: request.calendarID,
            mode: request.mode,
            items: items,
            issues: issues,
            requiredTemplateSnapshots: requiredTemplates
        )
    }

    func execute(
        plan: ShiftBatchOperationPlan,
        currentTemplates: [ShiftBatchTemplateSnapshot]
    ) async throws -> ShiftBatchOperationResult {
        guard plan.canExecute else {
            throw ShiftBatchOperationError.invalidPlan
        }

        let currentTemplatesByID = Dictionary(
            uniqueKeysWithValues: currentTemplates.map { ($0.id, $0) }
        )
        guard plan.requiredTemplateSnapshots.allSatisfy({ currentTemplatesByID[$0.id] == $0 }) else {
            throw ShiftBatchOperationError.stalePlan
        }

        for item in plan.items where !item.eventDrafts.isEmpty {
            let currentEvents = try await events(
                covering: [item.targetDate],
                calendarID: plan.calendarID
            )
            guard shiftEvents(
                on: item.targetDate,
                in: currentEvents,
                templates: currentTemplates
            ).isEmpty else {
                throw ShiftBatchOperationError.stalePlan
            }
            for sourceSnapshot in item.sourceEventSnapshots {
                guard try await eventUseCase.event(id: sourceSnapshot.id) == sourceSnapshot else {
                    throw ShiftBatchOperationError.stalePlan
                }
            }
            for draft in item.eventDrafts {
                guard try await eventUseCase.event(id: draft.id) == nil else {
                    throw ShiftBatchOperationError.stalePlan
                }
            }
        }

        let sourceSnapshots = plan.items
            .flatMap(\.sourceEventSnapshots)
            .reduce(into: [UUID: CalendarEvent]()) { result, event in
                result[event.id] = event
            }
            .map { $0.value }
        let saveResult: EventUseCase.BatchCreateResult
        do {
            saveResult = try await eventUseCase.createEventsBatch(
                plan.eventsToCreate,
                ifUnchanged: sourceSnapshots
            )
        } catch EventRepositoryBatchError.staleData,
                EventRepositoryBatchError.eventNotFound,
                EventRepositoryBatchError.shiftConflict {
            throw ShiftBatchOperationError.stalePlan
        }
        let undoSnapshot = ShiftBatchUndoSnapshot(
            batchID: plan.id,
            createdEvents: saveResult.savedEvents
        )
        return ShiftBatchOperationResult(
            batchID: plan.id,
            createdCount: saveResult.savedEvents.count,
            skippedCount: plan.items.filter { $0.status != .create }.count,
            auxiliaryFailureCount: saveResult.auxiliaryFailureCount,
            undoSnapshot: undoSnapshot
        )
    }

    func undo(snapshot: ShiftBatchUndoSnapshot) async throws -> ShiftBatchUndoResult {
        var unchangedEvents: [CalendarEvent] = []
        var editedCount = 0
        var missingCount = 0

        for savedEvent in snapshot.createdEvents {
            guard let currentEvent = try await eventUseCase.event(id: savedEvent.id) else {
                missingCount += 1
                continue
            }
            guard currentEvent == savedEvent else {
                editedCount += 1
                continue
            }
            unchangedEvents.append(savedEvent)
        }

        if !unchangedEvents.isEmpty {
            do {
                try await eventUseCase.deleteEventsBatch(expectedEvents: unchangedEvents)
            } catch EventRepositoryBatchError.staleData {
                throw ShiftBatchOperationError.stalePlan
            }
        }
        return ShiftBatchUndoResult(
            deletedCount: unchangedEvents.count,
            editedCount: editedCount,
            missingCount: missingCount
        )
    }

    private func normalizedUniqueDates(_ dates: [Date]) -> [Date] {
        let normalized = dates.map(calendar.startOfDay)
        return Array(Set(normalized)).sorted()
    }

    private func sourceDayOffset(for mode: ShiftBatchMode) -> Int? {
        switch mode {
        case .copyPreviousDay:
            return -1
        case .copyPreviousWeek:
            return -7
        case .template, .rotation:
            return nil
        }
    }

    private func requiredTemplateIDs(for mode: ShiftBatchMode) -> [ShiftTimeTemplateID] {
        let ids: [ShiftTimeTemplateID]
        switch mode {
        case .template(let id):
            ids = [id]
        case .rotation(let items, _):
            ids = items.compactMap {
                guard case .template(let id) = $0.selection else { return nil }
                return id
            }
        case .copyPreviousDay, .copyPreviousWeek:
            ids = []
        }
        var seen = Set<ShiftTimeTemplateID>()
        return ids.filter { seen.insert($0).inserted }
    }

    private func events(covering dates: [Date], calendarID: UUID) async throws -> [CalendarEvent] {
        guard let earliest = dates.min(), let latest = dates.max() else { return [] }
        let start = calendar.startOfDay(for: earliest)
        let latestStart = calendar.startOfDay(for: latest)
        let end = calendar.date(byAdding: .day, value: 2, to: latestStart) ?? latestStart
        return try await eventUseCase.events(
            in: DateInterval(start: start, end: end),
            calendarID: calendarID
        )
    }

    private func shiftEvents(
        on date: Date,
        in events: [CalendarEvent],
        templates: [ShiftBatchTemplateSnapshot]
    ) -> [CalendarEvent] {
        let templateNames = Set(templates.map(\.displayName))
        return events.filter { event in
            guard calendar.isDate(event.startDate, inSameDayAs: date),
                  event.workInfo == nil,
                  event.workClockKind == nil else {
                return false
            }
            return event.shiftTemplateID != nil
                || templateNames.contains(event.title)
                || legacyTemplateID(for: event.title) != nil
        }
        .sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func isValid(_ template: ShiftBatchTemplateSnapshot) -> Bool {
        template.enabled
            && !template.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hourMinute(from: template.startTime) != nil
            && hourMinute(from: template.endTime) != nil
    }

    private func makeEvent(
        from template: ShiftBatchTemplateSnapshot,
        on date: Date,
        calendarID: UUID
    ) -> CalendarEvent {
        let now = now()
        let dates = eventDates(
            on: date,
            startTime: template.startTime,
            endTime: template.endTime
        )
        return CalendarEvent(
            id: makeID(),
            calendarID: calendarID,
            title: template.displayName,
            note: template.note.isEmpty ? nil : template.note,
            startDate: dates.start,
            endDate: dates.end,
            isAllDay: false,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: nil,
            notificationID: nil,
            importSource: nil,
            createdAt: now,
            updatedAt: now,
            shiftTemplateID: template.id,
            workInfo: nil
        )
    }

    private func copy(
        _ source: CalendarEvent,
        to targetDate: Date,
        templates: [ShiftBatchTemplateSnapshot]
    ) -> CalendarEvent? {
        guard let startDate = mapTimeComponent(source.startDate, to: targetDate) else {
            return nil
        }
        let sourceStartDay = calendar.startOfDay(for: source.startDate)
        let sourceEndDay = calendar.startOfDay(for: source.endDate)
        let endDayOffset = calendar.dateComponents(
            [.day],
            from: sourceStartDay,
            to: sourceEndDay
        ).day ?? 0
        guard let targetEndDay = calendar.date(
            byAdding: .day,
            value: endDayOffset,
            to: calendar.startOfDay(for: targetDate)
        ), let endDate = mapTimeComponent(source.endDate, to: targetEndDay), endDate > startDate else {
            return nil
        }

        let now = now()
        let inferredTemplateID = source.shiftTemplateID
            ?? templates.first(where: { $0.displayName == source.title })?.id
            ?? legacyTemplateID(for: source.title)
        guard let inferredTemplateID else { return nil }

        return CalendarEvent(
            id: makeID(),
            calendarID: source.calendarID,
            title: source.title,
            note: source.note,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            categoryID: source.categoryID,
            recurrenceRule: .none,
            reminderTemplateID: source.reminderTemplateID,
            reminderOffsetMinutes: source.reminderOffsetMinutes,
            notificationID: nil,
            importSource: nil,
            createdAt: now,
            updatedAt: now,
            shiftTemplateID: inferredTemplateID,
            workInfo: nil
        )
    }

    private func eventDates(on targetDate: Date, startTime: String, endTime: String) -> (start: Date, end: Date) {
        let startParts = hourMinute(from: startTime) ?? (0, 0)
        let endParts = hourMinute(from: endTime) ?? (1, 0)
        let dayStart = calendar.startOfDay(for: targetDate)
        let start = date(on: dayStart, hour: startParts.hour, minute: startParts.minute)
        let startMinutes = startParts.hour * 60 + startParts.minute
        let endMinutes = endParts.hour * 60 + endParts.minute
        let endBase = endMinutes <= startMinutes
            ? (calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
            : dayStart
        let end = self.date(on: endBase, hour: endParts.hour, minute: endParts.minute)
        return (start, end)
    }

    private func mapTimeComponent(_ source: Date, to targetDay: Date) -> Date? {
        let components = calendar.dateComponents([.hour, .minute, .second], from: source)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return date(
            on: targetDay,
            hour: hour,
            minute: minute,
            second: components.second ?? 0
        )
    }

    private func date(on day: Date, hour: Int, minute: Int, second: Int = 0) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: second,
            of: dayStart
        ) ?? dayStart
    }

    private func hourMinute(from value: String) -> (hour: Int, minute: Int)? {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func legacyTemplateID(for title: String) -> ShiftTimeTemplateID? {
        if ["白", "白班", "日勤", "Day Shift", "주간"].contains(title) {
            return .day
        }
        if ["夜", "夜班", "夜勤", "Night Shift", "야간"].contains(title) {
            return .night
        }
        return nil
    }
}
