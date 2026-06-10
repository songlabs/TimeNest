import SwiftUI

enum EventEditorMode {
    case create(initialDate: Date)
    case edit(
        eventID: UUID,
        initialTitle: String,
        initialStartDate: Date,
        initialEndDate: Date,
        initialIsAllDay: Bool,
        initialReminderOffsetMinutes: Int?
    )
}

struct EventEditorView: View {
    @Environment(\.localization) private var localization
    @Binding var isPresented: Bool
    let mode: EventEditorMode
    var onSave: (String, Date, Date, Bool, Int?) async throws -> Void

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var reminderOffsetMinutes: Int?
    @State private var saving: Bool = false
    @State private var errorMessage: String?

    private let reminderOptions: [Int?] = [nil, 0, 5, 10, 15, 30, 60, 1440]

    init(
        isPresented: Binding<Bool>,
        mode: EventEditorMode,
        onSave: @escaping (String, Date, Date, Bool, Int?) async throws -> Void
    ) {
        _isPresented = isPresented
        self.mode = mode
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                TextField(localization.localized(.editorTitle), text: $title)
            } header: {
                Text(localization.localized(.editorBasicInfo))
            }

            Section {
                DatePicker(
                    localization.localized(.editorStart),
                    selection: $startDate,
                    displayedComponents: datePickerComponents
                )
                .onChange(of: startDate) { _, newValue in
                    adjustEndDateIfNeeded(for: newValue)
                }

                DatePicker(
                    localization.localized(.editorEnd),
                    selection: $endDate,
                    displayedComponents: datePickerComponents
                )

                Toggle(localization.localized(.editorAllDay), isOn: $isAllDay)
                    .onChange(of: isAllDay) { _, newValue in
                        normalizeForAllDayChange(newValue)
                    }

                Picker(localization.localized(.editorReminder), selection: $reminderOffsetMinutes) {
                    ForEach(reminderOptions.indices, id: \.self) { index in
                        let option = reminderOptions[index]
                        Text(reminderTitle(for: option)).tag(option as Int?)
                    }
                }
            } header: {
                Text(localization.localized(.editorTime))
            }

            if let validationMessage = validationMessage ?? errorMessage {
                Section {
                    Text(validationMessage)
                        .foregroundColor(.red)
                } header: {
                    Text(localization.localized(.editorError))
                }
            }

            Section {
                Button(localization.localized(.editorSave)) {
                    Task {
                        await save()
                    }
                }
                .disabled(!canSave || saving)
            }

            Section {
                Button(localization.localized(.editorCancel), role: .cancel) {
                    isPresented = false
                }
            }
        }
        .navigationTitle(isEditing ? localization.localized(.editorEditEvent) : localization.localized(.editorNewEvent))
        .disabled(saving)
        .onAppear {
            setupInitialState()
        }
    }

    private var isEditing: Bool {
        switch mode {
        case .create:
            return false
        case .edit:
            return true
        }
    }

    private var datePickerComponents: DatePickerComponents {
        isAllDay ? [.date] : [.date, .hourAndMinute]
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validationMessage == nil
    }

    private var validationMessage: String? {
        let normalized = normalizedDates()
        guard normalized.end > normalized.start else {
            return localization.localized(.editorInvalidDateRange)
        }
        return nil
    }

    private func setupInitialState() {
        switch mode {
        case .create(let initialDate):
            title = ""
            startDate = initialDate
            endDate = CalendarEvent.defaultEndDate(for: initialDate, isAllDay: false)
            isAllDay = false
            reminderOffsetMinutes = nil
        case .edit(_, let initialTitle, let initialStartDate, let initialEndDate, let initialIsAllDay, let initialReminderOffsetMinutes):
            title = initialTitle
            startDate = initialStartDate
            endDate = initialEndDate
            isAllDay = initialIsAllDay
            reminderOffsetMinutes = initialReminderOffsetMinutes
        }
    }

    private func save() async {
        guard canSave else { return }
        saving = true
        errorMessage = nil

        do {
            let normalized = normalizedDates()
            try await onSave(title, normalized.start, normalized.end, isAllDay, reminderOffsetMinutes)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }

        saving = false
    }

    private func normalizedDates() -> (start: Date, end: Date) {
        let calendar = Calendar(identifier: .gregorian)
        if isAllDay {
            let start = calendar.startOfDay(for: startDate)
            let endDay = calendar.startOfDay(for: endDate)
            let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
            return (start, end)
        }
        return (startDate, endDate)
    }

    private func adjustEndDateIfNeeded(for newStartDate: Date) {
        guard !isAllDay, endDate <= newStartDate else { return }
        endDate = CalendarEvent.defaultEndDate(for: newStartDate, isAllDay: false)
    }

    private func normalizeForAllDayChange(_ allDay: Bool) {
        let calendar = Calendar(identifier: .gregorian)
        if allDay {
            startDate = calendar.startOfDay(for: startDate)
            if endDate < startDate {
                endDate = startDate
            }
        } else {
            let startDay = calendar.startOfDay(for: startDate)
            if startDate == startDay {
                startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startDate) ?? startDate
            }
            if endDate <= startDate {
                endDate = CalendarEvent.defaultEndDate(for: startDate, isAllDay: false)
            }
        }
    }

    private func reminderTitle(for offset: Int?) -> String {
        switch offset {
        case nil:
            return localization.localized(.reminderNone)
        case 0:
            return localization.localized(.reminderAtStart)
        case 5:
            return localization.localized(.reminderFiveMinutesBefore)
        case 10:
            return localization.localized(.reminderTenMinutesBefore)
        case 15:
            return localization.localized(.reminderFifteenMinutesBefore)
        case 30:
            return localization.localized(.reminderThirtyMinutesBefore)
        case 60:
            return localization.localized(.reminderOneHourBefore)
        case 1440:
            return localization.localized(.reminderOneDayBefore)
        default:
            return localization.localized(.reminderNone)
        }
    }
}
