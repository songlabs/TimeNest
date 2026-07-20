import SwiftUI

@MainActor
final class ShiftBatchViewModel: ObservableObject {
    enum ModeChoice: String, CaseIterable, Identifiable {
        case template
        case previousDay
        case previousWeek
        case rotation

        var id: String { rawValue }
    }

    @Published var selectedDates: Set<Date>
    @Published var visibleMonth: Date
    @Published var modeChoice: ModeChoice = .template
    @Published var selectedTemplateID: ShiftTimeTemplateID?
    @Published var rotationStartDate: Date
    @Published var rotationEndDate: Date
    @Published var rotationItems: [ShiftRotationItem]
    @Published var rotationStartOffset = 0
    @Published private(set) var plan: ShiftBatchOperationPlan?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    let templates: [ShiftTimeTemplate]
    let favoriteIDs: Set<String>

    private let useCase: ShiftBatchOperationUseCase
    private let calendarID: UUID
    private let calendar: Calendar

    init(
        useCase: ShiftBatchOperationUseCase,
        calendarID: UUID,
        initialDate: Date,
        defaults: UserDefaults = .standard
    ) {
        self.useCase = useCase
        self.calendarID = calendarID
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = Self.firstWeekday(defaults: defaults)
        self.calendar = calendar

        let templates = ShiftTimeTemplate.enabled(from: defaults)
        self.templates = templates
        let favoriteIDs = ShiftTemplateFavoritesStore(defaults: defaults).reconcile(
            validTemplateIDs: templates.map(\.id)
        )
        self.favoriteIDs = Set(favoriteIDs)
        selectedTemplateID = templates.first?.id

        let day = calendar.startOfDay(for: initialDate)
        selectedDates = [day]
        visibleMonth = day
        rotationStartDate = day
        rotationEndDate = calendar.date(byAdding: .day, value: 6, to: day) ?? day
        if let first = templates.first {
            rotationItems = [
                ShiftRotationItem(selection: .template(first.id)),
                ShiftRotationItem(selection: .restDay)
            ]
        } else {
            rotationItems = [ShiftRotationItem(selection: .restDay)]
        }
    }

    var effectiveDates: [Date] {
        if modeChoice == .rotation {
            return datesInRotationRange()
        }
        return selectedDates.sorted()
    }

    var favoriteTemplates: [ShiftTimeTemplate] {
        templates.filter { favoriteIDs.contains($0.id.id) }
    }

    var otherTemplates: [ShiftTimeTemplate] {
        templates.filter { !favoriteIDs.contains($0.id.id) }
    }

    func toggleDate(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        if selectedDates.contains(day) {
            selectedDates.remove(day)
        } else {
            selectedDates.insert(day)
        }
        invalidatePlan()
    }

    func clearSelection() {
        selectedDates.removeAll()
        invalidatePlan()
    }

    func moveMonth(by value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }

    func invalidatePlan() {
        plan = nil
        errorMessage = nil
    }

    func addRotationItem() {
        let selection = selectedTemplateID.map(ShiftRotationItem.Selection.template) ?? .restDay
        rotationItems.append(ShiftRotationItem(selection: selection))
        normalizeRotationOffset()
        invalidatePlan()
    }

    func removeRotationItem(id: UUID) {
        guard rotationItems.count > 1 else { return }
        rotationItems.removeAll { $0.id == id }
        normalizeRotationOffset()
        invalidatePlan()
    }

    func setRotationSelection(_ selection: ShiftRotationItem.Selection, id: UUID) {
        guard let index = rotationItems.firstIndex(where: { $0.id == id }) else { return }
        rotationItems[index].selection = selection
        invalidatePlan()
    }

