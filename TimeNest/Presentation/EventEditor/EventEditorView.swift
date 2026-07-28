import SwiftUI
import UIKit

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
    static let sectionSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let contentTopPadding: CGFloat = 12
    static let contentBottomPadding: CGFloat = 12
    static let headerBottomPadding: CGFloat = 12
    static let workInfoVerticalPadding: CGFloat = 12
    static let rowHeight: CGFloat = 48
    static let controlHeight: CGFloat = 36
    static let compactControlHeight: CGFloat = 30
    static let shiftActionButtonWidth: CGFloat = 88
    static let shiftActionButtonHeight: CGFloat = 32
    static let shiftActionButtonCornerRadius: CGFloat = 8
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
    case note
    case transportFee
    case hourlyRate
}

enum EntryEditorKind: Hashable {
    case event
    case workRecord
}

enum EntryCalendarContext: Equatable {
    case fixedWritableCalendar(UUID)
    case needsCalendarSelection(initialCalendarID: UUID)
    case readOnlyCalendar(UUID)

    var showsCalendarSelector: Bool {
        if case .needsCalendarSelection = self {
            return true
        }
        return false
    }

    var allowsEditing: Bool {
        if case .readOnlyCalendar = self {
            return false
        }
        return true
    }

    func initialCalendarID(in calendars: [TimeNestCalendar]) -> UUID {
        switch self {
        case .fixedWritableCalendar(let calendarID), .readOnlyCalendar(let calendarID):
            return calendarID
        case .needsCalendarSelection(let preferredCalendarID):
            let writableCalendars = calendars.filter(\.canEditContent)
            if writableCalendars.contains(where: { $0.id == preferredCalendarID }) {
                return preferredCalendarID
            }
            if writableCalendars.contains(where: { $0.id == TimeNestCalendar.personalID }) {
                return TimeNestCalendar.personalID
            }
            return writableCalendars.first?.id ?? TimeNestCalendar.personalID
        }
    }

    func resolvedCalendarID(selectedCalendarID: UUID) -> UUID {
        switch self {
        case .fixedWritableCalendar(let calendarID), .readOnlyCalendar(let calendarID):
            return calendarID
        case .needsCalendarSelection:
            return selectedCalendarID
        }
    }
}


private enum NotificationSaveAlert: Identifiable {
    case denied
    case triggerDateInPast
    case failed

    init?(result: EventNotificationScheduleResult) {
        switch result {
        case .denied:
            self = .denied
        case .triggerDateInPast:
            self = .triggerDateInPast
        case .failed, .failedWithCause:
            self = .failed
        case .scheduled, .noReminder:
            return nil
        }
    }

    var id: String {
        switch self {
        case .denied:
            return "denied"
        case .triggerDateInPast:
            return "triggerDateInPast"
        case .failed:
            return "failed"
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

typealias EventEditorSaveAction = (
    String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo?, UUID
) async throws -> EventNotificationScheduleResult

typealias EventEditorUpdateAction = (
    UUID, String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo?, UUID
) async throws -> EventNotificationScheduleResult

typealias WorkRecordPairSaveAction = (
    WorkRecordPairSaveRequest
) async throws -> Void

struct EventEditorView: View {
    @Environment(\.localization) private var localization
    @Environment(\.openURL) private var openURL
    @Binding var isPresented: Bool
    let mode: EventEditorMode
    let existingEvents: [EventOccurrence]
    var onSave: EventEditorSaveAction
    private let onSaveWorkRecordPair: WorkRecordPairSaveAction?
    private let showsEntryKindPicker: Bool
    private let availableCalendars: [TimeNestCalendar]
    private let calendarContext: EntryCalendarContext

    @State private var selectedEntryKind: EntryEditorKind
    @State private var selectedCalendarID: UUID
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
    @State private var editingWorkTime: WorkTimeEditTarget?
    @State private var pendingNotificationSaveAlert: NotificationSaveAlert?
    @State private var workSessionId: UUID
    @StateObject private var speechMemoRecognitionService = SpeechMemoRecognitionService()
    @State private var speechMemoRecognitionStatus: SpeechMemoRecognitionStatus = .idle
    @State private var speechMemoMessage: String?
    @State private var speechMemoBaseText: String = ""
    @FocusState private var focusedField: EditorFocusedField?

    @State private var workRecordTitle: String
    @State private var workRecordDate: Date
    @State private var workRecordInDate: Date
    @State private var workRecordOutDate: Date
    @State private var workRecordRestTime: Double
    @State private var workRecordTransportFee: String
    @State private var workRecordHourlyRate: String
    @State private var workRecordSessionId: UUID
    @State private var isWorkRecordOutTimeSet: Bool
    @State private var showingWorkRecordDatePicker: Bool = false
    @State private var showingWorkRecordRestTimePicker: Bool = false
    @State private var editingWorkRecordTime: WorkTimeEditTarget?

    private let reminderOptions: [Int?] = [nil, 0, 5, 10, 15, 30, 60, 1440]

    init(
        isPresented: Binding<Bool>,
        mode: EventEditorMode,
        existingEvents: [EventOccurrence] = [],
        initialEntryKind: EntryEditorKind = .event,
        showsEntryKindPicker: Bool = false,
        availableCalendars: [TimeNestCalendar] = [],
        calendarContext: EntryCalendarContext = .fixedWritableCalendar(TimeNestCalendar.personalID),
        onSaveWorkRecordPair: WorkRecordPairSaveAction? = nil,
        onSave: @escaping EventEditorSaveAction
    ) {
        _isPresented = isPresented
        self.mode = mode
        self.existingEvents = existingEvents
        self.onSave = onSave
        self.onSaveWorkRecordPair = onSaveWorkRecordPair
        self.availableCalendars = availableCalendars.filter(\.canEditContent)
        self.calendarContext = calendarContext
        _selectedCalendarID = State(
            initialValue: calendarContext.initialCalendarID(in: availableCalendars)
        )
        let isCreateMode: Bool
        switch mode {
        case .create:
            isCreateMode = true
        case .edit:
            isCreateMode = false
        }
        self.showsEntryKindPicker = showsEntryKindPicker && isCreateMode

        let initialState = EventEditorView.initialState(for: mode)
        _selectedEntryKind = State(initialValue: isCreateMode ? initialEntryKind : .event)
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

        let workRecordInitialValues = WorkRecordEditorView.initialValues(for: .create(initialDate: initialState.defaultWorkDate))
        _workRecordTitle = State(initialValue: workRecordInitialValues.title)
        _workRecordDate = State(initialValue: workRecordInitialValues.workDate)
        _workRecordInDate = State(initialValue: workRecordInitialValues.workInTime)
        _workRecordOutDate = State(initialValue: workRecordInitialValues.workOutTime)
        _workRecordRestTime = State(initialValue: workRecordInitialValues.restHours)
        _workRecordTransportFee = State(initialValue: workRecordInitialValues.transportFee.map(String.init) ?? "")
        _workRecordHourlyRate = State(initialValue: workRecordInitialValues.hourlyRate.map(String.init) ?? "")
        _workRecordSessionId = State(initialValue: workRecordInitialValues.workSessionId)
        _isWorkRecordOutTimeSet = State(initialValue: workRecordInitialValues.isWorkOutTimeSet)
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
                                await saveSelectedEntry()
                            }
                        }
                    )

                    ScrollView {
                        VStack(spacing: EventEditorStyle.sectionSpacing) {
                            if calendarContext.showsCalendarSelector && !availableCalendars.isEmpty {
                                CalendarAssignmentEditorSection(
                                    calendars: availableCalendars,
                                    selectedCalendarID: $selectedCalendarID
                                )
                            }
                            if showsEntryKindPicker {
                                entryKindPicker
                            }

                            editorFormContent
                        }
                        .padding(.horizontal, EventEditorStyle.horizontalPadding)
                        .padding(.top, EventEditorStyle.contentTopPadding)
                        .padding(.bottom, EventEditorStyle.contentBottomPadding)
                    }
                    .scrollIndicators(.hidden)
                }

