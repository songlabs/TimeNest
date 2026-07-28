import SwiftUI

private enum DayDetailLayout {
    static let presentationHeightFraction: CGFloat = 0.6
    static let horizontalPadding: CGFloat = SettingsModalSurface.horizontalPadding
    static let contentTopPadding: CGFloat = 6
    static let bottomPadding: CGFloat = 24
    static let contentSpacing: CGFloat = 22
    static let sectionSpacing: CGFloat = 12
    static let sectionButtonTopSpacing: CGFloat = 8
    static let actionButtonMinWidth: CGFloat = 144
    static let actionButtonHeight: CGFloat = 44
}

struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    let cell: CalendarDayCell
    let onDeleteEvent: (UUID) -> Void
    let onDeleteWorkRecord: ([UUID]) -> Void
    let onCreateEvent: EventEditorSaveAction
    let onUpdateEvent: EventEditorUpdateAction
    let onSaveWorkRecordPair: WorkRecordPairSaveAction
    var availableCalendars: [TimeNestCalendar] = []
    var entryCalendarContext: EntryCalendarContext = .fixedWritableCalendar(TimeNestCalendar.personalID)

    @State private var editingEvent: EditingEvent?
    @State private var showingAddEntry: Bool = false
    @State private var addEntryInitialKind: EntryEditorKind = .event
    @State private var editingWorkRecord: WorkRecordEditorInitialSession?

    var body: some View {
        VStack(spacing: 0) {
            SettingsModalHeaderView(title: dateTitle) {
                dismiss()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: DayDetailLayout.contentSpacing) {
                    if !cell.holidays.isEmpty {
                        holidaySection
                    }

                    eventsSection

                    workRecordsSection
                }
                .padding(.horizontal, DayDetailLayout.horizontalPadding)
                .padding(.top, DayDetailLayout.contentTopPadding)
                .padding(.bottom, DayDetailLayout.bottomPadding)
            }
            .accessibilityIdentifier("dayDetail.content")
        }
        .background(SettingsModalSurface.background)
        .presentationDetents([.fraction(DayDetailLayout.presentationHeightFraction)])
        .sheet(isPresented: $showingAddEntry) {
            let initialDate = cell.date.toDate()
            EventEditorView(
                isPresented: $showingAddEntry,
                mode: .create(initialDate: initialDate),
                existingEvents: cell.events,
                initialEntryKind: addEntryInitialKind,
                showsEntryKindPicker: true,
                availableCalendars: availableCalendars,
                calendarContext: entryCalendarContext,
                onSaveWorkRecordPair: onSaveWorkRecordPair,
                onSave: { title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo, calendarID in
                    try await onCreateEvent(title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo, calendarID)
                }
            )
        }
        .sheet(item: $editingEvent) { event in
            EventEditorView(
                isPresented: editingPresentationBinding,
                mode: .edit(
                    eventID: event.eventID,
                    initialTitle: event.title,
                    initialNote: event.note,
                    initialStartDate: event.startDate,
                    initialEndDate: event.endDate,
                    initialIsAllDay: event.isAllDay,
                    initialReminderOffsetMinutes: event.reminderOffsetMinutes,
                    initialWorkInfo: event.workInfo,
                    initialShiftTemplateID: event.shiftTemplateID
                ),
                existingEvents: cell.events,
                availableCalendars: availableCalendars,
                calendarContext: .fixedWritableCalendar(event.calendarID),
                onSave: { newTitle, newNote, newStartDate, newEndDate, newIsAllDay, newReminderOffsetMinutes, newShiftTemplateID, workInfo, calendarID in
                    try await onUpdateEvent(event.eventID, newTitle, newNote, newStartDate, newEndDate, newIsAllDay, newReminderOffsetMinutes, newShiftTemplateID, workInfo, calendarID)
                }
            )
        }
        .sheet(item: $editingWorkRecord) { session in
            WorkRecordEditorView(
                isPresented: workRecordEditingPresentationBinding,
                mode: .edit(session),
                existingEvents: cell.events,
                availableCalendars: availableCalendars,
                calendarContext: .fixedWritableCalendar(session.calendarID),
                onSavePair: onSaveWorkRecordPair
            )
        }
    }

    private var holidaySection: some View {
        VStack(spacing: 4) {
            ForEach(cell.holidays, id: \.id) { holiday in
                Text(localizedHolidayName(holiday))
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: DayDetailLayout.sectionSpacing) {
            Text(localization.localized(.dayDetailTitle))
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)

            if regularEvents.isEmpty {
                EmptyView()
            } else {
                ForEach(regularEvents, id: \.id) { event in
                    EventRowView(
                        event: event,
                        selectedDate: cell.date.toDate(),
                        dayEvents: regularEvents,
                        onDelete: {
                            onDeleteEvent(event.eventID)
                        },
                        onEdit: {
                            openEditor(for: event)
                        }
                    )
                }
            }

            addEventButton
                .frame(maxWidth: .infinity)
                .padding(.top, DayDetailLayout.sectionButtonTopSpacing)
        }
    }

    private var workRecordsSection: some View {
        VStack(alignment: .leading, spacing: DayDetailLayout.sectionSpacing) {
            Text(localization.localized(.workRecordSectionTitle))
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
                .accessibilityIdentifier("workRecord.list")

            if workRecordSessions.isEmpty {
                TimeNestActionableEmptyStateView(
                    actionTitle: localization.localized(.workRecordAdd),
                    containerIdentifier: "workRecord.empty",
                    actionIdentifier: "workRecord.empty.create",
                    action: { presentAddEntry(kind: .workRecord) }
                )
            } else {
                ForEach(workRecordSessions) { session in
                    WorkRecordSessionRowView(
                        session: session,
                        selectedDate: cell.date.toDate(),
                        onEdit: {
                            editingWorkRecord = session.editorInitialSession(selectedDate: cell.date.toDate())
                        },
                        onDelete: {
                            onDeleteWorkRecord(session.eventIDs)
                        }
                    )
                }

                addWorkRecordButton
                    .frame(maxWidth: .infinity)
                    .padding(.top, DayDetailLayout.sectionButtonTopSpacing)
            }
        }
    }

    private var addEventButton: some View {
        Button(action: {
            presentAddEntry(kind: .event)
        }) {
            Text(localization.localized(.dayDetailAddEvent))
                .font(.headline.weight(.semibold))
                .frame(minWidth: DayDetailLayout.actionButtonMinWidth)
                .frame(height: DayDetailLayout.actionButtonHeight)
                .padding(.horizontal, 12)
                .background(ShiftCalendarColors.primaryBlue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: TimeNestTheme.controlCornerRadius, style: .continuous))
        }
    }

    private var addWorkRecordButton: some View {
        Button(action: {
            presentAddEntry(kind: .workRecord)
        }) {
            Text(localization.localized(.workRecordAdd))
                .font(.headline.weight(.semibold))
                .frame(minWidth: DayDetailLayout.actionButtonMinWidth)
                .frame(height: DayDetailLayout.actionButtonHeight)
                .padding(.horizontal, 12)
                .background(ShiftCalendarColors.primaryBlue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: TimeNestTheme.controlCornerRadius, style: .continuous))
        }
        .accessibilityIdentifier("workRecord.add")
    }

    private var regularEvents: [EventOccurrence] {
        cell.events.filter { !$0.isWorkClockEvent }
    }

    private var workRecordSessions: [WorkRecordDisplaySession] {
        WorkRecordDisplaySession.make(from: cell.events.filter { $0.isWorkClockEvent }, selectedDate: cell.date.toDate())
    }

    private func openEditor(for event: EventOccurrence) {
        editingEvent = EditingEvent(event)
    }

    private func presentAddEntry(kind: EntryEditorKind) {
        addEntryInitialKind = kind
        showingAddEntry = true
    }

    private var editingPresentationBinding: Binding<Bool> {
        Binding(
            get: { editingEvent != nil },
            set: { isPresented in
                if !isPresented {
                    editingEvent = nil
                }
            }
        )
    }

    private var workRecordEditingPresentationBinding: Binding<Bool> {
        Binding(
            get: { editingWorkRecord != nil },
            set: { isPresented in
                if !isPresented {
                    editingWorkRecord = nil
                }
            }
        )
    }

    private var dateTitle: String {
        let date = cell.date.toDate()
        return LocalizationManager.shared.formattedDateShort(for: date)
    }

    private func localizedHolidayName(_ holiday: Holiday) -> String {
        // 根据节假日所属地区选择对应语言名称，而不是根据当前 App 语言
        let names = holiday.localizedNames
        let displayName = names.displayName(for: holiday.region)
        
        // 如果为空，返回 fallback
        if displayName.isEmpty {
            return localizedHolidayNameFallback(names)
        }
        return displayName
    }

    private func localizedHolidayNameFallback(_ names: LocalizedText) -> String {
        // Fallback 顺序：ja -> zhHans -> enUS -> 任意非空名称
        if !names.ja.isEmpty { return names.ja }
        if !names.zhHans.isEmpty { return names.zhHans }
        if !names.enUS.isEmpty { return names.enUS }
        if !names.ko.isEmpty { return names.ko }
        return ""
    }
}