    func preview() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let request = ShiftBatchRequest(
                dates: effectiveDates,
                mode: batchMode,
                calendarID: calendarID,
                templates: templates.map(\.batchSnapshot)
            )
            let newPlan = try await useCase.makePlan(for: request)
            plan = newPlan
            if newPlan.issues.contains(.emptySelection) {
                errorMessage = LocalizationManager.shared.localized(.shiftBatchEmptySelection)
            } else if newPlan.issues.contains(.invalidTemplate) || newPlan.issues.contains(.emptyRotation) {
                errorMessage = LocalizationManager.shared.localized(.shiftBatchInvalidTemplate)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func execute() async throws -> ShiftBatchOperationResult {
        guard let plan else { throw ShiftBatchOperationError.invalidPlan }
        isWorking = true
        defer { isWorking = false }
        return try await useCase.execute(
            plan: plan,
            currentTemplates: ShiftTimeTemplate.enabled().map(\.batchSnapshot)
        )
    }

    func localizedModeTitle(_ mode: ModeChoice) -> String {
        let localization = LocalizationManager.shared
        switch mode {
        case .template:
            return localization.localized(.shiftBatchUseTemplate)
        case .previousDay:
            return localization.localized(.shiftBatchCopyPreviousDay)
        case .previousWeek:
            return localization.localized(.shiftBatchCopyPreviousWeek)
        case .rotation:
            return localization.localized(.shiftBatchRotation)
        }
    }

    private var batchMode: ShiftBatchMode {
        switch modeChoice {
        case .template:
            return .template(selectedTemplateID ?? .day)
        case .previousDay:
            return .copyPreviousDay
        case .previousWeek:
            return .copyPreviousWeek
        case .rotation:
            return .rotation(items: rotationItems, startOffset: rotationStartOffset)
        }
    }

    private func datesInRotationRange() -> [Date] {
        let start = calendar.startOfDay(for: rotationStartDate)
        let end = calendar.startOfDay(for: rotationEndDate)
        guard start <= end else { return [] }
        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current), next > current else {
                break
            }
            current = next
        }
        return dates
    }

    private func normalizeRotationOffset() {
        rotationStartOffset = min(rotationStartOffset, max(0, rotationItems.count - 1))
    }

    private static func firstWeekday(defaults: UserDefaults) -> Int {
        let policy = WeekStartPolicy(
            rawValue: defaults.string(forKey: "weekStart") ?? "system"
        ) ?? .system
        switch policy {
        case .sunday: return 1
        case .monday: return 2
        case .saturday: return 7
        case .system: return Calendar.current.firstWeekday
        }
    }
}

