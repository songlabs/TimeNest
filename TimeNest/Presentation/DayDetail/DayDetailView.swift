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

private struct DayDetailAddEntryRoute: Identifiable {
    let kind: EntryEditorKind

    var id: EntryEditorKind {
        kind
    }
}

struct DayDetailEventSectionVisibility: Equatable {
    let showsSection: Bool
    let showsAddButton: Bool

    init(hasEvents: Bool, allowsCreating: Bool) {
        showsSection = hasEvents || allowsCreating
        showsAddButton = allowsCreating
    }
}

struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    let cell: CalendarDayCell
    let onDeleteEvent: (UUID) -> Void
    let onDeleteWorkRecord: ([UUID]) -> Void
    let onLoadEntry: UnifiedEntryEditorLoadAction
    let onSaveEntry: UnifiedEntryEditorSaveAction
    var availableCalendars: [TimeNestCalendar] = []
    var entryCalendarContext: EntryCalendarContext = .fixedWritableCalendar(TimeNestCalendar.personalID)

    @State private var editingUnifiedEntry: UnifiedEntryEditorInitialState?
    @State private var addEntryRoute: DayDetailAddEntryRoute?
    @State private var entryLoadErrorMessage: String?

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

                    if shouldShowEventsSection {
                        eventsSection
                    }

                    if shouldShowWorkRecordsSection {
                        workRecordsSection
                    }
                }
                .padding(.horizontal, DayDetailLayout.horizontalPadding)
                .padding(.top, DayDetailLayout.contentTopPadding)
                .padding(.bottom, DayDetailLayout.bottomPadding)
            }
            .accessibilityIdentifier("dayDetail.content")
        }
        .background(SettingsModalSurface.background)
        .presentationDetents([.fraction(DayDetailLayout.presentationHeightFraction)])
        .sheet(item: $addEntryRoute) { route in
            let initialDate = cell.date.toDate()
            EventEditorView(
                isPresented: addEntryPresentationBinding,
                mode: .create(initialDate: initialDate),
                existingEvents: cell.events,
                initialEntryKind: route.kind,
                availableCalendars: availableCalendars,
                calendarContext: entryCalendarContext,
                onSaveEntry: onSaveEntry
            )
        }
        .sheet(item: $editingUnifiedEntry) { state in
            EventEditorView(
                isPresented: editingPresentationBinding,
                mode: .editUnified(state),
                existingEvents: cell.events,
                availableCalendars: availableCalendars,
                calendarContext: .fixedWritableCalendar(
                    state.event?.calendarID
                        ?? state.workRecord?.calendarID
                        ?? TimeNestCalendar.personalID
                ),
                onSaveEntry: onSaveEntry
            )
        }
        .alert(
            localization.localized(.calendarSharingErrorTitle),
            isPresented: Binding(
                get: { entryLoadErrorMessage != nil },
                set: { if !$0 { entryLoadErrorMessage = nil } }
            )
        ) {
            Button(localization.localized(.ok)) {
                entryLoadErrorMessage = nil
            }
        } message: {
            Text(entryLoadErrorMessage ?? "")
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
                .accessibilityIdentifier("event.list")

            ForEach(eventDisplayItems) { item in
                if let event = item.event {
                    EventRowView(
                        event: event,
                        workRecord: item.workRecord,
                        selectedDate: cell.date.toDate(),
                        dayEvents: cell.events,
                        onDelete: {
                            onDeleteEvent(event.eventID)
                        },
                        onEdit: {
                            openEditor(for: event)
                        },
                        onDeleteWorkRecord: {
                            guard let workRecord = item.workRecord else { return }
                            onDeleteWorkRecord(workRecord.eventIDs)
                        },
                        onEditWorkRecord: {
                            guard let workRecord = item.workRecord else { return }
                            openEditor(for: workRecord)
                        }
                    )
                }
            }

            if eventSectionVisibility.showsAddButton {
                addEventButton
                    .frame(maxWidth: .infinity)
                    .padding(.top, DayDetailLayout.sectionButtonTopSpacing)
            }
        }
    }

    private var workRecordsSection: some View {
        VStack(alignment: .leading, spacing: DayDetailLayout.sectionSpacing) {
            Text(localization.localized(.workRecordSectionTitle))
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
                .accessibilityIdentifier("workRecord.list")

            if standaloneWorkRecordSessions.isEmpty {
                TimeNestActionableEmptyStateView(
                    actionTitle: localization.localized(.workRecordAdd),
                    containerIdentifier: "workRecord.empty",
                    actionIdentifier: "workRecord.empty.create",
                    action: { presentAddEntry(kind: .workRecord) }
                )
            } else {
                ForEach(standaloneWorkRecordSessions) { session in
                    WorkRecordSessionRowView(
                        session: session,
                        selectedDate: cell.date.toDate(),
                        onEdit: {
                            openEditor(for: session)
                        },
                        onDelete: {
                            onDeleteWorkRecord(session.eventIDs)
                        }
                    )
                }
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
        .accessibilityIdentifier("event.add")
    }

    private var displayItems: [LinkedEntryDisplayItem] {
        LinkedEntryDisplayAssembler.make(
            from: cell.events,
            selectedDate: cell.date.toDate()
        )
    }

    private var eventDisplayItems: [LinkedEntryDisplayItem] {
        displayItems.filter { $0.event != nil }
    }

    private var standaloneWorkRecordSessions: [WorkRecordDisplaySession] {
        displayItems.compactMap { item in
            guard item.event == nil else { return nil }
            return item.workRecord
        }
    }

    private var shouldShowEventsSection: Bool {
        eventSectionVisibility.showsSection
    }

    private var eventSectionVisibility: DayDetailEventSectionVisibility {
        DayDetailEventSectionVisibility(
            hasEvents: !eventDisplayItems.isEmpty,
            allowsCreating: entryCalendarContext.allowsEditing
        )
    }

    private var shouldShowWorkRecordsSection: Bool {
        displayItems.isEmpty || !standaloneWorkRecordSessions.isEmpty
    }

    private func openEditor(for event: EventOccurrence) {
        loadEditor(
            for: .event(eventID: event.eventID)
        )
    }

    private func openEditor(for session: WorkRecordDisplaySession) {
        loadEditor(
            for: .workRecord(
                clockInEventID: session.clockIn?.eventID,
                clockOutEventID: session.clockOut?.eventID,
                workSessionID: session.workSessionId
            )
        )
    }

    private func loadEditor(for request: UnifiedEntryLoadRequest) {
        entryLoadErrorMessage = nil
        Task {
            do {
                editingUnifiedEntry = try await onLoadEntry(request)
            } catch {
                entryLoadErrorMessage = error.localizedDescription
            }
        }
    }

    private func presentAddEntry(kind: EntryEditorKind) {
        addEntryRoute = DayDetailAddEntryRoute(kind: kind)
    }

    private var addEntryPresentationBinding: Binding<Bool> {
        Binding(
            get: { addEntryRoute != nil },
            set: { isPresented in
                if !isPresented {
                    addEntryRoute = nil
                }
            }
        )
    }

    private var editingPresentationBinding: Binding<Bool> {
        Binding(
            get: { editingUnifiedEntry != nil },
            set: { isPresented in
                if !isPresented {
                    editingUnifiedEntry = nil
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
                    .accessibilityIdentifier("workRecord.primaryContent")

                Text(session.timeRangeText(selectedDate: selectedDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workRecord.row")
    }

}

struct EventRowView: View {
    let event: EventOccurrence
    let workRecord: WorkRecordDisplaySession?
    let selectedDate: Date
    let dayEvents: [EventOccurrence]
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onDeleteWorkRecord: () -> Void
    let onEditWorkRecord: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Text(event.localizedDisplayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .accessibilityIdentifier("event.primaryContent")
                        .accessibilityValue(event.eventID.uuidString)

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
                .contentShape(Rectangle())
                .onTapGesture(perform: onEdit)

                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .accessibilityLabel(LocalizationManager.shared.localized(.editorEditEvent))
                .accessibilityIdentifier("event.edit")
                .accessibilityValue(event.eventID.uuidString)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .accessibilityIdentifier("event.delete")
                .accessibilityValue(event.eventID.uuidString)
            }

            if let workRecord {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "briefcase")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(workRecord.timeRangeText(selectedDate: selectedDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("event.linkedWorkRecord")
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onEditWorkRecord)

                    Button(action: onEditWorkRecord) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel(LocalizationManager.shared.localized(.workRecordEdit))
                    .accessibilityIdentifier("workRecord.edit")

                    Button(action: onDeleteWorkRecord) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .accessibilityIdentifier("workRecord.delete")
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("event.row")
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