private struct EditingEvent: Identifiable {
    let id: String
    let eventID: UUID
    let calendarID: UUID
    let title: String
    let note: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let reminderOffsetMinutes: Int?
    let shiftTemplateID: ShiftTimeTemplateID?
    let workInfo: WorkInfo?

    init(_ event: EventOccurrence) {
        id = event.id
        eventID = event.eventID
        calendarID = event.calendarID
        title = event.title
        note = event.note
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        reminderOffsetMinutes = event.reminderOffsetMinutes
        shiftTemplateID = event.shiftTemplateID
        workInfo = event.workInfo
    }
}

struct WorkRecordDisplaySession: Identifiable {
    let id: String
    let clockIn: EventOccurrence?
    let clockOut: EventOccurrence?
    let workSessionId: UUID?

    var eventIDs: [UUID] {
        var ids: [UUID] = []
        if let clockIn, !ids.contains(clockIn.eventID) {
            ids.append(clockIn.eventID)
        }
        if let clockOut, !ids.contains(clockOut.eventID) {
            ids.append(clockOut.eventID)
        }
        return ids
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

}

private struct WorkRecordSessionRowView: View {
    let session: WorkRecordDisplaySession
    let selectedDate: Date
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayTitle(defaultTitle: LocalizationManager.shared.localized(.workRecordDefaultTitle)))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(timeRangeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .accessibilityIdentifier("workRecord.edit")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .accessibilityIdentifier("workRecord.delete")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var timeRangeText: String {
        "\(clockInText) → \(clockOutText)"
    }

    private var clockInText: String {
        guard let clockIn = session.clockIn else {
            return LocalizationManager.shared.localized(.workRecordMissingClockIn)
        }
        return "\(LocalizationManager.shared.localized(.editorWorkIn)) \(formatTime(clockIn.actualWorkClockDate))"
    }

    private var clockOutText: String {
        guard let clockOut = session.clockOut, clockOut.isWorkOutTimeSet else {
            return LocalizationManager.shared.localized(.workRecordMissingClockOut)
        }
        let clockOutTime = effectiveClockOutTime(clockOut)
        let time = formatTime(clockOutTime)
        if isNextDay(clockOutTime) {
            return "\(LocalizationManager.shared.localized(.editorWorkOut)) \(LocalizationManager.shared.localized(.workNextDayPrefix)) \(time)"
        }
        return "\(LocalizationManager.shared.localized(.editorWorkOut)) \(time)"
    }

    private func effectiveClockOutTime(_ clockOut: EventOccurrence) -> Date {
        let outTime = clockOut.actualWorkClockDate
        guard let clockInTime = session.clockIn?.actualWorkClockDate else {
            return outTime
        }
        let calendar = Calendar.current
        guard calendar.isDate(outTime, inSameDayAs: clockInTime), outTime <= clockInTime else {
            return outTime
        }
        return calendar.date(byAdding: .day, value: 1, to: outTime) ?? outTime
    }

    private func isNextDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: selectedDate)
    }

    private func formatTime(_ date: Date) -> String {
        LocalizationManager.shared.dateFormatter(dateFormat: "HH:mm").string(from: date)
    }
}

