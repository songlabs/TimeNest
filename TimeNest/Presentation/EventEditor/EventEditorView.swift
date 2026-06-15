import SwiftUI

// MARK: - Local Styles

/// EventEditorView 本地样式常量
/// 集中定义页面所需的背景色、文字色、布局参数等，避免依赖外部未定义类型
private enum EventEditorStyle {
    // MARK: - Background Colors

    /// 页面背景色 - 跟随系统深浅模式自动切换
    static var pageBackground: Color {
        Color(.systemGroupedBackground)
    }

    /// 卡片背景色 - 跟随系统深浅模式自动切换
    static var cardBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }

    // MARK: - Text Colors

    /// 主要文字颜色
    static var primaryText: Color {
        Color.primary
    }

    /// 次要文字颜色
    static var secondaryText: Color {
        Color.secondary
    }

    // MARK: - Field / Control Colors

    /// 输入框/按钮背景色
    static var fieldBackground: Color {
        Color(.tertiarySystemGroupedBackground)
    }

    /// 输入框/按钮文字颜色
    static var fieldText: Color {
        Color.primary
    }

    /// 输入框/按钮边框色
    static var buttonBorder: Color {
        Color(.separator).opacity(0.35)
    }

    // MARK: - Divider Colors

    /// 分隔线颜色
    static var dividerColor: Color {
        Color(.separator).opacity(0.45)
    }

    // MARK: - Destructive Color

    /// 删除/错误颜色
    static var destructive: Color {
        Color(.systemRed)
    }

    // MARK: - Layout Constants

    /// 统一卡片圆角
    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 22
    static let cardPadding: CGFloat = 16
    static let rowHeight: CGFloat = 48
    static let controlHeight: CGFloat = 36
    static let compactControlHeight: CGFloat = 30
    static let shiftActionButtonWidth: CGFloat = 88
    static let shiftActionButtonHeight: CGFloat = 32
    static let shiftActionButtonCornerRadius: CGFloat = 8
    static let shiftTemplateButtonSpacing: CGFloat = 12
    static let workColumnSpacing: CGFloat = 12
    static let workActionButtonFont = Font.subheadline.weight(.semibold)
    static let workInfoTimePillWidth: CGFloat = 92
    static let workInfoTimePillHeight: CGFloat = compactControlHeight
    static let workInfoTimePillCornerRadius: CGFloat = controlCornerRadius

    /// 统一卡片圆角
    static let cardCornerRadius: CGFloat = 26

    /// 统一控制组件圆角
    static let controlCornerRadius: CGFloat = 16

    /// 顶部按钮圆角
    static let headerButtonCornerRadius: CGFloat = 24
}

private enum EditorFocusedField: Hashable {
    case title
    case transportFee
    case hourlyRate
}


private struct WorkClockConfirmation: Identifiable {
    let kind: WorkClockKind

    var id: WorkClockKind { kind }

    var titleKey: LocalizedString {
        switch kind {
        case .clockIn:
            return .editorWorkInOverwriteTitle
        case .clockOut:
            return .editorWorkOutOverwriteTitle
        }
    }

    var messageKey: LocalizedString {
        switch kind {
        case .clockIn:
            return .editorWorkInOverwriteMessage
        case .clockOut:
            return .editorWorkOutOverwriteMessage
        }
    }
}

enum EventEditorMode {
    case create(initialDate: Date)
    case edit(
        eventID: UUID,
        initialTitle: String,
        initialNote: String?,
        initialStartDate: Date,
        initialEndDate: Date,
        initialIsAllDay: Bool,
        initialReminderOffsetMinutes: Int?,
        initialWorkInfo: WorkInfo? = nil,
        initialShiftTemplateID: ShiftTimeTemplateID? = nil
    )
}

