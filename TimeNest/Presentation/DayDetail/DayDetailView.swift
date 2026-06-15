import SwiftUI

struct DayDetailView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let cell: CalendarDayCell
    let onDeleteEvent: (UUID) -> Void
    let onCreateEvent: (String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> Void
    let onUpdateEvent: (UUID, String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> Void

    @State private var editingEvent: EditingEvent?
    @State private var showingAddEvent: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dateAndHolidaySection

                    Divider()

                    eventsSection
                }
                .padding()
            }
            .navigationTitle(localization.localized(.dayDetailTitle))
            .sheet(isPresented: $showingAddEvent) {
                let initialDate = cell.date.toDate()
                EventEditorView(
                    isPresented: $showingAddEvent,
                    mode: .create(initialDate: initialDate),
                    existingEvents: cell.events,
                    onSave: { title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo in
                        try await onCreateEvent(title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo)
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
                    onSave: { newTitle, newNote, newStartDate, newEndDate, newIsAllDay, newReminderOffsetMinutes, newShiftTemplateID, workInfo in
                        try await onUpdateEvent(event.eventID, newTitle, newNote, newStartDate, newEndDate, newIsAllDay, newReminderOffsetMinutes, newShiftTemplateID, workInfo)
                    }
                )
            }
        }
    }

    private var dateAndHolidaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateTitle)
                .font(.title)
                .fontWeight(.semibold)

            if !cell.holidays.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(cell.holidays, id: \.id) { holiday in
                        Text(localizedHolidayName(holiday))
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if cell.events.isEmpty {
                VStack(spacing: 16) {
                    Text(localization.localized(.dayDetailNoEvents))
                        .foregroundColor(.secondary)

                    addEventButton
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(cell.events, id: \.id) { event in
                    EventRowView(
                        event: event,
                        onDelete: {
                            onDeleteEvent(event.eventID)
                        },
                        onEdit: {
                            openEditor(for: event)
                        }
                    )
                }

                addEventButton
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
    }

    private var addEventButton: some View {
        Button(action: {
            showingAddEvent = true
        }) {
            Text(localization.localized(.dayDetailAddEvent))
                .fontWeight(.medium)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    private func openEditor(for event: EventOccurrence) {
        editingEvent = EditingEvent(event)
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

struct EventRowView: View {
    let event: EventOccurrence
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
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

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
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
            let clockOutTime = event.workInfo?.workOutTime ?? event.startDate
            let time = formatTime(clockOutTime) ?? ""
            if Calendar(identifier: .gregorian).startOfDay(for: clockOutTime) > Calendar(identifier: .gregorian).startOfDay(for: event.workDate) {
                return "\(LocalizationManager.shared.localized(.workNextDayPrefix)) \(time)"
            }
            return time
        }
        guard let start = formatTime(event.startDate), let end = formatTime(event.endDate) else {
            return ""
        }
        return "\(start) - \(end)"
    }

    private func formatTime(_ date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    DayDetailView(
        cell: CalendarDayCell(
            id: "2026-05-27",
            date: DateOnly(year: 2026, month: 5, day: 27),
            dayText: "27",
            weekdayText: "二",
            holidays: [],
            events: [],
            isToday: false,
            isWeekend: false,
            isInCurrentMonth: true,
            shiftType: "早班",
            eventMarkers: []
        ),
        onDeleteEvent: { _ in },
        onCreateEvent: { _, _, _, _, _, _, _, _ in },
        onUpdateEvent: { _, _, _, _, _, _, _, _, _ in }
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
}
#endif