struct ShiftBatchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var viewModel: ShiftBatchViewModel

    private let onCompleted: (ShiftBatchOperationResult) -> Void
    private let calendar: Calendar

    init(
        useCase: ShiftBatchOperationUseCase,
        calendarID: UUID,
        initialDate: Date,
        onCompleted: @escaping (ShiftBatchOperationResult) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: ShiftBatchViewModel(
                useCase: useCase,
                calendarID: calendarID,
                initialDate: initialDate
            )
        )
        self.onCompleted = onCompleted
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let policy = WeekStartPolicy(
            rawValue: UserDefaults.standard.string(forKey: "weekStart") ?? "system"
        ) ?? .system
        switch policy {
        case .sunday: calendar.firstWeekday = 1
        case .monday: calendar.firstWeekday = 2
        case .saturday: calendar.firstWeekday = 7
        case .system: calendar.firstWeekday = Calendar.current.firstWeekday
        }
        self.calendar = calendar
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        selectedCountHeader
                        modeSection
                        if viewModel.modeChoice == .rotation {
                            rotationSection
                        } else {
                            dateSelector
                            if viewModel.modeChoice == .template {
                                templateSection
                            }
                        }
                        if let plan = viewModel.plan {
                            previewSection(plan)
                        }
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("shiftBatch.error")
                        }
                    }
                    .padding()
                }

                Divider()
                actionBar
                    .padding()
                    .background(Color(uiColor: .systemBackground))
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localization.localized(.shiftBatchTitle))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(viewModel.isWorking)
            .onChange(of: viewModel.modeChoice) { _, _ in viewModel.invalidatePlan() }
            .onChange(of: viewModel.selectedTemplateID) { _, _ in viewModel.invalidatePlan() }
            .onChange(of: viewModel.rotationStartDate) { _, _ in viewModel.invalidatePlan() }
            .onChange(of: viewModel.rotationEndDate) { _, _ in viewModel.invalidatePlan() }
            .onChange(of: viewModel.rotationStartOffset) { _, _ in viewModel.invalidatePlan() }
        }
    }

    private var selectedCountHeader: some View {
        HStack {
            Text(String(
                format: localization.localized(.shiftBatchSelectedCount),
                viewModel.effectiveDates.count
            ))
            .font(.headline)
            .accessibilityIdentifier("shiftBatch.selectedCount")

            Spacer()

            if viewModel.modeChoice != .rotation {
                Button(localization.localized(.shiftBatchClearSelection)) {
                    viewModel.clearSelection()
                }
                .disabled(viewModel.selectedDates.isEmpty)
            }
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.localized(.shiftBatchMode))
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("shiftBatch.mode")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ShiftBatchViewModel.ModeChoice.allCases) { mode in
                    Button {
                        viewModel.modeChoice = mode
                    } label: {
                        Text(viewModel.localizedModeTitle(mode))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(viewModel.modeChoice == mode ? Color.black : Color.primary)
                            .background(
                                viewModel.modeChoice == mode
                                    ? ShiftCalendarColors.accentYellow
                                    : Color(uiColor: .secondarySystemGroupedBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(modeAccessibilityIdentifier(mode))
                    .accessibilityAddTraits(viewModel.modeChoice == mode ? .isSelected : [])
                }
            }
        }
    }

    private var dateSelector: some View {
        VStack(spacing: 10) {
            HStack {
                Button { viewModel.moveMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(localization.localized(.shiftBatchPreviousMonth))

                Spacer()
                Text(monthTitle(viewModel.visibleMonth))
                    .font(.headline)
                    .accessibilityIdentifier("shiftBatch.dateSelector")
                Spacer()

                Button { viewModel.moveMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(localization.localized(.shiftBatchNextMonth))
            }

            let symbols = localization.shortWeekdaySymbols(
                weekStartPolicy: weekStartPolicy
            )
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(monthGridDates, id: \.self) { date in
                    let isSelected = viewModel.selectedDates.contains(calendar.startOfDay(for: date))
                    Button {
                        viewModel.toggleDate(date)
                    } label: {
                        Text(String(calendar.component(.day, from: date)))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(isSelected ? Color.black : Color.primary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(isSelected ? ShiftCalendarColors.accentYellow : Color.clear)
                            .clipShape(Circle())
                            .opacity(calendar.isDate(date, equalTo: viewModel.visibleMonth, toGranularity: .month) ? 1 : 0.42)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("shiftBatch.date.\(dateIdentifier(date))")
                    .accessibilityLabel(dayAccessibilityLabel(date))
                    .accessibilityHint(
                        isSelected ? localization.localized(.shiftBatchRemoveDate) : ""
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !viewModel.favoriteTemplates.isEmpty {
                Text(localization.localized(.shiftTemplateFavorites))
                    .font(.headline)
                    .accessibilityIdentifier("shiftTemplate.favoriteSection")
                templateButtons(viewModel.favoriteTemplates)
            }

            if !viewModel.otherTemplates.isEmpty {
                Text(localization.localized(.shiftBatchUseTemplate))
                    .font(.headline)
                    .accessibilityIdentifier("shiftBatch.template")
                templateButtons(viewModel.otherTemplates)
            }
        }
    }

    private func templateButtons(_ templates: [ShiftTimeTemplate]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
            ForEach(templates) { template in
                Button {
                    viewModel.selectedTemplateID = template.id
                } label: {
                    HStack {
                        Circle().fill(template.color).frame(width: 10, height: 10)
                        Text(template.displayName)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if viewModel.selectedTemplateID == template.id {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                viewModel.selectedTemplateID == template.id
                                    ? ShiftCalendarColors.primaryBlue
                                    : Color.clear,
                                lineWidth: 2
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shiftBatch.templateOption")
                .accessibilityValue(template.displayName)
            }
        }
    }

    private var rotationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker(
                localization.localized(.shiftBatchStartDate),
                selection: $viewModel.rotationStartDate,
                displayedComponents: .date
            )
            DatePicker(
                localization.localized(.shiftBatchEndDate),
                selection: $viewModel.rotationEndDate,
                displayedComponents: .date
            )

            ForEach(Array(viewModel.rotationItems.enumerated()), id: \.element.id) { index, item in
                HStack {
                    Text("\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .frame(width: 24)
                    Menu {
                        Button(localization.localized(.shiftBatchRestDay)) {
                            viewModel.setRotationSelection(.restDay, id: item.id)
                        }
                        ForEach(viewModel.templates) { template in
                            Button(template.displayName) {
                                viewModel.setRotationSelection(.template(template.id), id: item.id)
                            }
                        }
                    } label: {
                        HStack {
                            Text(rotationSelectionTitle(item.selection))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if viewModel.rotationItems.count > 1 {
                        Button(role: .destructive) {
                            viewModel.removeRotationItem(id: item.id)
                        } label: {
                            Image(systemName: "minus.circle")
                                .frame(width: 36, height: 36)
                        }
                    }
                }
            }

            Button {
                viewModel.addRotationItem()
            } label: {
                Label(localization.localized(.shiftBatchAddRotationItem), systemImage: "plus.circle")
            }

            if !viewModel.rotationItems.isEmpty {
                Stepper(
                    value: $viewModel.rotationStartOffset,
                    in: 0...max(0, viewModel.rotationItems.count - 1)
                ) {
                    Text("\(localization.localized(.shiftBatchRotationStart)): \(viewModel.rotationStartOffset + 1)")
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("shiftBatch.rotation")
    }

    private func previewSection(_ plan: ShiftBatchOperationPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.localized(.shiftBatchPreview))
                .font(.title3.bold())
            HStack {
                summaryValue(localization.localized(.shiftBatchWillCreate), plan.createCount)
                summaryValue(localization.localized(.shiftBatchRestDay), plan.restDayCount)
                summaryValue(localization.localized(.shiftBatchExistingShift), plan.conflictCount)
                summaryValue(localization.localized(.shiftBatchNoSource), plan.noSourceCount)
            }

            ForEach(plan.items) { item in
                HStack(alignment: .firstTextBaseline) {
                    Text(shortDate(item.targetDate))
                        .font(.subheadline.monospacedDigit())
                    if let displayName = item.displayName {
                        Text(displayName)
                            .font(.subheadline)
                            .lineLimit(1)
                    } else if item.isRestDay {
                        Text(localization.localized(.shiftBatchRestDay))
                            .font(.subheadline)
                    }
                    Spacer()
                    Label(statusTitle(item.status), systemImage: statusIcon(item.status))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor(item.status))
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("shiftBatch.preview")
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(localization.localized(.cancel)) {
                dismiss()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("shiftBatch.cancel")

            Button {
                Task { await viewModel.preview() }
            } label: {
                if viewModel.isWorking && viewModel.plan == nil {
                    ProgressView()
                } else {
                    Text(localization.localized(.shiftBatchPreview))
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("shiftBatch.previewButton")

            if let plan = viewModel.plan {
                Button {
                    Task { await confirm(plan: plan) }
                } label: {
                    if viewModel.isWorking {
                        ProgressView()
                    } else {
                        Text(localization.localized(.shiftBatchConfirm))
                    }
                }
                .buttonStyle(.plain)
                .font(.body.weight(.bold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(ShiftCalendarColors.accentYellow)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(!plan.canExecute || viewModel.isWorking)
                .opacity(plan.canExecute ? 1 : 0.45)
                .accessibilityIdentifier("shiftBatch.confirm")
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func confirm(plan: ShiftBatchOperationPlan) async {
        guard plan.canExecute else { return }
        do {
            let result = try await viewModel.execute()
            onCompleted(result)
            dismiss()
        } catch ShiftBatchOperationError.stalePlan {
            viewModel.errorMessage = localization.localized(.shiftBatchPlanChanged)
            viewModel.invalidatePlan()
            viewModel.errorMessage = localization.localized(.shiftBatchPlanChanged)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private var monthGridDates: [Date] {
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: viewModel.visibleMonth)
        ) ?? viewModel.visibleMonth
        let weekday = calendar.component(.weekday, from: monthStart)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -offset, to: monthStart) ?? monthStart
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private var weekStartPolicy: WeekStartPolicy {
        WeekStartPolicy(
            rawValue: UserDefaults.standard.string(forKey: "weekStart") ?? "system"
        ) ?? .system
    }

    private func modeAccessibilityIdentifier(_ mode: ShiftBatchViewModel.ModeChoice) -> String {
        switch mode {
        case .template: return "shiftBatch.template"
        case .previousDay: return "shiftBatch.copyPreviousDay"
        case .previousWeek: return "shiftBatch.copyPreviousWeek"
        case .rotation: return "shiftBatch.rotation"
        }
    }

    private func rotationSelectionTitle(_ selection: ShiftRotationItem.Selection) -> String {
        switch selection {
        case .restDay:
            return localization.localized(.shiftBatchRestDay)
        case .template(let id):
            return viewModel.templates.first(where: { $0.id == id })?.displayName
                ?? localization.localized(.shiftBatchInvalidTemplate)
        }
    }

    private func statusTitle(_ status: ShiftBatchItemStatus) -> String {
        switch status {
        case .create: return localization.localized(.shiftBatchWillCreate)
        case .restDay: return localization.localized(.shiftBatchRestDay)
        case .noSource: return localization.localized(.shiftBatchNoSource)
        case .conflict: return localization.localized(.shiftBatchExistingShift)
        case .invalidTemplate: return localization.localized(.shiftBatchInvalidTemplate)
        }
    }

    private func statusIcon(_ status: ShiftBatchItemStatus) -> String {
        switch status {
        case .create: return "plus.circle.fill"
        case .restDay: return "moon.zzz"
        case .noSource: return "questionmark.circle"
        case .conflict: return "exclamationmark.triangle.fill"
        case .invalidTemplate: return "xmark.octagon.fill"
        }
    }

    private func statusColor(_ status: ShiftBatchItemStatus) -> Color {
        switch status {
        case .create: return .green
        case .restDay: return .secondary
        case .noSource: return .secondary
        case .conflict: return .orange
        case .invalidTemplate: return .red
        }
    }

    private func summaryValue(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.headline.monospacedDigit())
            Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = localization.currentLocale
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return formatter.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = localization.currentLocale
        formatter.setLocalizedDateFormatFromTemplate("MMMdE")
        return formatter.string(from: date)
    }

    private func dayAccessibilityLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = localization.currentLocale
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private func dateIdentifier(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
