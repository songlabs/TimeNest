import SwiftUI

struct DayDetailView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let cell: CalendarDayCell
    let onDeleteEvent: (UUID) -> Void
    let onUpdateEvent: (UUID, String, String?, Date, Date, Bool, Int?) async throws -> Void

    @State private var editingEvent: EditingEvent?

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
                        initialReminderOffsetMinutes: event.reminderOffsetMinutes
                    ),
                    onSave: { newTitle, newNote, newStartDate, newEndDate, newIsAllDay, newReminderOffsetMinutes in
                        try await onUpdateEvent(event.eventID, newTitle, newNote, newStartDate, newEndDate, newIsAllDay, newReminderOffsetMinutes)
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
            Text(localization.localized(.dayDetailTitle))
                .font(.title2)
                .fontWeight(.semibold)

            if cell.events.isEmpty {
                Text(localization.localized(.dayDetailNoEvents))
                    .foregroundColor(.secondary)
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
            }
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
        let language = localization.currentLanguage
        let names = holiday.localizedNames

        // 优先返回当前语言对应的名称，如果没有则按 fallback 顺序返回
        switch language {
        case .ja:
            return names.ja.isEmpty ? localizedHolidayNameFallback(names) : names.ja
        case .zhHans, .system:
            return names.zhHans.isEmpty ? localizedHolidayNameFallback(names) : names.zhHans
        case .ko:
            return names.ko.isEmpty ? localizedHolidayNameFallback(names) : names.ko
        case .enUS:
            return names.enUS.isEmpty ? localizedHolidayNameFallback(names) : names.enUS
        }
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

    init(_ event: EventOccurrence) {
        id = event.id
        eventID = event.eventID
        title = event.title
        note = event.note
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        reminderOffsetMinutes = event.reminderOffsetMinutes
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
                } else if let start = formatTime(event.startDate),
                          let end = formatTime(event.endDate) {
                    Text("\(start) - \(end)")
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
        onUpdateEvent: { _, _, _, _, _, _, _ in }
    )
    .environmentObject(LocalizationManager.preview(languageCode: "ja"))
}
#endif