struct EventEditorView: View {
    @Environment(\.localization) private var localization
    @Binding var isPresented: Bool
    let mode: EventEditorMode
    let existingEvents: [EventOccurrence]
    var onSave: (String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> Void

    @State private var title: String
    @State private var note: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var workInDate: Date
    @State private var workOutDate: Date
    @State private var workDate: Date
    @State private var isAllDay: Bool
    @State private var reminderOffsetMinutes: Int?
    @State private var selectedShiftTemplateID: ShiftTimeTemplateID?
    @State private var saving: Bool = false
    @State private var errorMessage: String?
    @State private var showingStartDatePicker: Bool = false
    @State private var showingStartTimePicker: Bool = false
    @State private var showingEndDatePicker: Bool = false
    @State private var showingEndTimePicker: Bool = false
    @State private var showingReminderPicker: Bool = false // 提醒时间选择器
    @State private var restTime: Double = 1.0 // 休息时间，单位：小时
    @State private var transportFee: String = "" // 交通费
    @State private var hourlyRate: String = "" // 时给
    @State private var showingRestTimePicker: Bool = false // 休息时间选择器
    @State private var pendingWorkClockConfirmation: WorkClockConfirmation?
    @State private var workSessionId: UUID
    @FocusState private var focusedField: EditorFocusedField?

    private let reminderOptions: [Int?] = [nil, 0, 5, 10, 15, 30, 60, 1440]

    init(
        isPresented: Binding<Bool>,
        mode: EventEditorMode,
        existingEvents: [EventOccurrence] = [],
        onSave: @escaping (String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> Void
    ) {
        _isPresented = isPresented
        self.mode = mode
        self.existingEvents = existingEvents
        self.onSave = onSave

        let initialState = EventEditorView.initialState(for: mode)
        _title = State(initialValue: initialState.title)
        _note = State(initialValue: initialState.note ?? "")
        _startDate = State(initialValue: initialState.startDate)
        _endDate = State(initialValue: initialState.endDate)
        let initialWorkDate = initialState.workInfo?.workDate ?? initialState.defaultWorkDate
        let initialWorkSessionId = initialState.workInfo?.workSessionId ?? WorkInfo.makeNewWorkSessionId()
        _workSessionId = State(initialValue: initialWorkSessionId)
        _workDate = State(initialValue: initialWorkDate)
        _workInDate = State(initialValue: initialState.workInfo?.workInTime ?? initialWorkDate)
        _workOutDate = State(initialValue: EventEditorView.initialWorkOutDate(
            title: initialState.title,
            workInfo: initialState.workInfo,
            defaultWorkDate: initialWorkDate,
            existingEvents: existingEvents
        ))
        _isAllDay = State(initialValue: initialState.isAllDay)
        _reminderOffsetMinutes = State(initialValue: initialState.reminderOffsetMinutes)
        let sharedValues = EventEditorView.sharedWorkValues(
            ownWorkInfo: initialState.workInfo,
            sessionId: initialWorkSessionId,
            targetDate: initialWorkDate,
            existingEvents: existingEvents,
            editingEventID: EventEditorView.editingEventID(for: mode)
        )
        _restTime = State(initialValue: sharedValues.restHours ?? 1.0)
        _transportFee = State(initialValue: sharedValues.transportFee.map(String.init) ?? "")
        _hourlyRate = State(initialValue: sharedValues.hourlyRate.map(String.init) ?? "")
        _selectedShiftTemplateID = State(initialValue: initialState.shiftTemplateID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EventEditorStyle.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    EditorHeader(
                        title: editorTitle,
                        cancelTitle: localization.localized(.editorCancel),
                        saveTitle: localization.localized(.editorSave),
                        canSave: canSave,
                        saving: saving,
                        onCancel: { isPresented = false },
                        onSave: {
                            Task {
                                await save()
                            }
                        }
                    )

                    ScrollView {
                        VStack(spacing: EventEditorStyle.sectionSpacing) {
                            TitleInputSection(
                                title: $title,
                                placeholder: localization.localized(.editorTitle),
                                focusedField: $focusedField
                            )

                            VStack(spacing: 0) {
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

                                CardDivider()

                                ReminderSection(
                                    reminderTitle: localization.localized(.editorReminder),
                                    reminderOffsetMinutes: $reminderOffsetMinutes,
                                    reminderOptions: reminderOptions,
                                    reminderTitleFormatter: { reminderTitle(for: $0) },
                                    showingReminderPicker: $showingReminderPicker
                                )
                            }
                            .cardContainer()

                            ShiftTemplateSection(templates: shiftTemplates, selectedTemplateID: $selectedShiftTemplateID) { template in
                                applyShiftTemplate(template)
                            }

                            WorkInfoSection(
                                restTime: $restTime,
                                transportFee: $transportFee,
                                hourlyRate: $hourlyRate,
                                showingRestTimePicker: $showingRestTimePicker,
                                workInDate: $workInDate,
                                workOutDate: $workOutDate,
                                eventTitle: $title,
                                focusedField: $focusedField,
                                workInTitle: localization.localized(.editorWorkIn),
                                workOutTitle: localization.localized(.editorWorkOut),
                                restTimeTitle: localization.localized(.editorRestTime),
                                transportFeeTitle: localization.localized(.editorTransportFee),
                                hourlyRateTitle: localization.localized(.editorHourlyRate),
                                currencyUnit: localization.localized(.editorCurrencyUnit),
                                onWorkInTap: { handleWorkClockTap(.clockIn) },
                                onWorkOutTap: { handleWorkClockTap(.clockOut) }
                            )
                            .sheet(isPresented: $showingRestTimePicker) {
                                RestTimePickerSheet(restTime: $restTime)
                            }

                            if let validationMessage = validationMessage ?? errorMessage {
                                Text(validationMessage)
                                    .font(.footnote)
                                    .foregroundColor(EventEditorStyle.destructive)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, EventEditorStyle.cardPadding)
                            }
                        }
                        .padding(.horizontal, EventEditorStyle.horizontalPadding)
                        .padding(.top, 18)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .disabled(saving)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(localization.localized(.done)) {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                applySharedWorkValuesForNewEventIfNeeded(date: startDate, resetWhenMissing: false)
            }
            .onChange(of: startDate) { oldValue, newValue in
                handleStartDateChange(from: oldValue, to: newValue)
            }
            .alert(item: $pendingWorkClockConfirmation) { confirmation in
                Alert(
                    title: Text(localization.localized(confirmation.titleKey)),
                    message: Text(localization.localized(confirmation.messageKey)),
                    primaryButton: .default(Text(localization.localized(.editorWorkOverwriteButton))) {
                        applyWorkClockSelection(confirmation.kind)
                    },
                    secondaryButton: .cancel(Text(localization.localized(.editorWorkOverwriteCancelButton)))
                )
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

    private static func initialState(for mode: EventEditorMode) -> (title: String, note: String?, startDate: Date, endDate: Date, isAllDay: Bool, reminderOffsetMinutes: Int?, workInfo: WorkInfo?, shiftTemplateID: ShiftTimeTemplateID?, defaultWorkDate: Date) {
        switch mode {
        case .create(let initialDate):
            let defaultStartDate = makeDefaultEventStartDate(selectedDate: initialDate)
            return (
                title: "",
                note: nil,
                startDate: defaultStartDate,
                endDate: makeDefaultEventEndDate(startDate: defaultStartDate),
                isAllDay: false,
                reminderOffsetMinutes: nil,
                workInfo: nil,
                shiftTemplateID: nil,
                defaultWorkDate: defaultStartDate
            )
        case .edit(_, let initialTitle, let initialNote, let initialStartDate, let initialEndDate, let initialIsAllDay, let initialReminderOffsetMinutes, let initialWorkInfo, let initialShiftTemplateID):
            return (
                title: initialTitle,
                note: initialNote,
                startDate: initialStartDate,
                endDate: initialEndDate,
                isAllDay: initialIsAllDay,
                reminderOffsetMinutes: initialReminderOffsetMinutes,
                workInfo: initialWorkInfo,
                shiftTemplateID: initialShiftTemplateID,
                defaultWorkDate: makeDefaultEventStartDate(selectedDate: initialStartDate)
            )
        }
    }


    private func handleWorkClockTap(_ kind: WorkClockKind) {
        focusedField = nil

        if hasExistingWorkClockEvent(kind) {
            pendingWorkClockConfirmation = WorkClockConfirmation(kind: kind)
        } else {
            applyWorkClockSelection(kind)
        }
    }

    private func applyWorkClockSelection(_ kind: WorkClockKind) {
        applySharedWorkValuesForNewEventIfNeeded(date: startDate, resetWhenMissing: false, preserveExistingValues: true)

        switch kind {
        case .clockIn:
            title = localization.localized(.editorWorkIn)
        case .clockOut:
            title = localization.localized(.editorWorkOut)
        }
        focusedField = nil
    }

    private func hasExistingWorkClockEvent(_ kind: WorkClockKind) -> Bool {
        existingEvents.contains { event in
            guard event.eventID != editingEventID else { return false }
            return event.workInfo?.workSessionId == workSessionId && event.matchesWorkClockKind(kind)
        }
    }

    private var editingEventID: UUID? {
        EventEditorView.editingEventID(for: mode)
    }

    private static func editingEventID(for mode: EventEditorMode) -> UUID? {
        if case .edit(let eventID, _, _, _, _, _, _, _, _) = mode {
            return eventID
        }
        return nil
    }

    private func handleStartDateChange(from oldValue: Date, to newValue: Date) {
        guard !isEditing else { return }

        let calendar = Calendar.current
        let newWorkDate = calendar.startOfDay(for: newValue)
        workDate = newWorkDate
        workInDate = EventEditorView.date(on: newWorkDate, matchingTimeOf: workInDate)
        workOutDate = EventEditorView.date(on: newWorkDate, matchingTimeOf: workOutDate)

        guard !calendar.isDate(oldValue, inSameDayAs: newValue) else { return }
        applySharedWorkValuesForNewEventIfNeeded(date: newValue, resetWhenMissing: true)
    }

    private static func sharedWorkValues(ownWorkInfo: WorkInfo?, sessionId: UUID, targetDate: Date, existingEvents: [EventOccurrence], editingEventID: UUID?) -> (restHours: Double?, transportFee: Int?, hourlyRate: Int?) {
        let calendar = Calendar.current
        let sameSessionWorkEvents = existingEvents.filter { event in
            event.eventID != editingEventID
            && event.isWorkClockEvent
            && event.workInfo?.workSessionId == sessionId
        }
        let sameDayWorkEvents = existingEvents.filter { event in
            event.eventID != editingEventID
            && event.isWorkClockEvent
            && calendar.isDate(event.workDate, inSameDayAs: targetDate)
        }
        let sourceEvents = sameSessionWorkEvents.isEmpty ? sameDayWorkEvents : sameSessionWorkEvents

        return (
            restHours: ownWorkInfo?.restHours ?? sourceEvents.compactMap { $0.workInfo?.restHours }.first,
            transportFee: ownWorkInfo?.transportFee ?? sourceEvents.compactMap { $0.workInfo?.transportFee }.first,
            hourlyRate: ownWorkInfo?.hourlyRate ?? sourceEvents.compactMap { $0.workInfo?.hourlyRate }.first
        )
    }

    private func applySharedWorkValuesForNewEventIfNeeded(date: Date, resetWhenMissing: Bool, preserveExistingValues: Bool = false) {
        guard !isEditing else { return }

        let sharedValues = EventEditorView.sharedWorkValues(
            ownWorkInfo: nil,
            sessionId: workSessionId,
            targetDate: date,
            existingEvents: existingEvents,
            editingEventID: nil
        )

        if !preserveExistingValues, let restHours = sharedValues.restHours {
            restTime = restHours
        } else if !preserveExistingValues, resetWhenMissing {
            restTime = 1.0
        }

        if let transportFee = sharedValues.transportFee, (!preserveExistingValues || self.transportFee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            self.transportFee = String(transportFee)
        } else if !preserveExistingValues, resetWhenMissing {
            self.transportFee = ""
        }

        if let hourlyRate = sharedValues.hourlyRate, (!preserveExistingValues || self.hourlyRate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            self.hourlyRate = String(hourlyRate)
        } else if !preserveExistingValues, resetWhenMissing {
            self.hourlyRate = ""
        }
    }

    private static func date(on day: Date, matchingTimeOf sourceDate: Date) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: sourceDate)
        return calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: timeComponents.second ?? 0,
            of: day
        ) ?? sourceDate
    }

    private static func initialWorkOutDate(title: String, workInfo: WorkInfo?, defaultWorkDate: Date, existingEvents: [EventOccurrence]) -> Date {
        let workOut = workInfo?.workOutTime ?? defaultWorkDate
        guard WorkClockTitleMatcher.isClockOutTitle(title) else { return workOut }

        let calendar = Calendar.current
        let workDay = calendar.startOfDay(for: workInfo?.workDate ?? defaultWorkDate)
        guard calendar.isDate(workOut, inSameDayAs: workDay),
              let clockIn = existingEvents
                .filter({ $0.isClockInEvent && ($0.workInfo?.workSessionId == workInfo?.workSessionId || ($0.workInfo?.workSessionId == nil && calendar.isDate($0.workDate, inSameDayAs: workDay))) })
                .map({ $0.workInfo?.workInTime ?? $0.startDate })
                .min()
        else {
            return workOut
        }

        let outMinutes = minutesSinceStartOfDay(workOut, calendar: calendar)
        let inMinutes = minutesSinceStartOfDay(clockIn, calendar: calendar)
        if outMinutes < inMinutes {
            return calendar.date(byAdding: .day, value: 1, to: workOut) ?? workOut
        }
        return workOut
    }

    private static func minutesSinceStartOfDay(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func save() async {
        guard canSave else { return }
        saving = true
        errorMessage = nil

        do {
            let saveContext = normalizedSaveContext()
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            try await onSave(title, trimmedNote.isEmpty ? nil : trimmedNote, saveContext.dates.start, saveContext.dates.end, isAllDay, reminderOffsetMinutes, selectedShiftTemplateID, saveContext.workInfo)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }

        saving = false
    }

    private func normalizedSaveContext() -> (dates: (start: Date, end: Date), workInfo: WorkInfo) {
        if WorkClockTitleMatcher.isClockOutTitle(title) {
            let matchedClockIn = matchingClockInForClockOut()
            let normalizedWorkDate = matchedClockIn.map { Calendar.current.startOfDay(for: $0.workDate) } ?? workDate
            let normalizedSessionId = matchedClockIn?.workInfo?.workSessionId ?? workSessionId
            let normalizedWorkOutDate = normalizedClockOutDate(
                selectedClockOutDate: workOutDate,
                clockInDate: matchedClockIn?.actualWorkClockDate,
                workDay: normalizedWorkDate
            )
            let info = currentWorkInfo(
                workInTime: workInDate,
                workOutTime: normalizedWorkOutDate,
                workDate: normalizedWorkDate,
                workSessionId: normalizedSessionId
            )
            return (workClockSaveDates(for: normalizedWorkOutDate), info)
        }

        if WorkClockTitleMatcher.isClockInTitle(title) {
            let info = currentWorkInfo(
                workInTime: workInDate,
                workOutTime: workOutDate,
                workDate: workDate,
                workSessionId: workSessionId
            )
            return (workClockSaveDates(for: workInDate), info)
        }

        return (normalizedDates(), currentWorkInfo(
            workInTime: workInDate,
            workOutTime: workOutDate,
            workDate: workDate,
            workSessionId: workSessionId
        ))
    }

    private func currentWorkInfo(workInTime: Date?, workOutTime: Date?, workDate: Date?, workSessionId: UUID?) -> WorkInfo {
        WorkInfo(
            workInTime: workInTime,
            workOutTime: workOutTime,
            restHours: restTime,
            workDate: workDate,
            transportFee: Int(transportFee.trimmingCharacters(in: .whitespacesAndNewlines)),
            hourlyRate: Int(hourlyRate.trimmingCharacters(in: .whitespacesAndNewlines)),
            workSessionId: workSessionId
        )
    }

    private func matchingClockInForClockOut() -> EventOccurrence? {
        let calendar = Calendar.current
        let targetWorkDay = calendar.startOfDay(for: workDate)
        let clockIns = existingEvents
            .filter { event in
                guard event.eventID != editingEventID, event.isClockInEvent else { return false }
                return calendar.isDate(event.workDate, inSameDayAs: targetWorkDay)
            }
            .sorted { $0.actualWorkClockDate > $1.actualWorkClockDate }

        if let sameSessionClockIn = clockIns.first(where: { $0.workInfo?.workSessionId == workSessionId }) {
            return sameSessionClockIn
        }

        let usedClockInSessionIDs = Set(existingEvents.compactMap { event -> UUID? in
            guard event.eventID != editingEventID, event.isClockOutEvent else { return nil }
            return event.workInfo?.workSessionId
        })

        return clockIns.first { event in
            guard let sessionId = event.workInfo?.workSessionId else { return true }
            return !usedClockInSessionIDs.contains(sessionId)
        } ?? clockIns.first
    }

    private func normalizedClockOutDate(selectedClockOutDate: Date, clockInDate: Date?, workDay: Date) -> Date {
        let calendar = Calendar.current
        var normalized = EventEditorView.date(on: workDay, matchingTimeOf: selectedClockOutDate)
        guard let clockInDate else {
            if calendar.startOfDay(for: selectedClockOutDate) > calendar.startOfDay(for: workDay) {
                return EventEditorView.date(on: selectedClockOutDate, matchingTimeOf: selectedClockOutDate)
            }
            return normalized
        }
        if normalized <= clockInDate {
            normalized = calendar.date(byAdding: .day, value: 1, to: normalized) ?? normalized
        }
        return normalized
    }

    private func normalizedDates() -> (start: Date, end: Date) {
        EventEditorDateNormalizer.normalizedDates(startDate: startDate, endDate: endDate, isAllDay: isAllDay)
    }

    private func workClockSaveDates(for clockDate: Date) -> (start: Date, end: Date) {
        let end = CalendarEvent.defaultEndDate(for: clockDate, isAllDay: false)
        return (clockDate, end)
    }

    private static func makeDefaultEventStartDate(selectedDate: Date, now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)

        var components = DateComponents()
        components.calendar = calendar
        components.year = selectedComponents.year
        components.month = selectedComponents.month
        components.day = selectedComponents.day
        components.hour = nowComponents.hour
        components.minute = nowComponents.minute
        components.second = 0

        return calendar.date(from: components) ?? now
    }

    private static func makeDefaultEventEndDate(startDate: Date) -> Date {
        CalendarEvent.defaultEndDate(for: startDate, isAllDay: false)
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
        let normalized = EventEditorDateNormalizer.normalizedForAllDayChange(
            allDay: allDay,
            startDate: startDate,
            endDate: endDate
        )
        startDate = normalized.startDate
        endDate = normalized.endDate
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


// MARK: - Shared Editor Components

private struct EditorHeader: View {
    let title: String
    let cancelTitle: String
    let saveTitle: String
    let canSave: Bool
    let saving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundColor(EventEditorStyle.primaryText)
                .lineLimit(1)

            HStack {
                Button(cancelTitle, action: onCancel)
                    .buttonStyle(HeaderCapsuleButtonStyle(isEnabled: !saving))
                    .disabled(saving)

                Spacer()

                Button(saveTitle, action: onSave)
                    .buttonStyle(HeaderCapsuleButtonStyle(isEnabled: canSave && !saving))
                    .disabled(!canSave || saving)
            }
        }
        .padding(.horizontal, EventEditorStyle.horizontalPadding)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .background(EventEditorStyle.pageBackground)
    }
}

private struct HeaderCapsuleButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(isEnabled ? EventEditorStyle.primaryText : EventEditorStyle.secondaryText.opacity(0.55))
            .padding(.horizontal, 18)
            .frame(height: EventEditorStyle.rowHeight)
            .background(EventEditorStyle.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.headerButtonCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EventEditorStyle.headerButtonCornerRadius, style: .continuous)
                    .stroke(EventEditorStyle.buttonBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(EventEditorStyle.dividerColor)
            .frame(height: 1 / UIScreen.main.scale)
            .padding(.leading, EventEditorStyle.cardPadding)
    }
}

private extension View {
    func cardContainer() -> some View {
        self
            .background(EventEditorStyle.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.cardCornerRadius, style: .continuous))
    }
}

