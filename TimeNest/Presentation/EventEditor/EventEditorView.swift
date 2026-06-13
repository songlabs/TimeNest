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
    @State private var showingStartDatePicker: Bool = false
    @State private var showingStartTimePicker: Bool = false
    @State private var showingEndDatePicker: Bool = false
    @State private var showingEndTimePicker: Bool = false


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
                }

                Section {
                    EventTimeSection(
                        startDate: $startDate,
                        endDate: $endDate,
                        isAllDay: $isAllDay,
                        allDayTitle: localization.localized(.editorAllDay),
                        showingStartDatePicker: $showingStartDatePicker,
                        showingStartTimePicker: $showingStartTimePicker,
                        showingEndDatePicker: $showingEndDatePicker,
                        showingEndTimePicker: $showingEndTimePicker
                    )
                    .onChange(of: isAllDay) { _, newValue in
                        normalizeForAllDayChange(newValue)
                    }

                    Picker(localization.localized(.editorReminder), selection: $reminderOffsetMinutes) {
                        ForEach(reminderOptions.indices, id: \.self) { index in
                            let option = reminderOptions[index]
                            Text(reminderTitle(for: option)).tag(option as Int?)
                        }
                    }
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

private struct EventTimeSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isAllDay: Bool
    let allDayTitle: String
    @Binding var showingStartDatePicker: Bool
    @Binding var showingStartTimePicker: Bool
    @Binding var showingEndDatePicker: Bool
    @Binding var showingEndTimePicker: Bool

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 第一行：終日 + Toggle，独立一行
            HStack {
                Text(allDayTitle)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Toggle("", isOn: $isAllDay)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            // 第二行：開始 + 日期/时间按钮
            HStack(alignment: .center, spacing: 8) {
                Text("開始")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)

                HStack(spacing: 8) {
                    // 日期按钮
                    Button {
                        showingStartDatePicker = true
                    } label: {
                        Text(formatDateOnly(startDate))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    // 时间按钮
                    Button {
                        showingStartTimePicker = true
                    } label: {
                        Text(formatTimeOnly(startDate))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .sheet(isPresented: $showingStartDatePicker) {
                TimePickerSheet(
                    startDate: $startDate,
                    endDate: $endDate,
                    isAllDay: isAllDay,
                    mode: .startDate
                )
            }
            .sheet(isPresented: $showingStartTimePicker) {
                TimePickerSheet(
                    startDate: $startDate,
                    endDate: $endDate,
                    isAllDay: isAllDay,
                    mode: .startTime
                )
            }

            // 第三行：終了 + 日期/时间按钮
            HStack(alignment: .center, spacing: 8) {
                Text("終了")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)

                HStack(spacing: 8) {
                    // 日期按钮
                    Button {
                        showingEndDatePicker = true
                    } label: {
                        Text(formatDateOnly(endDate))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    // 时间按钮
                    Button {
                        showingEndTimePicker = true
                    } label: {
                        Text(formatTimeOnly(endDate))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .sheet(isPresented: $showingEndDatePicker) {
                TimePickerSheet(
                    startDate: $startDate,
                    endDate: $endDate,
                    isAllDay: isAllDay,
                    mode: .endDate
                )
            }
            .sheet(isPresented: $showingEndTimePicker) {
                TimePickerSheet(
                    startDate: $startDate,
                    endDate: $endDate,
                    isAllDay: isAllDay,
                    mode: .endTime
                )
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDateOnly(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private func formatTimeOnly(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}

private enum TimePickerMode {
    case startDate
    case startTime
    case endDate
    case endTime
}

private struct TimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date
    @Binding var endDate: Date
    let isAllDay: Bool
    let mode: TimePickerMode

    @State private var tempDate: Date

    private var datePickerTitle: String {
        switch mode {
        case .startDate:
            return "选择开始日期"
        case .startTime:
            return "选择开始时间"
        case .endDate:
            return "选择结束日期"
        case .endTime:
            return "选择结束时间"
        }
    }

    init(startDate: Binding<Date>, endDate: Binding<Date>, isAllDay: Bool, mode: TimePickerMode) {
        _startDate = startDate
        _endDate = endDate
        self.isAllDay = isAllDay
        self.mode = mode
        
        // 根据模式初始化 tempDate
        switch mode {
        case .startDate, .startTime:
            _tempDate = State(initialValue: startDate.wrappedValue)
        case .endDate, .endTime:
            _tempDate = State(initialValue: endDate.wrappedValue)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if isAllDay {
                            // 全天模式：只显示日期选择
                            DatePicker(
                                "",
                                selection: $tempDate,
                                in: dateRangeForMode(),
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                        } else {
                            // 非全天模式：根据模式显示日期或时间
                            switch mode {
                            case .startDate, .endDate:
                                // 日期选择：只显示日期
                                DatePicker(
                                    "",
                                    selection: $tempDate,
                                    in: dateRangeForMode(),
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.graphical)
                                
                            case .startTime, .endTime:
                                // 时间选择：只显示时间
                                DatePicker(
                                    "",
                                    selection: $tempDate,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(.wheel)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(datePickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedString("完了")) {
                        commitSelection()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("取消")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func dateRangeForMode() -> ClosedRange<Date> {
        let calendar = Calendar(identifier: .gregorian)
        // 允许选择前后 10 年的日期，不限制开始/结束日期的相对关系
        let calendarStart = calendar.startOfDay(for: Date())
        let minDate = calendar.date(byAdding: .year, value: -10, to: calendarStart) ?? calendarStart
        let maxDate = calendar.date(byAdding: .year, value: 10, to: calendarStart) ?? calendarStart
        
        // 所有模式都允许自由选择任意日期
        return minDate...maxDate
    }

    private func commitSelection() {
        let calendar = Calendar(identifier: .gregorian)
        
        switch mode {
        case .startDate:
            // 只更新开始日期的年月日，保留原来的时分
            let timeComponent = calendar.dateComponents([.hour, .minute, .second], from: startDate)
            let newDate = calendar.date(bySettingHour: timeComponent.hour ?? 0,
                                        minute: timeComponent.minute ?? 0,
                                        second: timeComponent.second ?? 0,
                                        of: tempDate) ?? tempDate
            startDate = newDate
            // 如果修改后 endDate <= startDate，自动修正 endDate
            if endDate <= startDate {
                endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
            }
            
        case .startTime:
            // 只更新开始时间的时分秒，保留原来的年月日
            let dateComponent = calendar.dateComponents([.year, .month, .day], from: startDate)
            let timeDate = calendar.date(from: dateComponent) ?? startDate
            let newDate = calendar.date(bySettingHour: calendar.component(.hour, from: tempDate),
                                        minute: calendar.component(.minute, from: tempDate),
                                        second: calendar.component(.second, from: tempDate),
                                        of: timeDate) ?? timeDate
            startDate = newDate
            // 如果修改后 endDate <= startDate，自动修正 endDate
            if endDate <= startDate {
                endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
            }
            
        case .endDate:
            // 只更新结束日期的年月日，保留原来的时分
            let timeComponent = calendar.dateComponents([.hour, .minute, .second], from: endDate)
            let newDate = calendar.date(bySettingHour: timeComponent.hour ?? 0,
                                        minute: timeComponent.minute ?? 0,
                                        second: timeComponent.second ?? 0,
                                        of: tempDate) ?? tempDate
            endDate = newDate
            // 如果修改后 endDate <= startDate，自动修正 startDate
            if endDate <= startDate {
                startDate = calendar.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
            }
            
        case .endTime:
            // 只更新结束时间的时分秒，保留原来的年月日
            let dateComponent = calendar.dateComponents([.year, .month, .day], from: endDate)
            let timeDate = calendar.date(from: dateComponent) ?? endDate
            let newDate = calendar.date(bySettingHour: calendar.component(.hour, from: tempDate),
                                        minute: calendar.component(.minute, from: tempDate),
                                        second: calendar.component(.second, from: tempDate),
                                        of: timeDate) ?? timeDate
            endDate = newDate
            // 如果修改后 endDate <= startDate，自动修正 startDate
            if endDate <= startDate {
                startDate = calendar.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
            }
        }
    }

    private func localizedString(_ key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        return localized != key ? localized : key
    }
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
