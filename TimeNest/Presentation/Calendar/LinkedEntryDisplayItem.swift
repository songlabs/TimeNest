import Foundation

struct WorkRecordDisplaySession: Identifiable {
    let id: String
    let clockIn: EventOccurrence?
    let clockOut: EventOccurrence?
    let workSessionId: UUID?

    var eventIDs: [UUID] {
        occurrences.reduce(into: []) { ids, occurrence in
            if !ids.contains(occurrence.eventID) {
                ids.append(occurrence.eventID)
            }
        }
    }

    var occurrences: [EventOccurrence] {
        [clockIn, clockOut].compactMap { $0 }
    }

    var unifiedEntryID: UUID? {
        guard let first = occurrences.first?.unifiedEntryID else {
            return nil
        }
        guard occurrences.allSatisfy({ $0.unifiedEntryID == first }) else {
            return nil
        }
        return first
    }

    var sortDate: Date {
        clockIn?.actualWorkClockDate ?? clockOut?.actualWorkClockDate ?? .distantPast
    }

    static func make(from events: [EventOccurrence], selectedDate: Date) -> [WorkRecordDisplaySession] {
        _ = selectedDate
        let occurrencesByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        let entries = events.compactMap(WorkRecordClockEntry.init(occurrence:))
        return WorkRecordSessionAssembler.sessions(from: entries).compactMap { session in
            let clockIn = occurrence(for: session.clockIn, in: occurrencesByID)
            let clockOut = occurrence(for: session.clockOut, in: occurrencesByID)
            guard clockIn != nil || clockOut != nil else { return nil }
            let fallbackID = [
                clockIn?.id ?? "missing-in",
                clockOut?.id ?? "missing-out"
            ].joined(separator: "-")
            return WorkRecordDisplaySession(
                id: session.sessionID?.uuidString ?? "legacy-\(fallbackID)",
                clockIn: clockIn,
                clockOut: clockOut,
                workSessionId: session.sessionID
            )
        }
    }

    private static func occurrence(
        for entry: WorkRecordClockEntry?,
        in occurrencesByID: [String: EventOccurrence]
    ) -> EventOccurrence? {
        guard let entry,
              case .occurrence(let id) = entry.sourceID else {
            return nil
        }
        return occurrencesByID[id]
    }

    func editorInitialSession(selectedDate: Date) -> WorkRecordEditorInitialSession {
        let sourceWorkInfo = clockIn?.workInfo ?? clockOut?.workInfo
        return WorkRecordEditorInitialSession(
            clockInEventID: clockIn?.eventID,
            clockOutEventID: clockOut?.eventID,
            title: editorTitle(defaultTitle: LocalizationManager.shared.localized(.workRecordDefaultTitle)),
            workDate: clockIn?.workDate ?? clockOut?.workDate ?? selectedDate,
            workInTime: clockIn?.actualWorkClockDate,
            workOutTime: clockOut?.actualWorkClockDate,
            restHours: sourceWorkInfo?.restHours ?? 1.0,
            transportFee: sourceWorkInfo?.transportFee,
            hourlyRate: sourceWorkInfo?.hourlyRate,
            workSessionId: workSessionId ?? clockIn?.workInfo?.workSessionId ?? clockOut?.workInfo?.workSessionId,
            isWorkOutTimeSet: clockOut?.isWorkOutTimeSet ?? false,
            calendarID: calendarID
        )
    }

    var calendarID: UUID {
        clockIn?.calendarID ?? clockOut?.calendarID ?? TimeNestCalendar.personalID
    }

    func displayTitle(defaultTitle: String) -> String {
        for title in [clockIn?.title, clockOut?.title].compactMap({ $0 }) {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty, WorkClockTitleMatcher.kind(for: trimmedTitle) == nil {
                return trimmedTitle
            }
        }
        return defaultTitle
    }

    func editorTitle(defaultTitle: String) -> String {
        for title in [clockIn?.title, clockOut?.title].compactMap({ $0 }) {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty {
                return trimmedTitle
            }
        }
        return defaultTitle
    }

    func timeRangeText(selectedDate: Date) -> String {
        "\(clockInText) → \(clockOutText(selectedDate: selectedDate))"
    }

    private var clockInText: String {
        guard let clockIn else {
            return LocalizationManager.shared.localized(.workRecordMissingClockIn)
        }
        return "\(LocalizationManager.shared.localized(.editorWorkIn)) \(formatTime(clockIn.actualWorkClockDate))"
    }

    private func clockOutText(selectedDate: Date) -> String {
        guard let clockOut, clockOut.isWorkOutTimeSet else {
            return LocalizationManager.shared.localized(.workRecordMissingClockOut)
        }
        let clockOutTime = effectiveClockOutTime(clockOut)
        let time = formatTime(clockOutTime)
        if isNextDay(clockOutTime, selectedDate: selectedDate) {
            return "\(LocalizationManager.shared.localized(.editorWorkOut)) \(LocalizationManager.shared.localized(.workNextDayPrefix)) \(time)"
        }
        return "\(LocalizationManager.shared.localized(.editorWorkOut)) \(time)"
    }