// MARK: - Reminder Section

/// 提醒设置组件（与时间设置卡片样式保持一致）
private struct ReminderSection: View {
    let reminderTitle: String
    @Binding var reminderOffsetMinutes: Int?
    let reminderOptions: [Int?]
    let reminderTitleFormatter: (Int?) -> String
    @Binding var showingReminderPicker: Bool

    var body: some View {
        Button {
            showingReminderPicker = true
        } label: {
            HStack {
                Text(reminderTitle)
                    .font(.subheadline)
                    .foregroundColor(EventEditorStyle.secondaryText)
                    .frame(minWidth: 40, alignment: .leading)

                Spacer()

                HStack {
                    Text(reminderTitleFormatter(reminderOffsetMinutes))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(EventEditorStyle.primaryText)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(EventEditorStyle.secondaryText)
                        .padding(.leading, 4)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: EventEditorStyle.rowHeight)
            .padding(.horizontal, EventEditorStyle.cardPadding)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingReminderPicker) {
            ReminderPickerSheet(
                reminderOffsetMinutes: $reminderOffsetMinutes,
                reminderOptions: reminderOptions,
                reminderTitleFormatter: reminderTitleFormatter,
                showingReminderPicker: $showingReminderPicker
            )
        }
    }
}

/// 提醒时间选择器弹窗
private struct ReminderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var reminderOffsetMinutes: Int?
    let reminderOptions: [Int?]
    let reminderTitleFormatter: (Int?) -> String
    @Binding var showingReminderPicker: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(reminderOptions.indices, id: \.self) { index in
                        let option = reminderOptions[index]
                        Button {
                            reminderOffsetMinutes = option
                            showingReminderPicker = false
                            dismiss()
                        } label: {
                            HStack {
                                Text(reminderTitleFormatter(option))
                                    .foregroundColor(.primary)
                                Spacer()
                                if reminderOffsetMinutes == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(localizedString("提醒"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("取消")) {
                        showingReminderPicker = false
                        dismiss()
                    }
                }
            }
        }
    }

