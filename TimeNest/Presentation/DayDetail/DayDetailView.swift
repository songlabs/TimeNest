import SwiftUI

struct DayDetailView: View {
    let cell: CalendarDayCell
    let onDeleteEvent: (UUID) -> Void
    let onUpdateEvent: (UUID, String, Date, Bool) async -> Void

    @State private var showingEditor: Bool = false
    @State private var editingEventID: UUID?
    @State private var editingEventTitle: String = ""
    @State private var editingEventDate: Date = Date()
    @State private var editingEventIsAllDay: Bool = false

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
            .navigationTitle("予定")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditor) {
                if let eventID = editingEventID {
                    EventEditorView(
                        isPresented: $showingEditor,
                        mode: .edit(
                            eventID: eventID,
                            initialTitle: editingEventTitle,
                            initialDate: editingEventDate,
                            initialIsAllDay: editingEventIsAllDay
                        ),
                        onSave: { newTitle, newDate, newIsAllDay in
                            await onUpdateEvent(eventID, newTitle, newDate, newIsAllDay)
                        }
                    )
                }
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
                        Text(holiday.localizedNames.zhHans)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("予定")
                .font(.title2)
                .fontWeight(.semibold)

            if cell.events.isEmpty {
                Text("予定はありません")
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
        editingEventID = event.eventID
        editingEventTitle = event.title
        editingEventDate = event.startDate
        editingEventIsAllDay = false
        showingEditor = true
    }

    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy 年 M 月 d 日"
        let date = cell.date.toDate()
        return formatter.string(from: date)
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

                if let start = formatTime(event.startDate),
                   let end = formatTime(event.endDate ?? event.startDate) {
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