    private func effectiveClockOutTime(_ clockOut: EventOccurrence) -> Date {
        let outTime = clockOut.actualWorkClockDate
        guard let clockInTime = clockIn?.actualWorkClockDate else {
            return outTime
        }
        let calendar = Calendar.current
        guard calendar.isDate(outTime, inSameDayAs: clockInTime), outTime <= clockInTime else {
            return outTime
        }
        return calendar.date(byAdding: .day, value: 1, to: outTime) ?? outTime
    }

    private func isNextDay(_ date: Date, selectedDate: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: selectedDate)
    }

    private func formatTime(_ date: Date) -> String {
        LocalizationManager.shared.dateFormatter(dateFormat: "HH:mm").string(from: date)
    }
}

struct LinkedEntryDisplayItem: Identifiable {
    let event: EventOccurrence?
    let workRecord: WorkRecordDisplaySession?
    fileprivate let sourceOrder: Int

    var id: String {
        if let unifiedEntryID, event != nil, workRecord != nil {
            return "linked-\(unifiedEntryID.uuidString)"
        }
        if let event {
            return "event-\(event.id)"
        }
        if let workRecord {
            return "work-\(workRecord.id)"
        }
        return "empty-\(sourceOrder)"
    }

    var unifiedEntryID: UUID? {
        event?.unifiedEntryID ?? workRecord?.unifiedEntryID
    }

    var isLinked: Bool {
        guard let eventID = event?.unifiedEntryID,
              let workRecordID = workRecord?.unifiedEntryID else {
            return false
        }
        return eventID == workRecordID
    }
}

enum LinkedEntryDisplayAssembler {
    static func make(
        from occurrences: [EventOccurrence],
        selectedDate: Date
    ) -> [LinkedEntryDisplayItem] {
        var sourceIndexByOccurrenceID: [String: Int] = [:]
        for (index, occurrence) in occurrences.enumerated()
            where sourceIndexByOccurrenceID[occurrence.id] == nil {
            sourceIndexByOccurrenceID[occurrence.id] = index
        }

        let events = occurrences.filter { !$0.isWorkClockEvent }
        let workRecords = WorkRecordDisplaySession.make(
            from: occurrences.filter(\.isWorkClockEvent),
            selectedDate: selectedDate
        )
        let workRecordsByUnifiedEntryID = Dictionary(
            grouping: workRecords.filter { $0.unifiedEntryID != nil },
            by: { $0.unifiedEntryID! }
        )
        var consumedWorkRecordIDs = Set<String>()
        var items: [LinkedEntryDisplayItem] = []

        for event in events {
            let workRecord: WorkRecordDisplaySession?
            if let unifiedEntryID = event.unifiedEntryID,
               let candidates = workRecordsByUnifiedEntryID[unifiedEntryID],
               let match = candidates.first(where: {
                   !consumedWorkRecordIDs.contains($0.id)
               }) {
                workRecord = match
                consumedWorkRecordIDs.insert(match.id)
            } else {
                workRecord = nil
            }

            items.append(
                LinkedEntryDisplayItem(
                    event: event,
                    workRecord: workRecord,
                    sourceOrder: sourceOrder(
                        event: event,
                        workRecord: workRecord,
                        sourceIndexByOccurrenceID: sourceIndexByOccurrenceID
                    )
                )
            )
        }

        for workRecord in workRecords
            where !consumedWorkRecordIDs.contains(workRecord.id) {
            items.append(
                LinkedEntryDisplayItem(
                    event: nil,
                    workRecord: workRecord,
                    sourceOrder: sourceOrder(
                        event: nil,
                        workRecord: workRecord,
                        sourceIndexByOccurrenceID: sourceIndexByOccurrenceID
                    )
                )
            )
        }

        return items.sorted {
            if $0.sourceOrder != $1.sourceOrder {
                return $0.sourceOrder < $1.sourceOrder
            }
            return $0.id < $1.id
        }
    }

    static func collapsedOccurrences(
        from occurrences: [EventOccurrence]
    ) -> [EventOccurrence] {
        let selectedDate = occurrences.first?.occurrenceDate.toDate() ?? .distantPast
        let linkedWorkOccurrenceIDs = Set(
            make(from: occurrences, selectedDate: selectedDate)
                .filter(\.isLinked)
                .flatMap { $0.workRecord?.occurrences.map(\.id) ?? [] }
        )
        return occurrences.filter {
            !linkedWorkOccurrenceIDs.contains($0.id)
        }
    }

    private static func sourceOrder(
        event: EventOccurrence?,
        workRecord: WorkRecordDisplaySession?,
        sourceIndexByOccurrenceID: [String: Int]
    ) -> Int {
        ([event].compactMap { $0 } + (workRecord?.occurrences ?? []))
            .compactMap { sourceIndexByOccurrenceID[$0.id] }
            .min() ?? .max
    }
}