    private func localizedString(_ key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        return localized != key ? localized : key
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
                    .foregroundColor(EventEditorStyle.primaryText)
                Spacer()
                Toggle("", isOn: $isAllDay)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(EventEditorStyle.primaryText)
            }

            // 第二行：開始 + 日期/时间按钮
            HStack(alignment: .center, spacing: 8) {
                Text("開始")
                    .font(.subheadline)
                    .foregroundColor(EventEditorStyle.secondaryText)
                    .frame(minWidth: 40, alignment: .leading)

                HStack(spacing: 8) {
                    // 日期按钮
                    Button {
                        showingStartDatePicker = true
                    } label: {
                        Text(formatDateOnly(startDate))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(EventEditorStyle.fieldText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(EventEditorStyle.fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.controlCornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: EventEditorStyle.controlCornerRadius, style: .continuous)
                                    .stroke(EventEditorStyle.buttonBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    // 时间按钮
                    Button {
                        showingStartTimePicker = true
                    } label: {
                        Text(formatTimeOnly(startDate))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(EventEditorStyle.fieldText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(EventEditorStyle.fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.controlCornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: EventEditorStyle.controlCornerRadius, style: .continuous)
                                    .stroke(EventEditorStyle.buttonBorder, lineWidth: 1)
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
                    .foregroundColor(EventEditorStyle.secondaryText)
                    .frame(minWidth: 40, alignment: .leading)

                HStack(spacing: 8) {
                    // 日期按钮
                    Button {
                        showingEndDatePicker = true
                    } label: {
                        Text(formatDateOnly(endDate))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(EventEditorStyle.fieldText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(EventEditorStyle.fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.controlCornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: EventEditorStyle.controlCornerRadius, style: .continuous)
                                    .stroke(EventEditorStyle.buttonBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    // 时间按钮
                    Button {
                        showingEndTimePicker = true
                    } label: {
                        Text(formatTimeOnly(endDate))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(EventEditorStyle.fieldText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(EventEditorStyle.fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.controlCornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: EventEditorStyle.controlCornerRadius, style: .continuous)
                                    .stroke(EventEditorStyle.buttonBorder, lineWidth: 1)
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
        .padding(EventEditorStyle.cardPadding)
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

// MARK: - Title Input Section

/// 标题输入组件
private struct TitleInputSection: View {
    @Binding var title: String
    let placeholder: String
    var focusedField: FocusState<EditorFocusedField?>.Binding

    var body: some View {
        TextField(placeholder, text: $title)
            .focused(focusedField, equals: .title)
            .textFieldStyle(.plain)
            .padding(.horizontal, EventEditorStyle.cardPadding)
            .frame(height: EventEditorStyle.rowHeight + 12)
            .background(EventEditorStyle.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.cardCornerRadius, style: .continuous))
            .tint(EventEditorStyle.primaryText)
    }
}

// MARK: - Shift Template Section

/// 班次模板选择组件
private struct ShiftTemplateSection: View {
    let templates: [ShiftTimeTemplate]
    @Binding var selectedTemplateID: ShiftTimeTemplateID?
    let onSelect: (ShiftTimeTemplate) -> Void

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: EventEditorStyle.shiftActionButtonWidth,
                        maximum: EventEditorStyle.shiftActionButtonWidth
                    ),
                    spacing: EventEditorStyle.shiftTemplateButtonSpacing,
                    alignment: .leading
                )
            ],
            alignment: .leading,
            spacing: EventEditorStyle.shiftTemplateButtonSpacing
        ) {
            ForEach(templates) { template in
                Button {
                    onSelect(template)
                } label: {
                    Text(template.displayName)
                }
                .buttonStyle(ShiftTemplateButtonStyle(backgroundColor: template.color.opacity(0.24)))
            }
        }
        .padding(EventEditorStyle.cardPadding)
        .cardContainer()
    }
}

// MARK: - Work Info Time Picker Sheet

private struct WorkInfoTimePickerSheet<PickerContent: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onCancel: () -> Void
    let onDone: () -> Void
    @ViewBuilder let pickerContent: () -> PickerContent

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        pickerContent()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedString("完了")) {
                        onDone()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("取消")) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }

    private func localizedString(_ key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        return localized != key ? localized : key
    }
}

/// 休息时间选择器（Sheet）
private struct RestTimePickerSheet: View {
    @Binding var restTime: Double // 休息时间（小时）

    var body: some View {
        WorkInfoTimePickerSheet(
            title: localizedString("选择休息时间"),
            onCancel: {},
            onDone: {}
        ) {
            DatePicker(
                "",
                selection: Binding(
                    get: { restTimeToDuration(restTime) },
                    set: { restTime = durationToRestTime($0) }
                ),
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
        }
    }

    private func restTimeToDuration(_ hours: Double) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let baseDate = calendar.startOfDay(for: Date())
        let hour = Int(hours)
        let minute = Int((hours - Double(hour)) * 60)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) ?? baseDate
    }

    private func durationToRestTime(_ date: Date) -> Double {
        let calendar = Calendar(identifier: .gregorian)
        let hour = Double(calendar.component(.hour, from: date))
        let minute = Double(calendar.component(.minute, from: date))
        return hour + minute / 60.0
    }

    private func localizedString(_ key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        return localized != key ? localized : key
    }
}

// MARK: - Work Info Section

private enum WorkTimeEditTarget: Hashable, Identifiable {
    case workIn
    case workOut

    var id: Self { self }

    func pickerTitle(workInTitle: String, workOutTitle: String) -> String {
        switch self {
        case .workIn:
            return localizedString("选择") + workInTitle + localizedString("editor.time")
        case .workOut:
            return localizedString("选择") + workOutTitle + localizedString("editor.time")
        }
    }

    private func localizedString(_ key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        return localized != key ? localized : key
    }
}

/// 打工时间和收入信息输入组件
private struct WorkInfoSection: View {
    @Binding var restTime: Double
    @Binding var transportFee: String
    @Binding var hourlyRate: String
    @Binding var showingRestTimePicker: Bool
    @Binding var workInDate: Date
    @Binding var workOutDate: Date
    @Binding var eventTitle: String
    var focusedField: FocusState<EditorFocusedField?>.Binding

    let workInTitle: String
    let workOutTitle: String
    let restTimeTitle: String
    let transportFeeTitle: String
    let hourlyRateTitle: String
    let currencyUnit: String
    let onWorkInTap: () -> Void
    let onWorkOutTap: () -> Void

    @State private var editingWorkTime: WorkTimeEditTarget?

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: EventEditorStyle.workColumnSpacing) {
                workColumn(title: workInTitle) {
                    onWorkInTap()
                } content: {
                    Button {
                        editingWorkTime = .workIn
                    } label: {
                        workInfoTimeValuePillLabel(formatWorkTime(workInDate))
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: EventEditorStyle.workInfoTimePillCornerRadius, style: .continuous))
                }

                workColumn(title: restTimeTitle) {
                    Button {
                        showingRestTimePicker = true
                    } label: {
                        workInfoTimeValuePillLabel(formatRestTime(restTime))
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: EventEditorStyle.workInfoTimePillCornerRadius, style: .continuous))
                }

                workColumn(title: workOutTitle) {
                    onWorkOutTap()
                } content: {
                    Button {
                        editingWorkTime = .workOut
                    } label: {
                        workInfoTimeValuePillLabel(formatWorkTime(workOutDate))
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: EventEditorStyle.workInfoTimePillCornerRadius, style: .continuous))
                }
            }

