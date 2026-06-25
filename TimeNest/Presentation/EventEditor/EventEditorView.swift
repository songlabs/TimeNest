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
        case .failed:
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

struct EventEditorView: View {
    @Environment(\.localization) private var localization
    @Environment(\.openURL) private var openURL
    @Binding var isPresented: Bool
    let mode: EventEditorMode
    let existingEvents: [EventOccurrence]
    var onSave: (String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> EventNotificationScheduleResult
    var onUpdateEvent: ((UUID, String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> EventNotificationScheduleResult)?
    var onReloadEvents: ((Date) async -> [EventOccurrence])?

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
    @State private var pendingWorkClockConfirmation: WorkClockConfirmation?
    @State private var pendingNotificationSaveAlert: NotificationSaveAlert?
    @State private var workSessionId: UUID
    @State private var workRecordEvents: [EventOccurrence]
    @State private var showingAddWorkRecord: Bool = false
    @State private var editingWorkRecord: WorkRecordEditorInitialSession?
    @FocusState private var focusedField: EditorFocusedField?

    private let reminderOptions: [Int?] = [nil, 0, 5, 10, 15, 30, 60, 1440]

    init(
        isPresented: Binding<Bool>,
        mode: EventEditorMode,
        existingEvents: [EventOccurrence] = [],
        onSave: @escaping (String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> EventNotificationScheduleResult,
        onUpdateEvent: ((UUID, String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> EventNotificationScheduleResult)? = nil,
        onReloadEvents: ((Date) async -> [EventOccurrence])? = nil
    ) {
        _isPresented = isPresented
        self.mode = mode
        self.existingEvents = existingEvents
        self.onSave = onSave
        self.onUpdateEvent = onUpdateEvent
        self.onReloadEvents = onReloadEvents

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
        _workRecordEvents = State(initialValue: existingEvents)
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
                                    startTitle: localization.localized(.editorStart),
                                    endTitle: localization.localized(.editorEnd),
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
                                Text(validationMessage)
                                    .font(.footnote)
                                    .foregroundColor(EventEditorStyle.destructive)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, EventEditorStyle.cardPadding)
                            }

                            if shouldShowWorkRecordsSection {
                                workRecordsSection
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
            .onAppear {
                applySharedWorkValuesForNewEventIfNeeded(date: startDate, resetWhenMissing: false)
            }
            .onChange(of: startDate) { oldValue, newValue in
                handleStartDateChange(from: oldValue, to: newValue)
            }
            .onChange(of: isFloatingPickerPresented) { _, isPresented in
                if isPresented {
                    focusedField = nil
                }
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
            .alert(item: $pendingNotificationSaveAlert) { alert in
                notificationSaveAlert(for: alert)
            }
            .sheet(isPresented: $showingAddWorkRecord) {
                WorkRecordEditorView(
                    isPresented: $showingAddWorkRecord,
                    mode: .create(initialDate: workRecordTargetDate),
                    existingEvents: workRecordEvents,
                    onCreateEvent: { title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo in
                        try await onSave(title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo)
                    },
                    onSaved: {
                        Task {
                            await reloadWorkRecordEvents(for: workRecordTargetDate)
                        }
                    }
                )
            }
            .sheet(item: $editingWorkRecord) { session in
                WorkRecordEditorView(
                    isPresented: workRecordEditingPresentationBinding,
                    mode: .edit(session),
                    existingEvents: workRecordEvents,
                    onCreateEvent: { title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo in
                        try await onSave(title, note, startDate, endDate, isAllDay, reminderOffsetMinutes, shiftTemplateID, workInfo)
                    },
                    onUpdateEvent: onUpdateEvent,
                    onSaved: {
                        Task {
                            await reloadWorkRecordEvents(for: workRecordTargetDate)
                        }
                    }
                )
            }
        }
        .presentationDetents([.fraction(0.6), .large])
    }

    private var shouldShowWorkRecordsSection: Bool {
        !isEditing && onReloadEvents != nil
    }

    private var workRecordTargetDate: Date {
        Calendar.current.startOfDay(for: startDate)
    }

    private var workRecordSessions: [WorkRecordDisplaySession] {
        let calendar = Calendar.current
        let targetDate = workRecordTargetDate
        let workEvents = workRecordEvents.filter { event in
            event.isWorkClockEvent && calendar.isDate(event.workDate, inSameDayAs: targetDate)
        }
        return WorkRecordDisplaySession.make(from: workEvents, selectedDate: targetDate)
    }

    private var workRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.localized(.workRecordSectionTitle))
                .font(.headline.weight(.semibold))
                .foregroundColor(EventEditorStyle.primaryText)

            if workRecordSessions.isEmpty {
                Text(localization.localized(.workRecordEmpty))
                    .font(.footnote)
                    .foregroundColor(EventEditorStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(workRecordSessions) { session in
                        WorkRecordSummaryRowView(
                            session: session,
                            selectedDate: workRecordTargetDate,
                            onEdit: onUpdateEvent == nil ? nil : {
                                editingWorkRecord = session.editorInitialSession(selectedDate: workRecordTargetDate)
                            }
                        )
                    }
                }
            }

            Button {
                focusedField = nil
                showingAddWorkRecord = true
            } label: {
                Text(localization.localized(.workRecordAdd))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: EventEditorStyle.rowHeight)
                    .background(ShiftCalendarColors.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: EventEditorStyle.controlCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(EventEditorStyle.cardPadding)
        .cardContainer()
    }

    private func reloadWorkRecordEvents(for date: Date) async {
        guard let onReloadEvents else { return }
        workRecordEvents = await onReloadEvents(date)
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
        activeTimePickerMode != nil || showingRestTimePicker || editingWorkTime != nil
    }

    private func dismissEventTimePicker() {
        showingStartDatePicker = false
        showingStartTimePicker = false
        showingEndDatePicker = false
        showingEndTimePicker = false
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
        isEditing ? localization.localized(.editorEditEvent) : localization.localized(.editorNewEvent)
    }

    private var canSave: Bool {
        validationMessage == nil
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
        Task {
            await reloadWorkRecordEvents(for: newValue)
        }
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
            let notificationResult = try await onSave(normalizedEventTitle(), trimmedNote.isEmpty ? nil : trimmedNote, saveContext.dates.start, saveContext.dates.end, isAllDay, reminderOffsetMinutes, selectedShiftTemplateID, saveContext.workInfo)
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

        return ((startDate, endDate), currentWorkInfo(
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

struct WorkRecordEditorView: View {
    @Environment(\.localization) private var localization
    @Binding var isPresented: Bool
    let mode: WorkRecordEditorMode
    let existingEvents: [EventOccurrence]
    let onCreateEvent: (String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> EventNotificationScheduleResult
    var onUpdateEvent: ((UUID, String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> EventNotificationScheduleResult)?
    var onSaved: (() -> Void)?

    @State private var workDate: Date
    @State private var workInDate: Date
    @State private var workOutDate: Date
    @State private var restTime: Double
    @State private var transportFee: String
    @State private var hourlyRate: String
    @State private var workSessionId: UUID
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
        onCreateEvent: @escaping (String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> EventNotificationScheduleResult,
        onUpdateEvent: ((UUID, String, String?, Date, Date, Bool, Int?, ShiftTimeTemplateID?, WorkInfo) async throws -> EventNotificationScheduleResult)? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        _isPresented = isPresented
        self.mode = mode
        self.existingEvents = existingEvents
        self.onCreateEvent = onCreateEvent
        self.onUpdateEvent = onUpdateEvent
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
                        canSave: !saving,
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
        Button {
            focusedField = nil
            showingWorkDatePicker = true
        } label: {
            HStack {
                Text(localization.localized(.editorDate))
                    .font(.subheadline)
                    .foregroundColor(EventEditorStyle.secondaryText)

                Spacer()

                Text(formatDateOnly(workDate))
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
            let normalizedDate = Calendar.current.startOfDay(for: workDate)
            let normalizedIn = WorkRecordEditorView.date(on: normalizedDate, matchingTimeOf: workInDate)
            let normalizedOut = normalizedClockOutDate(selectedClockOutDate: workOutDate, clockInDate: normalizedIn, workDay: normalizedDate)
            let recordTitle = normalizedRecordTitle()
            let clockInWorkInfo = WorkInfo(
                workInTime: normalizedIn,
                workOutTime: nil,
                restHours: restTime,
                workDate: normalizedDate,
                transportFee: Int(transportFee.trimmingCharacters(in: .whitespacesAndNewlines)),
                hourlyRate: Int(hourlyRate.trimmingCharacters(in: .whitespacesAndNewlines)),
                workSessionId: workSessionId
            )
            let clockOutWorkInfo = WorkInfo(
                workInTime: nil,
                workOutTime: normalizedOut,
                restHours: restTime,
                workDate: normalizedDate,
                transportFee: Int(transportFee.trimmingCharacters(in: .whitespacesAndNewlines)),
                hourlyRate: Int(hourlyRate.trimmingCharacters(in: .whitespacesAndNewlines)),
                workSessionId: workSessionId
            )

            try await saveClock(kind: .clockIn, title: recordTitle, workInfo: clockInWorkInfo)
            try await saveClock(kind: .clockOut, title: recordTitle, workInfo: clockOutWorkInfo)
            saving = false
            isPresented = false
            onSaved?()
        } catch {
            errorMessage = error.localizedDescription
            saving = false
        }
    }

    @discardableResult
    private func saveClock(kind: WorkClockKind, title: String, workInfo: WorkInfo) async throws -> EventNotificationScheduleResult {
        let eventID: UUID?
        let clockDate: Date

        switch kind {
        case .clockIn:
            eventID = editInitialSession?.clockInEventID
            clockDate = workInfo.workInTime ?? workDate
        case .clockOut:
            eventID = editInitialSession?.clockOutEventID
            clockDate = workInfo.workOutTime ?? workDate
        }

        let dates = workClockSaveDates(for: clockDate)
        if let eventID, let onUpdateEvent {
            return try await onUpdateEvent(eventID, title, nil, dates.start, dates.end, false, nil, nil, workInfo)
        }
        return try await onCreateEvent(title, nil, dates.start, dates.end, false, nil, nil, workInfo)
    }

    private func normalizedRecordTitle() -> String {
        let trimmedTitle = workTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? localization.localized(.workRecordDefaultTitle) : trimmedTitle
    }

    private var editInitialSession: WorkRecordEditorInitialSession? {
        if case .edit(let session) = mode {
            return session
        }
        return nil
    }

    private func normalizedClockOutDate(selectedClockOutDate: Date, clockInDate: Date, workDay: Date) -> Date {
        let calendar = Calendar.current
        var normalized = WorkRecordEditorView.date(on: workDay, matchingTimeOf: selectedClockOutDate)
        if normalized <= clockInDate {
            normalized = calendar.date(byAdding: .day, value: 1, to: normalized) ?? normalized
        }
        return normalized
    }

    private func workClockSaveDates(for clockDate: Date) -> (start: Date, end: Date) {
        let end = CalendarEvent.defaultEndDate(for: clockDate, isAllDay: false)
        return (clockDate, end)
    }

    private func formatDateOnly(_ date: Date) -> String {
        LocalizationManager.shared.dateFormatter(dateFormat: "yyyy/MM/dd").string(from: date)
    }

    private static func initialValues(for mode: WorkRecordEditorMode) -> (title: String, workDate: Date, workInTime: Date, workOutTime: Date, restHours: Double, transportFee: Int?, hourlyRate: Int?, workSessionId: UUID) {
        switch mode {
        case .create(let initialDate):
            let workDate = Calendar.current.startOfDay(for: initialDate)
            let workInTime = makeDefaultWorkInDate(selectedDate: workDate)
            let workOutTime = Calendar.current.date(byAdding: .hour, value: 1, to: workInTime) ?? workInTime
            return (
                title: LocalizationManager.shared.localized(.workRecordDefaultTitle),
                workDate: workDate,
                workInTime: workInTime,
                workOutTime: workOutTime,
                restHours: 0.0,
                transportFee: nil,
                hourlyRate: nil,
                workSessionId: WorkInfo.makeNewWorkSessionId()
            )
        case .edit(let session):
            let workDate = Calendar.current.startOfDay(for: session.workDate)
            let fallbackInTime = session.workInTime ?? makeDefaultWorkInDate(selectedDate: workDate)
            let fallbackOutTime = session.workOutTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: fallbackInTime) ?? fallbackInTime
            return (
                title: session.title,
                workDate: workDate,
                workInTime: fallbackInTime,
                workOutTime: fallbackOutTime,
                restHours: session.restHours,
                transportFee: session.transportFee,
                hourlyRate: session.hourlyRate,
                workSessionId: session.workSessionId ?? WorkInfo.makeNewWorkSessionId()
            )
        }
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

private struct WorkRecordSummaryRowView: View {
    let session: WorkRecordDisplaySession
    let selectedDate: Date
    let onEdit: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayTitle(defaultTitle: LocalizationManager.shared.localized(.workRecordDefaultTitle)))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(EventEditorStyle.primaryText)
                    .lineLimit(1)

                Text(timeRangeText)
                    .font(.caption)
                    .foregroundColor(EventEditorStyle.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(EventEditorStyle.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        guard let clockOut = session.clockOut else {
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
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: selectedDate)
    }

    private func formatTime(_ date: Date) -> String {
        LocalizationManager.shared.dateFormatter(dateFormat: "HH:mm").string(from: date)
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

                Spacer()

                Button(saveTitle, action: onSave)
                    .buttonStyle(HeaderCapsuleButtonStyle(isEnabled: canSave && !saving))
                    .disabled(!canSave || saving)
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
                title: reminderTitle,
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

private struct EventTimeSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isAllDay: Bool
    let allDayTitle: String
    let startTitle: String
    let endTitle: String
    @Binding var showingStartDatePicker: Bool
    @Binding var showingStartTimePicker: Bool
    @Binding var showingEndDatePicker: Bool
    @Binding var showingEndTimePicker: Bool

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
                Text(startTitle)
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
                            .glassCapsuleStyle()
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
                            .glassCapsuleStyle()
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // 第三行：終了 + 日期/时间按钮
            HStack(alignment: .center, spacing: 8) {
                Text(endTitle)
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
                            .glassCapsuleStyle()
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
                            .glassCapsuleStyle()
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .padding(EventEditorStyle.cardPadding)
    }

    private func formatDateOnly(_ date: Date) -> String {
        LocalizationManager.shared.dateFormatter(dateFormat: "yyyy/MM/dd").string(from: date)
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