struct EventRowView: View {
    let event: EventOccurrence
    let selectedDate: Date
    let dayEvents: [EventOccurrence]
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Text(event.localizedDisplayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if event.isAllDay {
                    Text(LocalizationManager.shared.localized(.editorAllDay))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(eventTimeText(for: event))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .accessibilityIdentifier("event.edit")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .accessibilityIdentifier("event.delete")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func eventTimeText(for event: EventOccurrence) -> String {
        if event.isClockInEvent {
            return formatTime(event.workInfo?.workInTime ?? event.startDate) ?? ""
        }
        if event.isClockOutEvent {
            guard event.isWorkOutTimeSet else {
                return LocalizationManager.shared.localized(.workRecordMissingClockOut)
            }
            let clockOutTime = event.workInfo?.workOutTime ?? event.startDate
            let time = formatTime(clockOutTime) ?? ""
            if isNextDayClockOut(clockOutTime, event: event) {
                return "\(LocalizationManager.shared.localized(.workNextDayPrefix)) \(time)"
            }
            return time
        }
        guard let start = formatTime(event.startDate), let end = formatTime(event.endDate) else {
            return ""
        }
        return "\(start) - \(end)"
    }

    private func isNextDayClockOut(_ clockOutTime: Date, event: EventOccurrence) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let detailDay = calendar.startOfDay(for: selectedDate)
        let clockOutDay = calendar.startOfDay(for: clockOutTime)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: detailDay) else {
            return false
        }
        if clockOutDay == nextDay {
            return true
        }

        guard clockOutDay == detailDay,
              let clockInTime = matchingClockInTime(for: event),
              calendar.isDate(clockInTime, inSameDayAs: detailDay)
        else {
            return false
        }
        return clockOutTime <= clockInTime
    }

    private func matchingClockInTime(for clockOutEvent: EventOccurrence) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        let detailDay = calendar.startOfDay(for: selectedDate)
        let clockIns = dayEvents
            .filter { event in
                guard event.isClockInEvent else { return false }
                return calendar.isDate(event.workDate, inSameDayAs: detailDay)
            }
            .sorted { $0.actualWorkClockDate > $1.actualWorkClockDate }

        if let sessionId = clockOutEvent.workInfo?.workSessionId,
           let sameSessionClockIn = clockIns.first(where: { $0.workInfo?.workSessionId == sessionId }) {
            return sameSessionClockIn.actualWorkClockDate
        }
        return clockIns.first?.actualWorkClockDate
    }

    private func formatTime(_ date: Date) -> String? {
        LocalizationManager.shared.dateFormatter(dateFormat: "HH:mm").string(from: date)
    }
}