                floatingPickerOverlay
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
            .onDisappear {
                stopSpeechMemoRecognition()
            }
            .onChange(of: startDate) { oldValue, newValue in
                handleStartDateChange(from: oldValue, to: newValue)
            }
            .onChange(of: selectedEntryKind) { _, _ in
                focusedField = nil
                dismissAllFloatingPickers()
                errorMessage = nil
            }
            .onChange(of: isFloatingPickerPresented) { _, isPresented in
                if isPresented {
                    focusedField = nil
                }
            }
            .alert(item: $pendingNotificationSaveAlert) { alert in
                notificationSaveAlert(for: alert)
            }
        }
        .presentationDetents([.fraction(0.6), .large])
        .accessibilityIdentifier("entry.editor")
    }

    private var entryKindPicker: some View {
        Picker("", selection: $selectedEntryKind) {
            Text(localization.localized(.entryKindEvent))
                .tag(EntryEditorKind.event)
                .accessibilityIdentifier("entry.kind.event")
            Text(localization.localized(.entryKindWorkRecord))
                .tag(EntryEditorKind.workRecord)
                .accessibilityIdentifier("entry.kind.workRecord")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("entry.kind")
    }

    @ViewBuilder
    private var editorFormContent: some View {
        if showsEntryKindPicker && selectedEntryKind == .workRecord {
            workRecordFormContent
        } else {
            eventFormContent
        }
    }

    private var eventFormContent: some View {
        VStack(spacing: EventEditorStyle.sectionSpacing) {
            TitleInputSection(
                title: $title,
                placeholder: localization.localized(.editorTitle),
                focusedField: $focusedField
            )

            EventTimeSection(
                startDate: $startDate,
                endDate: $endDate,
                isAllDay: $isAllDay,
                reminderOffsetMinutes: $reminderOffsetMinutes,
                allDayTitle: localization.localized(.editorAllDay),
                reminderTitle: localization.localized(.editorReminder),
                startTitle: localization.localized(.editorStart),
                endTitle: localization.localized(.editorEnd),
                reminderOptions: reminderOptions,
                reminderTitleFormatter: { reminderTitle(for: $0) },
                showingReminderPicker: $showingReminderPicker,
                showingStartDatePicker: $showingStartDatePicker,
                showingStartTimePicker: $showingStartTimePicker,
                showingEndDatePicker: $showingEndDatePicker,
                showingEndTimePicker: $showingEndTimePicker
            )
            .onChange(of: isAllDay) { _, newValue in
                normalizeForAllDayChange(newValue)
            }
            .cardContainer()

            MemoInputSection(
                title: localization.localized(.eventMemoTitle),
                text: $note,
                placeholder: localization.localized(.eventMemoVoicePlaceholder),
                statusMessage: speechMemoStatusMessage,
                isRecognizing: speechMemoRecognitionStatus == .recording,
                microphoneAccessibilityLabel: speechMemoRecognitionStatus == .recording
                    ? localization.localized(.eventMemoVoiceStop)
                    : localization.localized(.eventMemoVoiceStart),
                focusedField: $focusedField,
                onMicrophoneTap: {
                    Task {
                        await toggleSpeechMemoRecognition()
                    }
                }
            )

            if isEditingWorkClock {
                WorkInfoSection(
                    restTime: $restTime,
                    transportFee: $transportFee,
                    hourlyRate: $hourlyRate,
                    showingRestTimePicker: $showingRestTimePicker,
                    workInDate: $workInDate,
                    workOutDate: $workOutDate,
                    editingWorkTime: $editingWorkTime,
                    focusedField: $focusedField,
                    workInTitle: localization.localized(.editorWorkIn),
                    workOutTitle: localization.localized(.editorWorkOut),
                    restTimeTitle: localization.localized(.editorRestTime),
                    transportFeeTitle: localization.localized(.editorTransportFee),
                    hourlyRateTitle: localization.localized(.editorHourlyRate),
                    currencyUnit: localization.localized(.editorCurrencyUnit)
                )
            }

            if let validationMessage = validationMessage ?? errorMessage {
                validationText(validationMessage)
            }

        }
    }

    private var workRecordFormContent: some View {
        VStack(spacing: EventEditorStyle.sectionSpacing) {
            TitleInputSection(
                title: $workRecordTitle,
                placeholder: localization.localized(.editorTitle),
                focusedField: $focusedField
            )

            WorkRecordTimeSection(
                restTime: $workRecordRestTime,
                workDate: workRecordDate,
                showingRestTimePicker: $showingWorkRecordRestTimePicker,
                showingDatePicker: $showingWorkRecordDatePicker,
                workInDate: $workRecordInDate,
                workOutDate: $workRecordOutDate,
                editingWorkTime: $editingWorkRecordTime,
                focusedField: $focusedField,
                workInTitle: localization.localized(.editorWorkIn),
                workOutTitle: localization.localized(.editorWorkOut),
                restTimeTitle: localization.localized(.editorRestTime)
            )

            WorkRecordCurrencySection(
                transportFee: $workRecordTransportFee,
                hourlyRate: $workRecordHourlyRate,
                focusedField: $focusedField,
                transportFeeTitle: localization.localized(.editorTransportFee),
                hourlyRateTitle: localization.localized(.editorHourlyRate),
                currencyUnit: localization.localized(.editorCurrencyUnit)
            )

            if let errorMessage {
                validationText(errorMessage)
            }
        }
        .accessibilityIdentifier("workRecord.editor")
    }

    private func validationText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(EventEditorStyle.destructive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, EventEditorStyle.cardPadding)
    }

    @ViewBuilder
    private var floatingPickerOverlay: some View {
        if let mode = activeTimePickerMode {
            FloatingPickerOverlay(onDismiss: dismissEventTimePicker) {
                EventDateTimePickerPanel(
                    title: eventPickerTitle(for: mode),
                    startDate: $startDate,
                    endDate: $endDate,
                    isAllDay: isAllDay,
                    doneTitle: localization.localized(.done),
                    cancelTitle: localization.localized(.cancel),
                    mode: mode,
                    onCancel: dismissEventTimePicker,
                    onDone: dismissEventTimePicker
                )
                .id(mode)
            }
        } else if showingRestTimePicker {
            FloatingPickerOverlay(onDismiss: { showingRestTimePicker = false }) {
                RestTimePickerPanel(
                    restTime: $restTime,
                    title: localization.localized(.editorRestTime),
                    cancelTitle: localization.localized(.cancel),
                    doneTitle: localization.localized(.done),
                    onCancel: { showingRestTimePicker = false },
                    onDone: { showingRestTimePicker = false }
                )
            }
        } else if let target = editingWorkTime {
            FloatingPickerOverlay(onDismiss: { editingWorkTime = nil }) {
                FloatingDatePickerPanel(
                    title: target.pickerTitle(
                        workInTitle: localization.localized(.editorWorkIn),
                        workOutTitle: localization.localized(.editorWorkOut),
                        timeTitle: localization.localized(.editorTime)
                    ),
                    initialSelection: workTime(for: target),
                    cancelTitle: localization.localized(.cancel),
                    doneTitle: localization.localized(.done),
                    kind: .time,
                    confirmColor: ShiftCalendarColors.primaryBlue,
                    onCancel: { editingWorkTime = nil },
                    onDone: { selection in
                        setWorkTime(selection, for: target)
                        editingWorkTime = nil
                    }
                )
                .id(target)
            }
        } else if showingWorkRecordDatePicker {
            FloatingPickerOverlay(onDismiss: { showingWorkRecordDatePicker = false }) {
                FloatingDatePickerPanel(
                    title: localization.localized(.editorDate),
                    initialSelection: workRecordDate,
                    cancelTitle: localization.localized(.cancel),
                    doneTitle: localization.localized(.done),
                    kind: .date,
                    confirmColor: ShiftCalendarColors.primaryBlue,
                    onCancel: { showingWorkRecordDatePicker = false },
                    onDone: { selection in
                        setWorkRecordDate(selection)
                        showingWorkRecordDatePicker = false
                    }
                )
            }
        } else if showingWorkRecordRestTimePicker {
            FloatingPickerOverlay(onDismiss: { showingWorkRecordRestTimePicker = false }) {
                RestTimePickerPanel(
                    restTime: $workRecordRestTime,
                    title: localization.localized(.editorRestTime),
                    cancelTitle: localization.localized(.cancel),
                    doneTitle: localization.localized(.done),
                    onCancel: { showingWorkRecordRestTimePicker = false },
                    onDone: { showingWorkRecordRestTimePicker = false }
                )
            }
        } else if let target = editingWorkRecordTime {
            FloatingPickerOverlay(onDismiss: { editingWorkRecordTime = nil }) {
                FloatingDatePickerPanel(
                    title: target.pickerTitle(
                        workInTitle: localization.localized(.editorWorkIn),
                        workOutTitle: localization.localized(.editorWorkOut),
                        timeTitle: localization.localized(.editorTime)
                    ),
                    initialSelection: workRecordTime(for: target),
                    cancelTitle: localization.localized(.cancel),
                    doneTitle: localization.localized(.done),
                    kind: .time,
                    confirmColor: ShiftCalendarColors.primaryBlue,
                    onCancel: { editingWorkRecordTime = nil },
                    onDone: { selection in
                        setWorkRecordTime(selection, for: target)
                        editingWorkRecordTime = nil
                    }
                )
                .id(target)
            }
        }
    }

    private var activeTimePickerMode: TimePickerMode? {
        if showingStartDatePicker { return .startDate }
        if showingStartTimePicker { return .startTime }
        if showingEndDatePicker { return .endDate }
        if showingEndTimePicker { return .endTime }
        return nil
    }

    private var isFloatingPickerPresented: Bool {
        activeTimePickerMode != nil
            || showingRestTimePicker
            || editingWorkTime != nil
            || showingWorkRecordDatePicker
            || showingWorkRecordRestTimePicker
            || editingWorkRecordTime != nil
    }

    private func dismissEventTimePicker() {
        showingStartDatePicker = false
        showingStartTimePicker = false
        showingEndDatePicker = false
        showingEndTimePicker = false
    }

    private func dismissAllFloatingPickers() {
        dismissEventTimePicker()
        showingRestTimePicker = false
        editingWorkTime = nil
        showingWorkRecordDatePicker = false
        showingWorkRecordRestTimePicker = false
        editingWorkRecordTime = nil
    }

    private func eventPickerTitle(for mode: TimePickerMode) -> String {
        switch mode {
        case .startDate:
            return localization.localized(.editorStart)
        case .startTime:
            return "\(localization.localized(.editorStart)) \(localization.localized(.editorTime))"
        case .endDate:
            return localization.localized(.editorEnd)
        case .endTime:
            return "\(localization.localized(.editorEnd)) \(localization.localized(.editorTime))"
        }
    }

    private func workTime(for target: WorkTimeEditTarget) -> Date {
        switch target {
        case .workIn:
            return workInDate
        case .workOut:
            return workOutDate
        }
    }

    private func setWorkTime(_ selection: Date, for target: WorkTimeEditTarget) {
        switch target {
        case .workIn:
            workInDate = selection
        case .workOut:
            workOutDate = selection
        }
    }

    private func workRecordTime(for target: WorkTimeEditTarget) -> Date {
        switch target {
        case .workIn:
            return workRecordInDate
        case .workOut:
            return workRecordOutDate
        }
    }

    private func setWorkRecordTime(_ selection: Date, for target: WorkTimeEditTarget) {
        switch target {
        case .workIn:
            workRecordInDate = selection
        case .workOut:
            workRecordOutDate = selection
            isWorkRecordOutTimeSet = true
        }
    }

    private func setWorkRecordDate(_ selection: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: selection)
        workRecordDate = normalizedDate
        workRecordInDate = EventEditorView.date(on: normalizedDate, matchingTimeOf: workRecordInDate)
        workRecordOutDate = EventEditorView.date(on: normalizedDate, matchingTimeOf: workRecordOutDate)
    }

    private var isEditing: Bool {
        switch mode {
        case .create:
            return false
        case .edit:
            return true
        }
    }

    private var isEditingWorkClock: Bool {
        isEditing && (WorkClockTitleMatcher.kind(for: title) != nil || EventEditorView.initialWorkClockKind(for: mode) != nil)
    }

    private var editorTitle: String {
        if showsEntryKindPicker {
            return localization.localized(.entryCreateTitle)
        }
        return isEditing ? localization.localized(.editorEditEvent) : localization.localized(.editorNewEvent)
    }

    private var canSave: Bool {
        guard calendarContext.allowsEditing else { return false }
        if showsEntryKindPicker && selectedEntryKind == .workRecord {
            return !saving
        }
        return validationMessage == nil
    }

    private var validationMessage: String? {
        let normalized = normalizedDates()
        guard normalized.end > normalized.start else {
            return localization.localized(.editorInvalidDateRange)
        }
        return nil
    }

    private var speechMemoStatusMessage: String? {
        if speechMemoRecognitionStatus == .recording {
            return localization.localized(.eventMemoVoiceRecognizing)
        }
        return speechMemoMessage
    }

    private static func initialState(for mode: EventEditorMode) -> (title: String, note: String?, startDate: Date, endDate: Date, isAllDay: Bool, reminderOffsetMinutes: Int?, workInfo: WorkInfo?, shiftTemplateID: ShiftTimeTemplateID?, defaultWorkDate: Date) {
        switch mode {
        case .create(let initialDate):
            let defaultStartDate = makeDefaultEventStartDate(selectedDate: initialDate)
            return (
                title: LocalizationManager.shared.localized(.eventDefaultTitle),
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
            let editorDates = EventEditorDateNormalizer.editorDates(
                startDate: initialStartDate,
                exclusiveEndDate: initialEndDate,
                isAllDay: initialIsAllDay
            )
            return (
                title: initialTitle,
                note: initialNote,
                startDate: editorDates.start,
                endDate: editorDates.end,
                isAllDay: initialIsAllDay,
                reminderOffsetMinutes: initialReminderOffsetMinutes,
                workInfo: initialWorkInfo,
                shiftTemplateID: initialShiftTemplateID,
                defaultWorkDate: makeDefaultEventStartDate(selectedDate: initialStartDate)
            )
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

    private static func initialWorkClockKind(for mode: EventEditorMode) -> WorkClockKind? {
        if case .edit(_, let initialTitle, _, _, _, _, _, let initialWorkInfo, _) = mode {
            return WorkClockTitleMatcher.kind(for: initialTitle) ?? WorkClockTitleMatcher.kind(for: initialWorkInfo)
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

    private func saveSelectedEntry() async {
        if showsEntryKindPicker && selectedEntryKind == .workRecord {
            await saveWorkRecord()
        } else {
            await save()
        }
    }

    private func save() async {
        guard canSave else { return }
        saving = true
        errorMessage = nil

        do {
            let saveContext = normalizedSaveContext()
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let notificationResult = try await onSave(
                normalizedEventTitle(),
                trimmedNote.isEmpty ? nil : trimmedNote,
                saveContext.dates.start,
                saveContext.dates.end,
                isAllDay,
                reminderOffsetMinutes,
                selectedShiftTemplateID,
                saveContext.workInfo,
                calendarContext.resolvedCalendarID(selectedCalendarID: selectedCalendarID)
            )
            saving = false
            if let alert = NotificationSaveAlert(result: notificationResult) {
                pendingNotificationSaveAlert = alert
            } else {
                isPresented = false
            }
        } catch {
            errorMessage = error.localizedDescription
            saving = false
        }
    }

    private func saveWorkRecord() async {
        guard !saving else { return }
        guard let onSaveWorkRecordPair else {
            assertionFailure("Work record pair save action is required")
            return
        }
        saving = true
        errorMessage = nil

        do {
            try await WorkRecordEditorSaveLogic.save(
                context: workRecordSaveContext,
                defaultTitle: localization.localized(.workRecordDefaultTitle),
                calendarID: calendarContext.resolvedCalendarID(
                    selectedCalendarID: selectedCalendarID
                ),
                onSavePair: onSaveWorkRecordPair
            )
            saving = false
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
            saving = false
        }
    }

    private var workRecordSaveContext: WorkRecordEditorSaveContext {
        WorkRecordEditorSaveContext(
            title: workRecordTitle,
            workDate: workRecordDate,
            workInDate: workRecordInDate,
            workOutDate: workRecordOutDate,
            restTime: workRecordRestTime,
            transportFee: workRecordTransportFee,
            hourlyRate: workRecordHourlyRate,
            workSessionId: workRecordSessionId,
            isWorkOutTimeSet: isWorkRecordOutTimeSet,
            editInitialSession: nil
        )
    }

    @MainActor
    private func toggleSpeechMemoRecognition() async {
        focusedField = nil

        if speechMemoRecognitionStatus == .recording {
            stopSpeechMemoRecognition()
            return
        }

        speechMemoMessage = nil
        speechMemoBaseText = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let status = await speechMemoRecognitionService.startRecognition(
            language: localization.currentLanguage,
            onTranscription: { transcript, _ in
                applySpeechMemoTranscription(transcript)
            },
            onCompletion: { failure in
                handleSpeechMemoRecognitionCompletion(failure)
            }
        )

        speechMemoRecognitionStatus = status
        switch status {
        case .denied:
            speechMemoMessage = localization.localized(.eventMemoVoicePermissionDenied)
            speechMemoBaseText = ""
        case .unavailable:
            speechMemoMessage = localization.localized(.eventMemoVoiceUnavailable)
            speechMemoBaseText = ""
        case .idle, .recording:
            break
        }
    }

    @MainActor
    private func applySpeechMemoTranscription(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }

        if speechMemoBaseText.isEmpty {
            note = trimmedTranscript
        } else {
            note = "\(speechMemoBaseText)\n\(trimmedTranscript)"
        }
    }

    @MainActor
    private func handleSpeechMemoRecognitionCompletion(_ failure: SpeechMemoRecognitionFailure?) {
        speechMemoBaseText = ""

        switch failure {
        case nil:
            speechMemoRecognitionStatus = .idle
            speechMemoMessage = nil
        case .permissionDenied:
            speechMemoRecognitionStatus = .denied
            speechMemoMessage = localization.localized(.eventMemoVoicePermissionDenied)
        case .unavailable, .recognitionFailed:
            speechMemoRecognitionStatus = .unavailable
            speechMemoMessage = localization.localized(.eventMemoVoiceUnavailable)
        }
    }

    @MainActor
    private func stopSpeechMemoRecognition() {
        speechMemoRecognitionService.stopRecognition()
        speechMemoRecognitionStatus = .idle
        speechMemoMessage = nil
        speechMemoBaseText = ""
    }

    private func normalizedEventTitle() -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        if isEditingWorkClock {
            return localization.localized(.workRecordDefaultTitle)
        }
        return localization.localized(.eventDefaultTitle)
    }

    private func notificationSaveAlert(for alert: NotificationSaveAlert) -> Alert {
        switch alert {
        case .denied:
            return Alert(
                title: Text(localization.localized(.notificationPermissionDeniedTitle)),
                message: Text(localization.localized(.notificationPermissionDeniedMessage)),
                primaryButton: .default(Text(localization.localized(.notificationOpenSettings))) {
                    openNotificationSettings()
                    isPresented = false
                },
                secondaryButton: .cancel(Text(localization.localized(.cancel))) {
                    isPresented = false
                }
            )
        case .triggerDateInPast:
            return Alert(
                title: Text(localization.localized(.notificationReminderTimePastTitle)),
                message: Text(localization.localized(.notificationReminderTimePastMessage)),
                dismissButton: .default(Text(localization.localized(.ok))) {
                    isPresented = false
                }
            )
        case .failed:
            return Alert(
                title: Text(localization.localized(.notificationScheduleFailedTitle)),
                message: Text(localization.localized(.notificationScheduleFailedMessage)),
                dismissButton: .default(Text(localization.localized(.ok))) {
                    isPresented = false
                }
            )
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url) { _ in }
    }

    private func normalizedSaveContext() -> (dates: (start: Date, end: Date), workInfo: WorkInfo?) {
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

        return ((startDate, endDate), nil)
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
        EventEditorDateNormalizer.persistenceDates(
            startDate: startDate,
            inclusiveEndDate: endDate,
            isAllDay: isAllDay
        )
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

    private func formatDateOnly(_ date: Date) -> String {
        LocalizationManager.shared.formattedUserVisibleDate(for: date)
    }
}


struct WorkRecordEditorInitialSession: Identifiable, Hashable {
    let clockInEventID: UUID?
    let clockOutEventID: UUID?
    let title: String
    let workDate: Date
    let workInTime: Date?
    let workOutTime: Date?
    let restHours: Double
    let transportFee: Int?
    let hourlyRate: Int?
    let workSessionId: UUID?
    let isWorkOutTimeSet: Bool
    let calendarID: UUID

    var id: String {
        if let workSessionId {
            return workSessionId.uuidString
        }
        return [
            clockInEventID?.uuidString,
            clockOutEventID?.uuidString
        ]
        .compactMap { $0 }
        .joined(separator: "-")
    }
}

enum WorkRecordEditorMode {
    case create(initialDate: Date)
    case edit(WorkRecordEditorInitialSession)
}

struct WorkRecordEditorSaveContext {
    let title: String
    let workDate: Date
    let workInDate: Date
    let workOutDate: Date
    let restTime: Double
    let transportFee: String
    let hourlyRate: String
    let workSessionId: UUID
    let isWorkOutTimeSet: Bool
    let editInitialSession: WorkRecordEditorInitialSession?
}

enum WorkRecordEditorSaveLogic {
    static func save(
        context: WorkRecordEditorSaveContext,
        defaultTitle: String,
        calendarID: UUID,
        onSavePair: WorkRecordPairSaveAction
    ) async throws {
        let normalizedDate = Calendar.current.startOfDay(for: context.workDate)
        let normalizedIn = date(on: normalizedDate, matchingTimeOf: context.workInDate)
        let normalizedOut = normalizedClockOutDate(
            selectedClockOutDate: context.workOutDate,
            clockInDate: normalizedIn,
            workDay: normalizedDate,
            isWorkOutTimeSet: context.isWorkOutTimeSet
        )
        let recordTitle = normalizedRecordTitle(context.title, defaultTitle: defaultTitle)
        let transportFee = Int(context.transportFee.trimmingCharacters(in: .whitespacesAndNewlines))
        let hourlyRate = Int(context.hourlyRate.trimmingCharacters(in: .whitespacesAndNewlines))

        try await onSavePair(
            WorkRecordPairSaveRequest(
                clockInEventID: context.editInitialSession?.clockInEventID,
                clockOutEventID: context.editInitialSession?.clockOutEventID,
                calendarID: calendarID,
                title: recordTitle,
                workDate: normalizedDate,
                clockInDate: normalizedIn,
                clockOutDate: normalizedOut,
                restHours: context.restTime,
                transportFee: transportFee,
                hourlyRate: hourlyRate,
                sessionID: context.workSessionId,
                isWorkOutTimeSet: context.isWorkOutTimeSet
            )
        )
    }

    private static func normalizedRecordTitle(_ title: String, defaultTitle: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? defaultTitle : trimmedTitle
    }

    private static func normalizedClockOutDate(selectedClockOutDate: Date, clockInDate: Date, workDay: Date, isWorkOutTimeSet: Bool) -> Date {
        let calendar = Calendar.current
        var normalized = date(on: workDay, matchingTimeOf: selectedClockOutDate)
        if isWorkOutTimeSet && normalized <= clockInDate {
            normalized = calendar.date(byAdding: .day, value: 1, to: normalized) ?? normalized
        }
        return normalized
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
}

struct WorkRecordEditorView: View {
    @Environment(\.localization) private var localization
    @Binding var isPresented: Bool
    let mode: WorkRecordEditorMode
    let existingEvents: [EventOccurrence]
    let onSavePair: WorkRecordPairSaveAction
    var onSaved: (() -> Void)?
    private let availableCalendars: [TimeNestCalendar]
    private let calendarContext: EntryCalendarContext

    @State private var workDate: Date
    @State private var selectedCalendarID: UUID
    @State private var workInDate: Date
    @State private var workOutDate: Date
    @State private var restTime: Double
    @State private var transportFee: String
    @State private var hourlyRate: String
    @State private var workSessionId: UUID
    @State private var isWorkOutTimeSet: Bool
    @State private var workTitle: String = ""
    @State private var showingWorkDatePicker: Bool = false
    @State private var showingRestTimePicker: Bool = false
    @State private var editingWorkTime: WorkTimeEditTarget?
    @State private var saving: Bool = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: EditorFocusedField?

    init(
        isPresented: Binding<Bool>,
        mode: WorkRecordEditorMode,
        existingEvents: [EventOccurrence] = [],
        availableCalendars: [TimeNestCalendar] = [],
        calendarContext: EntryCalendarContext = .fixedWritableCalendar(TimeNestCalendar.personalID),
        onSavePair: @escaping WorkRecordPairSaveAction,
        onSaved: (() -> Void)? = nil
    ) {
        _isPresented = isPresented
        self.mode = mode
        self.existingEvents = existingEvents
        self.availableCalendars = availableCalendars.filter(\.canEditContent)
        self.calendarContext = calendarContext
        _selectedCalendarID = State(
            initialValue: calendarContext.initialCalendarID(in: availableCalendars)
        )
        self.onSavePair = onSavePair
        self.onSaved = onSaved

        let initialValues = WorkRecordEditorView.initialValues(for: mode)
        _workTitle = State(initialValue: initialValues.title)
        _workDate = State(initialValue: initialValues.workDate)
        _workInDate = State(initialValue: initialValues.workInTime)
        _workOutDate = State(initialValue: initialValues.workOutTime)
        _restTime = State(initialValue: initialValues.restHours)
        _transportFee = State(initialValue: initialValues.transportFee.map(String.init) ?? "")
        _hourlyRate = State(initialValue: initialValues.hourlyRate.map(String.init) ?? "")
        _workSessionId = State(initialValue: initialValues.workSessionId)
        _isWorkOutTimeSet = State(initialValue: initialValues.isWorkOutTimeSet)
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
                        canSave: calendarContext.allowsEditing && !saving,
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
                            if calendarContext.showsCalendarSelector && !availableCalendars.isEmpty {
                                CalendarAssignmentEditorSection(
                                    calendars: availableCalendars,
                                    selectedCalendarID: $selectedCalendarID
                                )
                            }
                            TitleInputSection(
                                title: $workTitle,
                                placeholder: localization.localized(.editorTitle),
                                focusedField: $focusedField
                            )

                            workDateSection

                            WorkInfoSection(
                                restTime: $restTime,
                                transportFee: $transportFee,
                                hourlyRate: $hourlyRate,
                                showingRestTimePicker: $showingRestTimePicker,
                                workInDate: $workInDate,
                                workOutDate: $workOutDate,
                                editingWorkTime: $editingWorkTime,
                                focusedField: $focusedField,
                                workInTitle: localization.localized(.editorWorkIn),
                                workOutTitle: localization.localized(.editorWorkOut),
                                restTimeTitle: localization.localized(.editorRestTime),
                                transportFeeTitle: localization.localized(.editorTransportFee),
                                hourlyRateTitle: localization.localized(.editorHourlyRate),
                                currencyUnit: localization.localized(.editorCurrencyUnit)
                            )

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundColor(EventEditorStyle.destructive)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, EventEditorStyle.cardPadding)
                            }
                        }
                        .padding(.horizontal, EventEditorStyle.horizontalPadding)
                        .padding(.top, EventEditorStyle.contentTopPadding)
                        .padding(.bottom, EventEditorStyle.contentBottomPadding)
                    }
                    .scrollIndicators(.hidden)
                }

                floatingPickerOverlay
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
            .onChange(of: isFloatingPickerPresented) { _, isPresented in
                if isPresented {
                    focusedField = nil
                }
            }
        }
        .presentationDetents([.fraction(0.6), .large])
    }

    private var editorTitle: String {
        switch mode {
        case .create:
            return localization.localized(.workRecordAdd)
        case .edit:
            return localization.localized(.workRecordEdit)
        }
    }

    private var workDateSection: some View {
        WorkRecordDateSection(
            title: localization.localized(.editorDate),
            dateText: formatDateOnly(workDate),
            onTap: {
                focusedField = nil
                showingWorkDatePicker = true
            }
        )
    }

    private var workRecordSaveContext: WorkRecordEditorSaveContext {
        WorkRecordEditorSaveContext(
            title: workTitle,
            workDate: workDate,
            workInDate: workInDate,
            workOutDate: workOutDate,
            restTime: restTime,
            transportFee: transportFee,
            hourlyRate: hourlyRate,
            workSessionId: workSessionId,
            isWorkOutTimeSet: isWorkOutTimeSet,
            editInitialSession: editInitialSession
        )
    }

    private var editInitialSession: WorkRecordEditorInitialSession? {
        if case .edit(let session) = mode {
            return session
        }
        return nil
    }

    @ViewBuilder
    private var floatingPickerOverlay: some View {
        if showingWorkDatePicker {
            FloatingPickerOverlay(onDismiss: { showingWorkDatePicker = false }) {
                FloatingDatePickerPanel(
                    title: localization.localized(.editorDate),
                    initialSelection: workDate,
                    cancelTitle: localization.localized(.cancel),
                    doneTitle: localization.localized(.done),
                    kind: .date,
                    confirmColor: ShiftCalendarColors.primaryBlue,
                    onCancel: { showingWorkDatePicker = false },
                    onDone: { selection in
                        setWorkDate(selection)
                        showingWorkDatePicker = false
                    }
                )
            }
        } else if showingRestTimePicker {
            FloatingPickerOverlay(onDismiss: { showingRestTimePicker = false }) {
                RestTimePickerPanel(
                    restTime: $restTime,
                    title: localization.localized(.editorRestTime),
                    cancelTitle: localization.localized(.cancel),
                    doneTitle: localization.localized(.done),
                    onCancel: { showingRestTimePicker = false },
                    onDone: { showingRestTimePicker = false }
                )
            }
        } else if let target = editingWorkTime {
            FloatingPickerOverlay(onDismiss: { editingWorkTime = nil }) {
                FloatingDatePickerPanel(
                    title: target.pickerTitle(
                        workInTitle: localization.localized(.editorWorkIn),
                        workOutTitle: localization.localized(.editorWorkOut),
                        timeTitle: localization.localized(.editorTime)
                    ),
                    initialSelection: workTime(for: target),
                    cancelTitle: localization.localized(.cancel),
                    doneTitle: localization.localized(.done),
                    kind: .time,
                    confirmColor: ShiftCalendarColors.primaryBlue,
                    onCancel: { editingWorkTime = nil },
                    onDone: { selection in
                        setWorkTime(selection, for: target)
                        editingWorkTime = nil
                    }
                )
                .id(target)
            }
        }
    }

    private var isFloatingPickerPresented: Bool {
        showingWorkDatePicker || showingRestTimePicker || editingWorkTime != nil
    }

    private func workTime(for target: WorkTimeEditTarget) -> Date {
        switch target {
        case .workIn:
            return workInDate
        case .workOut:
            return workOutDate
        }
    }

    private func setWorkTime(_ selection: Date, for target: WorkTimeEditTarget) {
        switch target {
        case .workIn:
            workInDate = selection
        case .workOut:
            workOutDate = selection
            isWorkOutTimeSet = true
        }
    }

    private func setWorkDate(_ selection: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: selection)
        workDate = normalizedDate
        workInDate = WorkRecordEditorView.date(on: normalizedDate, matchingTimeOf: workInDate)
        workOutDate = WorkRecordEditorView.date(on: normalizedDate, matchingTimeOf: workOutDate)
    }

    private func save() async {
        guard !saving else { return }
        saving = true
        errorMessage = nil

        do {
            try await WorkRecordEditorSaveLogic.save(
                context: workRecordSaveContext,
                defaultTitle: localization.localized(.workRecordDefaultTitle),
                calendarID: calendarContext.resolvedCalendarID(
                    selectedCalendarID: selectedCalendarID
                ),
                onSavePair: onSavePair
            )
            saving = false
            isPresented = false
            onSaved?()
        } catch {
            errorMessage = error.localizedDescription
            saving = false
        }
    }

    private func formatDateOnly(_ date: Date) -> String {
        LocalizationManager.shared.formattedUserVisibleDate(for: date)
    }

    fileprivate static func initialValues(for mode: WorkRecordEditorMode) -> (title: String, workDate: Date, workInTime: Date, workOutTime: Date, restHours: Double, transportFee: Int?, hourlyRate: Int?, workSessionId: UUID, isWorkOutTimeSet: Bool) {
        switch mode {
        case .create(let initialDate):
            let workDate = Calendar.current.startOfDay(for: initialDate)
            let workInTime = makeDefaultWorkInDate(selectedDate: workDate)
            let workOutTime = workDate
            return (
                title: LocalizationManager.shared.localized(.workRecordDefaultTitle),
                workDate: workDate,
                workInTime: workInTime,
                workOutTime: workOutTime,
                restHours: 0.0,
                transportFee: nil,
                hourlyRate: nil,
                workSessionId: WorkInfo.makeNewWorkSessionId(),
                isWorkOutTimeSet: false
            )
        case .edit(let session):
            let workDate = Calendar.current.startOfDay(for: session.workDate)
            let fallbackInTime = session.workInTime ?? makeDefaultWorkInDate(selectedDate: workDate)
            let fallbackOutTime = editWorkOutTime(
                for: session,
                workDate: workDate,
                fallbackInTime: fallbackInTime
            )
            return (
                title: session.title,
                workDate: workDate,
                workInTime: fallbackInTime,
                workOutTime: fallbackOutTime,
                restHours: session.restHours,
                transportFee: session.transportFee,
                hourlyRate: session.hourlyRate,
                workSessionId: session.workSessionId ?? WorkInfo.makeNewWorkSessionId(),
                isWorkOutTimeSet: session.isWorkOutTimeSet
            )
        }
    }

    private static func editWorkOutTime(for session: WorkRecordEditorInitialSession, workDate: Date, fallbackInTime: Date) -> Date {
        if session.isWorkOutTimeSet {
            return session.workOutTime ?? workDate
        }
        if session.workInTime != nil || session.workOutTime != nil {
            return makeDefaultWorkInDate(selectedDate: workDate)
        }
        return session.workOutTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: fallbackInTime) ?? fallbackInTime
    }

    private static func makeDefaultWorkInDate(selectedDate: Date, now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: selectedDate)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        return calendar.date(
            bySettingHour: nowComponents.hour ?? 0,
            minute: nowComponents.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
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
                .font(TimeNestTheme.Fonts.popupTitle)
                .foregroundColor(EventEditorStyle.primaryText)
                .lineLimit(1)

            HStack {
                Button(cancelTitle, action: onCancel)
                    .buttonStyle(HeaderCapsuleButtonStyle(isEnabled: !saving))
                    .disabled(saving)
                    .accessibilityIdentifier("entry.editor.cancel")

                Spacer()

                Button(saveTitle, action: onSave)
                    .buttonStyle(HeaderCapsuleButtonStyle(isEnabled: canSave && !saving))
                    .disabled(!canSave || saving)
                    .accessibilityIdentifier("entry.editor.save")
            }
        }
        .padding(.horizontal, EventEditorStyle.horizontalPadding)
        .padding(.top, 22)
        .padding(.bottom, EventEditorStyle.headerBottomPadding)
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