            CardDivider()

            HStack(spacing: EventEditorStyle.workColumnSpacing) {
                currencyField(title: transportFeeTitle, value: $transportFee, field: .transportFee)
                currencyField(title: hourlyRateTitle, value: $hourlyRate, field: .hourlyRate)
            }
        }
        .padding(EventEditorStyle.cardPadding)
        .cardContainer()
        .sheet(item: $editingWorkTime) { target in
            WorkInfoTimePickerSheet(
                title: target.pickerTitle(workInTitle: workInTitle, workOutTitle: workOutTitle),
                onCancel: { editingWorkTime = nil },
                onDone: { editingWorkTime = nil }
            ) {
                DatePicker(
                    "",
                    selection: workTimeBinding(for: target),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
        }
    }

    private func workColumn<Content: View>(title: String, action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Text(title)
                    .font(EventEditorStyle.workActionButtonFont)
            }
            .buttonStyle(ShiftToggleActiveButtonStyle(width: EventEditorStyle.shiftActionButtonWidth, height: EventEditorStyle.shiftActionButtonHeight, cornerRadius: EventEditorStyle.shiftActionButtonCornerRadius, font: EventEditorStyle.workActionButtonFont))
            content()
        }
        .frame(maxWidth: .infinity)
    }

    private func workColumn<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(EventEditorStyle.primaryText)
                .frame(width: EventEditorStyle.shiftActionButtonWidth, height: EventEditorStyle.shiftActionButtonHeight)

            content()
        }
        .frame(maxWidth: .infinity)
    }

    private func workInfoTimeValuePillLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundColor(EventEditorStyle.fieldText)
            .frame(width: EventEditorStyle.workInfoTimePillWidth,
                   height: EventEditorStyle.workInfoTimePillHeight)
            .background(EventEditorStyle.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.workInfoTimePillCornerRadius, style: .continuous))
    }

    private func workTimeBinding(for target: WorkTimeEditTarget) -> Binding<Date> {
        switch target {
        case .workIn:
            return $workInDate
        case .workOut:
            return $workOutDate
        }
    }

    private func formatWorkTime(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func localizedString(_ key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        return localized != key ? localized : key
    }

}

private struct ShiftTemplateButtonStyle: ButtonStyle {
    let backgroundColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EventEditorStyle.workActionButtonFont)
            .foregroundColor(EventEditorStyle.primaryText)
            .frame(width: EventEditorStyle.shiftActionButtonWidth, height: EventEditorStyle.shiftActionButtonHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.shiftActionButtonCornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private extension WorkInfoSection {
    private func currencyField(title: String, value: Binding<String>, field: EditorFocusedField) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(EventEditorStyle.secondaryText)

            TextField("", text: value)
                .focused(focusedField, equals: field)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity)
                .frame(height: EventEditorStyle.controlHeight)
                .padding(.horizontal, 10)
                .background(EventEditorStyle.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.controlCornerRadius, style: .continuous))

            Text(currencyUnit)
                .font(.subheadline)
                .foregroundColor(EventEditorStyle.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatRestTime(_ hours: Double) -> String {
        let hour = Int(hours)
        let minute = Int((hours - Double(hour)) * 60)
        return String(format: "%d:%02d", hour, minute)
    }
}
