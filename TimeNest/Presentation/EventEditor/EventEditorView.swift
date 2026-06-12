import SwiftUI

enum EventEditorMode {
    case create(initialDate: Date)
    case edit(
        eventID: UUID,
        initialTitle: String,
        initialNote: String?,
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
    var onSave: (String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?) async throws -> Void

    @State private var title: String
    @State private var note: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var reminderOffsetMinutes: Int?
    @State private var selectedShiftTemplateID: ShiftTimeTemplateID?
    @State private var saving: Bool = false
    @State private var errorMessage: String?


    private let reminderOptions: [Int?] = [nil, 0, 5, 10, 15, 30, 60, 1440]

    init(
        isPresented: Binding<Bool>,
        mode: EventEditorMode,
        onSave: @escaping (String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?) async throws -> Void
    ) {
        _isPresented = isPresented
        self.mode = mode
        self.onSave = onSave

        let initialState = EventEditorView.initialState(for: mode)
        _title = State(initialValue: initialState.title)
        _note = State(initialValue: initialState.note ?? "")
        _startDate = State(initialValue: initialState.startDate)
        _endDate = State(initialValue: initialState.endDate)
        _isAllDay = State(initialValue: initialState.isAllDay)
        _reminderOffsetMinutes = State(initialValue: initialState.reminderOffsetMinutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(localization.localized(.editorTitle), text: $title)
                } header: {
                    Text(localization.localized(.editorBasicInfo))
                }

                Section {
                    EventTimeCompactRow(
                        startDate: $startDate,
                        endDate: $endDate,
                        isAllDay: $isAllDay,
                        allDayTitle: localization.localized(.editorAllDay),
                        datePickerComponents: datePickerComponents
                    )
                    .onChange(of: startDate) { _, newValue in
                        adjustEndDateIfNeeded(for: newValue)
                    }
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

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                        ForEach(shiftTemplates) { template in
                            Button {
                                applyShiftTemplate(template)
                            } label: {
                                Text(template.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(template.buttonTextColor)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 4)
                                    .background(template.color.opacity(0.2))
                                    .cornerRadius(6)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text(localization.localized(.shiftCommon))
                }

                if let validationMessage = validationMessage ?? errorMessage {
                    Section {
                        Text(validationMessage)
                            .foregroundColor(.red)
                    } header: {
                        Text(localization.localized(.editorError))
                    }
                }
            }
            .disabled(saving)
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.editorCancel), role: .cancel) {
                        isPresented = false
                    }
                    .disabled(saving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.localized(.editorSave)) {
                        Task {
                            await save()
                        }
                    }
                    .disabled(!canSave || saving)
                }
            }
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

    private var editorTitle: String {
        isEditing ? localization.localized(.editorEditEvent) : localization.localized(.editorNewEvent)
    }

    private var datePickerComponents: DatePickerComponents {
        isAllDay ? [.date] : [.date, .hourAndMinute]
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validationMessage == nil
    }

    private var shiftTemplates: [ShiftTimeTemplate] {
        ShiftTimeTemplate.enabled()
    }

    private var validationMessage: String? {
        let normalized = normalizedDates()
        guard normalized.end > normalized.start else {
            return localization.localized(.editorInvalidDateRange)
        }
        return nil
    }

    private static func initialState(for mode: EventEditorMode) -> (title: String, note: String?, startDate: Date, endDate: Date, isAllDay: Bool, reminderOffsetMinutes: Int?) {
        switch mode {
        case .create(let initialDate):
            return (
                title: "",
                note: nil,
                startDate: initialDate,
                endDate: CalendarEvent.defaultEndDate(for: initialDate, isAllDay: false),
                isAllDay: false,
                reminderOffsetMinutes: nil
            )
        case .edit(_, let initialTitle, let initialNote, let initialStartDate, let initialEndDate, let initialIsAllDay, let initialReminderOffsetMinutes):
            return (
                title: initialTitle,
                note: initialNote,
                startDate: initialStartDate,
                endDate: initialEndDate,
                isAllDay: initialIsAllDay,
                reminderOffsetMinutes: initialReminderOffsetMinutes
            )
        }
    }

    private func save() async {
        guard canSave else { return }
        saving = true
        errorMessage = nil

        do {
            let normalized = normalizedDates()
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            try await onSave(title, trimmedNote.isEmpty ? nil : trimmedNote, normalized.start, normalized.end, isAllDay, reminderOffsetMinutes, selectedShiftTemplateID)
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

    private func applyShiftTemplate(_ template: ShiftTimeTemplate) {
        guard let startTime = template.startHourMinute,
              let endTime = template.endHourMinute else { return }

        let calendar = Calendar(identifier: .gregorian)
        let baseDate = calendar.startOfDay(for: startDate)
        let start = calendar.date(
            bySettingHour: startTime.hour,
            minute: startTime.minute,
            second: 0,
            of: baseDate
        ) ?? startDate

        let endBaseDate: Date
        if endTime.hour < startTime.hour || (endTime.hour == startTime.hour && endTime.minute <= startTime.minute) {
            endBaseDate = calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
        } else {
            endBaseDate = baseDate
        }

        let end = calendar.date(
            bySettingHour: endTime.hour,
            minute: endTime.minute,
            second: 0,
            of: endBaseDate
        ) ?? CalendarEvent.defaultEndDate(for: start, isAllDay: false)

        isAllDay = false
        startDate = start
        endDate = end
        selectedShiftTemplateID = template.id

        // 只有当标题为空或标题是默认班次名称时才覆盖
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           isDefaultShiftTitle(title) {
            title = template.displayName
        }
    }

    /// 判断标题是否为任意一个启用班次模板的显示名称
    private func isDefaultShiftTitle(_ title: String) -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return shiftTemplates.contains { $0.displayName == normalizedTitle }
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

private struct EventTimeCompactRow: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isAllDay: Bool
    let allDayTitle: String
    let datePickerComponents: DatePickerComponents

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(format: .full)
            row(format: .short)
            row(format: .compact)
        }
        .font(.subheadline)
        .frame(minHeight: 36)
        .accessibilityElement(children: .contain)
    }

    private func row(format: TimeDisplayFormat) -> some View {
        HStack(spacing: format.spacing) {
            EditableDateText(
                date: $startDate,
                text: formatted(startDate, role: .start, format: format),
                components: datePickerComponents
            )

            Text(format.separator)
                .foregroundStyle(.secondary)
                .fixedSize()

            EditableDateText(
                date: $endDate,
                text: formatted(endDate, role: .end, format: format),
                components: datePickerComponents
            )

            Spacer(minLength: 4)

            Toggle(isOn: $isAllDay) {
                Text(allDayTitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .toggleStyle(.switch)
            .fixedSize()
            .controlSize(.small)
        }
        .lineLimit(1)
    }

    private func formatted(_ date: Date, role: TimeRole, format: TimeDisplayFormat) -> String {
        if isAllDay {
            switch format {
            case .full:
                return date.formatted(with: "yyyy/MM/dd")
            case .short, .compact:
                return date.formatted(with: "MM/dd")
            }
        }

        switch format {
        case .full:
            return date.formatted(with: "yyyy/MM/dd H:mm")
        case .short:
            return date.formatted(with: "MM/dd H:mm")
        case .compact:
            if role == .end && Calendar.current.isDate(startDate, inSameDayAs: endDate) {
                return date.formatted(with: "HH:mm")
            }
            return date.formatted(with: "MM/dd HH:mm")
        }
    }
}

private struct EditableDateText: View {
    @Binding var date: Date
    let text: String
    let components: DatePickerComponents

    var body: some View {
        Text(text)
            .foregroundStyle(.primary)
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .overlay {
                DatePicker("", selection: $date, displayedComponents: components)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .opacity(0.02)
            }
    }
}

private enum TimeDisplayFormat {
    case full
    case short
    case compact

    var separator: String {
        switch self {
        case .full, .short:
            return "～"
        case .compact:
            return "～"
        }
    }

    var spacing: CGFloat {
        switch self {
        case .full, .short:
            return 6
        case .compact:
            return 0
        }
    }
}

private enum TimeRole {
    case start
    case end
}

private extension Date {
    func formatted(with dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dateFormat
        return formatter.string(from: self)
    }
}