private struct WorkRecordDateSection: View {
    let title: String
    let dateText: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(EventEditorStyle.secondaryText)

                Spacer()

                Text(dateText)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(EventEditorStyle.primaryText)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(EventEditorStyle.secondaryText)
            }
            .frame(height: EventEditorStyle.rowHeight)
            .padding(.horizontal, EventEditorStyle.cardPadding)
        }
        .buttonStyle(.plain)
        .cardContainer()
    }
}

/// 提醒时间选择器弹窗
private struct ReminderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ModalHeaderCloseButton {
                        showingReminderPicker = false
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Memo Section

private struct MemoInputSection: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let statusMessage: String?
    let isRecognizing: Bool
    let microphoneAccessibilityLabel: String
    var focusedField: FocusState<EditorFocusedField?>.Binding
    let onMicrophoneTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(EventEditorStyle.secondaryText)
                .padding(.horizontal, EventEditorStyle.cardPadding)

            HStack(alignment: .center, spacing: 12) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .focused(focusedField, equals: .note)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundColor(EventEditorStyle.fieldText)
                    .lineLimit(1...5)
                    .tint(EventEditorStyle.primaryText)

                Button(action: onMicrophoneTap) {
                    Image(systemName: isRecognizing ? "mic.fill" : "mic")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(isRecognizing ? ShiftCalendarColors.primaryBlue : EventEditorStyle.secondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(microphoneAccessibilityLabel)
            }
            .padding(.leading, EventEditorStyle.cardPadding)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .frame(minHeight: 72)
            .background(EventEditorStyle.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.cardCornerRadius, style: .continuous))

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(isRecognizing ? ShiftCalendarColors.primaryBlue : EventEditorStyle.secondaryText)
                    .padding(.horizontal, EventEditorStyle.cardPadding)
            }
        }
    }
}

private struct EventTimeSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isAllDay: Bool
    @Binding var reminderOffsetMinutes: Int?
    let allDayTitle: String
    let reminderTitle: String
    let startTitle: String
    let endTitle: String
    let reminderOptions: [Int?]
    let reminderTitleFormatter: (Int?) -> String
    @Binding var showingReminderPicker: Bool
    @Binding var showingStartDatePicker: Bool
    @Binding var showingStartTimePicker: Bool
    @Binding var showingEndDatePicker: Bool
    @Binding var showingEndTimePicker: Bool

    var body: some View {
        VStack(spacing: 0) {
            allDayReminderRow

            CardDivider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Text(startTitle)
                        .font(.subheadline)
                        .foregroundColor(EventEditorStyle.secondaryText)
                        .frame(minWidth: 40, alignment: .leading)

                    HStack(spacing: 8) {
                        Button {
                            showingStartDatePicker = true
                        } label: {
                            Text(formatDateOnly(startDate))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(EventEditorStyle.fieldText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .glassCapsuleStyle()
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingStartTimePicker = true
                        } label: {
                            Text(formatTimeOnly(startDate))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(EventEditorStyle.fieldText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .glassCapsuleStyle()
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }

                HStack(alignment: .center, spacing: 8) {
                    Text(endTitle)
                        .font(.subheadline)
                        .foregroundColor(EventEditorStyle.secondaryText)
                        .frame(minWidth: 40, alignment: .leading)

                    HStack(spacing: 8) {
                        Button {
                            showingEndDatePicker = true
                        } label: {
                            Text(formatDateOnly(endDate))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(EventEditorStyle.fieldText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .glassCapsuleStyle()
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingEndTimePicker = true
                        } label: {
                            Text(formatTimeOnly(endDate))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(EventEditorStyle.fieldText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .glassCapsuleStyle()
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }
            .padding(EventEditorStyle.cardPadding)
        }
        .sheet(isPresented: $showingReminderPicker) {
            ReminderPickerSheet(
                title: reminderTitle,
                reminderOffsetMinutes: $reminderOffsetMinutes,
                reminderOptions: reminderOptions,
                reminderTitleFormatter: reminderTitleFormatter,
                showingReminderPicker: $showingReminderPicker
            )
        }
    }

    private var allDayReminderRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                allDayToggleRow
                    .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(EventEditorStyle.dividerColor)
                    .frame(width: 1 / UIScreen.main.scale, height: 26)

                reminderButtonRow
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, EventEditorStyle.cardPadding)
            .frame(minHeight: EventEditorStyle.rowHeight)

            VStack(spacing: 0) {
                allDayToggleRow
                    .padding(.horizontal, EventEditorStyle.cardPadding)
                    .frame(minHeight: EventEditorStyle.rowHeight)

                CardDivider()

                reminderButtonRow
                    .padding(.horizontal, EventEditorStyle.cardPadding)
                    .frame(minHeight: EventEditorStyle.rowHeight)
            }
        }
    }

    private var allDayToggleRow: some View {
        Toggle(isOn: $isAllDay) {
            Text(allDayTitle)
                .font(.subheadline)
                .foregroundColor(EventEditorStyle.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(EventEditorStyle.primaryText)
    }

    private var reminderButtonRow: some View {
        Button {
            showingReminderPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(reminderTitle)
                    .font(.subheadline)
                    .foregroundColor(EventEditorStyle.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 6)

                Text(reminderTitleFormatter(reminderOffsetMinutes))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(EventEditorStyle.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(EventEditorStyle.secondaryText)
                    .padding(.leading, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatDateOnly(_ date: Date) -> String {
        LocalizationManager.shared.formattedUserVisibleDate(for: date)
    }

    private func formatTimeOnly(_ date: Date) -> String {
        LocalizationManager.shared.dateFormatter(dateFormat: "HH:mm").string(from: date)
    }
}

private enum TimePickerMode: Hashable {
    case startDate
    case startTime
    case endDate
    case endTime
}

private struct EventDateTimePickerPanel: View {
    let title: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    let isAllDay: Bool
    let doneTitle: String
    let cancelTitle: String
    let mode: TimePickerMode
    let onCancel: () -> Void
    let onDone: () -> Void

    @State private var tempDate: Date

    init(
        title: String,
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        isAllDay: Bool,
        doneTitle: String,
        cancelTitle: String,
        mode: TimePickerMode,
        onCancel: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.title = title
        _startDate = startDate
        _endDate = endDate
        self.isAllDay = isAllDay
        self.doneTitle = doneTitle
        self.cancelTitle = cancelTitle
        self.mode = mode
        self.onCancel = onCancel
        self.onDone = onDone
        
        // 根据模式初始化 tempDate
        switch mode {
        case .startDate, .startTime:
            _tempDate = State(initialValue: startDate.wrappedValue)
        case .endDate, .endTime:
            _tempDate = State(initialValue: endDate.wrappedValue)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(TimeNestTheme.Fonts.popupTitle)
                .foregroundColor(TimeNestTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            pickerContent

            FloatingPickerActionRow(
                cancelTitle: cancelTitle,
                confirmTitle: doneTitle,
                confirmColor: ShiftCalendarColors.primaryBlue,
                onCancel: onCancel,
                onConfirm: {
                    commitSelection()
                    onDone()
                }
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .frame(maxWidth: panelMaximumWidth)
        .floatingPickerPanelStyle()
        .environment(\.locale, LocalizationManager.shared.calendarLocale)
        .environment(\.calendar, LocalizationManager.shared.calendar)
    }

    @ViewBuilder
    private var pickerContent: some View {
        if isAllDay || mode == .startDate || mode == .endDate {
            DatePicker(
                "",
                selection: $tempDate,
                in: dateRangeForMode(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
        } else {
            HourMinute24Picker(selection: $tempDate)
        }
    }

    private var panelMaximumWidth: CGFloat {
        isAllDay || mode == .startDate || mode == .endDate ? 340 : 300
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
            if isAllDay, endDate < startDate {
                endDate = startDate
            } else if !isAllDay, endDate <= startDate {
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
            if isAllDay, endDate < startDate {
                startDate = endDate
            } else if !isAllDay, endDate <= startDate {
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
            .accessibilityIdentifier("entry.title")
    }
}

/// 休息时间选择器浮层。
private struct RestTimePickerPanel: View {
    @Binding var restTime: Double // 休息时间（小时）
    let title: String
    let cancelTitle: String
    let doneTitle: String
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        FloatingDatePickerPanel(
            title: title,
            initialSelection: restTimeToDuration(restTime),
            cancelTitle: cancelTitle,
            doneTitle: doneTitle,
            kind: .time,
            confirmColor: ShiftCalendarColors.primaryBlue,
            onCancel: onCancel,
            onDone: { selection in
                restTime = durationToRestTime(selection)
                onDone()
            }
        )
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
}

// MARK: - Work Info Section

private enum WorkTimeEditTarget: Hashable, Identifiable {
    case workIn
    case workOut

    var id: Self { self }

    func pickerTitle(workInTitle: String, workOutTitle: String, timeTitle: String) -> String {
        switch self {
        case .workIn:
            return "\(workInTitle) \(timeTitle)"
        case .workOut:
            return "\(workOutTitle) \(timeTitle)"
        }
    }
}

private struct WorkRecordTimeSection: View {
    @Binding var restTime: Double
    let workDate: Date
    @Binding var showingRestTimePicker: Bool
    @Binding var showingDatePicker: Bool
    @Binding var workInDate: Date
    @Binding var workOutDate: Date
    @Binding var editingWorkTime: WorkTimeEditTarget?
    var focusedField: FocusState<EditorFocusedField?>.Binding

    let workInTitle: String
    let workOutTitle: String
    let restTimeTitle: String

    var body: some View {
        VStack(spacing: 0) {
            workTimeRow(
                title: workInTitle,
                time: workInDate,
                target: .workIn
            )

            CardDivider()

            restTimeRow

            CardDivider()

            workTimeRow(
                title: workOutTitle,
                time: workOutDate,
                target: .workOut
            )
        }
        .cardContainer()
    }

    private func workTimeRow(title: String, time: Date, target: WorkTimeEditTarget) -> some View {
        HStack(alignment: .center, spacing: 8) {
            rowTitle(title)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button {
                    focusedField.wrappedValue = nil
                    showingDatePicker = true
                } label: {
                    dateValuePill(formatDateOnly(workDate))
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())

                Button {
                    focusedField.wrappedValue = nil
                    editingWorkTime = target
                } label: {
                    timeValuePill(formatWorkTime(time))
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, EventEditorStyle.cardPadding)
        .frame(minHeight: EventEditorStyle.rowHeight + 8)
    }

    private var restTimeRow: some View {
        HStack(alignment: .center, spacing: 8) {
            rowTitle(restTimeTitle)

            Spacer(minLength: 8)

            Button {
                focusedField.wrappedValue = nil
                showingRestTimePicker = true
            } label: {
                timeValuePill(formatRestTime(restTime))
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
        }
        .padding(.horizontal, EventEditorStyle.cardPadding)
        .frame(minHeight: EventEditorStyle.rowHeight + 8)
    }

    private func rowTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(EventEditorStyle.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(width: 76, alignment: .leading)
    }

    private func dateValuePill(_ text: String) -> some View {
        valueText(text)
            .frame(minWidth: 112, maxWidth: .infinity)
            .frame(height: EventEditorStyle.workInfoTimePillHeight)
            .glassCapsuleStyle()
    }

    private func timeValuePill(_ text: String) -> some View {
        valueText(text)
            .frame(width: EventEditorStyle.workInfoTimePillWidth,
                   height: EventEditorStyle.workInfoTimePillHeight)
            .glassCapsuleStyle()
    }

    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundColor(EventEditorStyle.fieldText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private func formatDateOnly(_ date: Date) -> String {
        LocalizationManager.shared.formattedUserVisibleDate(for: date)
    }

    private func formatWorkTime(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func formatRestTime(_ hours: Double) -> String {
        let hour = Int(hours)
        let minute = Int((hours - Double(hour)) * 60)
        return String(format: "%d:%02d", hour, minute)
    }
}

private struct WorkRecordCurrencySection: View {
    @Binding var transportFee: String
    @Binding var hourlyRate: String
    var focusedField: FocusState<EditorFocusedField?>.Binding

    let transportFeeTitle: String
    let hourlyRateTitle: String
    let currencyUnit: String

    var body: some View {
        HStack(spacing: EventEditorStyle.workColumnSpacing) {
            currencyField(title: transportFeeTitle, value: $transportFee, field: .transportFee)
            currencyField(title: hourlyRateTitle, value: $hourlyRate, field: .hourlyRate)
        }
        .padding(.horizontal, EventEditorStyle.cardPadding)
        .padding(.vertical, EventEditorStyle.workInfoVerticalPadding)
        .cardContainer()
    }

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
}

/// 打工时间和收入信息输入组件
private struct WorkInfoSection: View {
    @Binding var restTime: Double
    @Binding var transportFee: String
    @Binding var hourlyRate: String
    @Binding var showingRestTimePicker: Bool
    @Binding var workInDate: Date
    @Binding var workOutDate: Date
    @Binding var editingWorkTime: WorkTimeEditTarget?
    var focusedField: FocusState<EditorFocusedField?>.Binding

    let workInTitle: String
    let workOutTitle: String
    let restTimeTitle: String
    let transportFeeTitle: String
    let hourlyRateTitle: String
    let currencyUnit: String

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: EventEditorStyle.workColumnSpacing) {
                workColumn(title: workInTitle) {
                    Button {
                        focusedField.wrappedValue = nil
                        editingWorkTime = .workIn
                    } label: {
                        workInfoTimeValuePillLabel(formatWorkTime(workInDate))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                }

                workColumn(title: restTimeTitle) {
                    Button {
                        focusedField.wrappedValue = nil
                        showingRestTimePicker = true
                    } label: {
                        workInfoTimeValuePillLabel(formatRestTime(restTime))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                }

                workColumn(title: workOutTitle) {
                    Button {
                        focusedField.wrappedValue = nil
                        editingWorkTime = .workOut
                    } label: {
                        workInfoTimeValuePillLabel(formatWorkTime(workOutDate))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                }
            }

            CardDivider()

            HStack(spacing: EventEditorStyle.workColumnSpacing) {
                currencyField(title: transportFeeTitle, value: $transportFee, field: .transportFee)
                currencyField(title: hourlyRateTitle, value: $hourlyRate, field: .hourlyRate)
            }
        }
        .padding(.horizontal, EventEditorStyle.cardPadding)
        .padding(.vertical, EventEditorStyle.workInfoVerticalPadding)
        .cardContainer()
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
            .glassCapsuleStyle()
    }

    private func formatWorkTime(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
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

private struct CalendarAssignmentEditorSection: View {
    @Environment(\.localization) private var localization
    let calendars: [TimeNestCalendar]
    @Binding var selectedCalendarID: UUID

    var body: some View {
        HStack {
            Label(
                localization.localized(.calendarSharingSelectCalendar),
                systemImage: "calendar"
            )
            .foregroundStyle(EventEditorStyle.primaryText)
            Spacer()
            Picker("", selection: $selectedCalendarID) {
                ForEach(calendars) { calendar in
                    Text(calendar.name).tag(calendar.id)
                }
            }
            .labelsHidden()
        }
        .padding(EventEditorStyle.cardPadding)
        .background(EventEditorStyle.cardBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: EventEditorStyle.cardCornerRadius,
                style: .continuous
            )
        )
        .accessibilityIdentifier("entry.calendarSelector")
    }
}
