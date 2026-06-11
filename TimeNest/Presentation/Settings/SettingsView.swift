import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @AppStorage("weekStart") private var weekStart: String = "system"
    @AppStorage("themeMode") private var themeMode: String = "system"
    @AppStorage("notificationEnabled") private var notificationEnabled: Bool = true

    @State private var showVersionInfo: Bool = false
    @StateObject private var subscriptionManager = HolidaySubscriptionManager.shared

    var body: some View {
        Form {
            // MARK: - Language Section
            Section {
                Picker(localization.localized(.settingsLanguage), selection: Binding(
                    get: { localization.selectedLanguageCode },
                    set: { localization.setLanguage(DisplayLanguage(rawValue: $0) ?? .system) }
                )) {
                    Text(localization.localized(.languageSystem)).tag("system")
                    Text(localization.localized(.languageSimplifiedChinese)).tag("zhHans")
                    Text(localization.localized(.languageJapanese)).tag("ja")
                    Text(localization.localized(.languageKorean)).tag("ko")
                    Text(localization.localized(.languageEnglish)).tag("enUS")
                }
            } header: {
                Text(localization.localized(.settingsLanguage))
            }

            // MARK: - Holiday Subscription Section
            Section {
                NavigationLink {
                    HolidaySubscriptionSettingsView()
                        .environmentObject(localization)
                } label: {
                    HStack {
                        Text(localization.localized(.settingsHolidayRegion))
                        Spacer()
                        Text(enabledSubscriptionsDisplayText)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(localization.localized(.settingsHolidayRegion))
            }

            // MARK: - Week Start Section
            Section {
                Picker(localization.localized(.settingsWeekStart), selection: $weekStart) {
                    Text(localization.localized(.weekStartSystem)).tag("system")
                    Text(localization.localized(.weekStartSunday)).tag("sunday")
                    Text(localization.localized(.weekStartMonday)).tag("monday")
                    Text(localization.localized(.weekStartSaturday)).tag("saturday")
                }
            } header: {
                Text(localization.localized(.settingsWeekStart))
            }

            // MARK: - Shift Time Section
            Section {
                NavigationLink {
                    ShiftTimeSettingsView()
                        .environmentObject(localization)
                } label: {
                    Text(localization.localized(.shiftTimeSettingsTitle))
                }
            } header: {
                Text(localization.localized(.shiftTimeSettingsTitle))
            }

            // MARK: - Notification Section
            Section {
                Toggle(localization.localized(.notificationEnabled), isOn: $notificationEnabled)

                // Placeholder for future notification time setting
                HStack {
                    Text(localization.localized(.notificationTime))
                    Spacer()
                    Text(localization.localized(.notImplemented))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .opacity(notificationEnabled ? 1.0 : 0.5)
                .disabled(!notificationEnabled)
            } header: {
                Text(localization.localized(.settingsNotification))
            }

            // MARK: - Theme Section
            Section {
                Picker(localization.localized(.settingsTheme), selection: $themeMode) {
                    Text(localization.localized(.themeLight)).tag("light")
                    Text(localization.localized(.themeDark)).tag("dark")
                    Text(localization.localized(.themeSystem)).tag("system")
                }
            } header: {
                Text(localization.localized(.settingsTheme))
            }

            // MARK: - About Section
            Section {
                HStack {
                    Text(localization.localized(.aboutVersion))
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(localization.localized(.aboutDeveloper))
                    Spacer()
                    Text(localization.localized(.aboutDeveloperName))
                        .foregroundColor(.secondary)
                }

            } header: {
                Text(localization.localized(.settingsAbout))
            }

            // MARK: - File Sharing Section
            Section {
                NavigationLink {
                    TimeNestFileSharingView()
                        .environmentObject(localization)
                } label: {
                    Text(localization.localized(.fileSharingTitle))
                }
            } header: {
                Text(localization.localized(.fileSharingTitle))
            }

            // MARK: - Shift Sharing Section
            Section {
                NavigationLink {
                    ShiftSharePlaceholderView()
                        .environmentObject(localization)
                } label: {
                    Text(localization.localized(.shiftShare))
                }
            } header: {
                Text(localization.localized(.shiftShare))
            }
        }
        .navigationTitle(localization.localized(.settingsTitle))
        .foregroundColor(.primary)
        .onAppear {
            // 执行启动时的自动同步检查
            Task {
                await subscriptionManager.performAutoSync()
            }
        }
    }

    private var enabledSubscriptionsDisplayText: String {
        let enabledRegions = subscriptionManager.enabledRegions
        if enabledRegions.isEmpty {
            return localization.localized(.holidaySubscriptionNone)
        }
        return enabledRegions
            .sorted { $0.localizedKey < $1.localizedKey }
            .map { localization.localized($0.localizedKey) }
            .joined(separator: ", ")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(LocalizationManager.preview(languageCode: "ja"))
    }
}
#endif

// MARK: - Shift Time Settings

enum ShiftTimeTemplateID: String, CaseIterable, Identifiable {
    case day
    case night

    var id: String { rawValue }

    var nameKey: LocalizedString {
        switch self {
        case .day:
            return .shiftDay
        case .night:
            return .shiftNight
        }
    }

    var defaultStartTime: String {
        switch self {
        case .day:
            return "08:30"
        case .night:
            return "17:00"
        }
    }

    var defaultEndTime: String {
        switch self {
        case .day:
            return "17:30"
        case .night:
            return "09:00"
        }
    }

    var startTimeKey: String {
        "shiftTime.\(rawValue).start"
    }

    var endTimeKey: String {
        "shiftTime.\(rawValue).end"
    }

    var enabledKey: String {
        "shiftTime.\(rawValue).enabled"
    }
}

struct ShiftTimeTemplate: Identifiable, Equatable {
    let id: ShiftTimeTemplateID
    let nameKey: LocalizedString
    let startTime: String
    let endTime: String
    var enabled: Bool

    var displayTime: String {
        "\(startTime)〜\(endTime)"
    }

    var startHourMinute: (hour: Int, minute: Int)? {
        Self.hourMinute(from: startTime)
    }

    var endHourMinute: (hour: Int, minute: Int)? {
        Self.hourMinute(from: endTime)
    }

    static func all(from defaults: UserDefaults = .standard) -> [ShiftTimeTemplate] {
        ShiftTimeTemplateID.allCases.map { id in
            ShiftTimeTemplate(
                id: id,
                nameKey: id.nameKey,
                startTime: defaults.string(forKey: id.startTimeKey) ?? id.defaultStartTime,
                endTime: defaults.string(forKey: id.endTimeKey) ?? id.defaultEndTime,
                enabled: defaults.object(forKey: id.enabledKey) as? Bool ?? true
            )
        }
    }

    static func enabled(from defaults: UserDefaults = .standard) -> [ShiftTimeTemplate] {
        all(from: defaults).filter(\.enabled)
    }

    static func normalizedTimeString(from date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    static func date(from timeString: String, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        let components = hourMinute(from: timeString) ?? (0, 0)
        return calendar.date(bySettingHour: components.hour, minute: components.minute, second: 0, of: Date()) ?? Date()
    }

    static func hourMinute(from timeString: String) -> (hour: Int, minute: Int)? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    static func == (lhs: ShiftTimeTemplate, rhs: ShiftTimeTemplate) -> Bool {
        lhs.id == rhs.id &&
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.enabled == rhs.enabled
    }
}

struct ShiftTimeSettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @State private var selectedShift: ShiftTimeTemplateID?
    @State private var shiftTemplates: [ShiftTimeTemplate] = []

    var body: some View {
        List {
            ForEach(shiftTemplates) { template in
                ShiftTimeSettingsRow(
                    template: template,
                    onToggle: toggleEnabled,
                    onTap: { selectedShift = template.id }
                )
            }
        }
        .navigationTitle(localization.localized(.shiftTimeSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedShift) { shiftID in
            ShiftTimeEditSheet(
                shiftID: shiftID,
                onSave: updateShiftTemplate
            )
            .environmentObject(localization)
        }
        .onAppear {
            loadShiftTemplates()
        }
        .onChange(of: shiftTemplates) { _, _ in
            saveShiftTemplates()
        }
    }

    private func loadShiftTemplates() {
        shiftTemplates = ShiftTimeTemplate.all()
    }

    private func toggleEnabled(_ template: ShiftTimeTemplate) {
        if let index = shiftTemplates.firstIndex(where: { $0.id == template.id }) {
            var updated = shiftTemplates[index]
            updated.enabled.toggle()
            shiftTemplates[index] = updated
        }
    }

    private func updateShiftTemplate(_ template: ShiftTimeTemplate) {
        if let index = shiftTemplates.firstIndex(where: { $0.id == template.id }) {
            shiftTemplates[index] = template
        }
    }

    private func saveShiftTemplates() {
        let defaults = UserDefaults.standard
        for template in shiftTemplates {
            defaults.set(template.startTime, forKey: template.id.startTimeKey)
            defaults.set(template.endTime, forKey: template.id.endTimeKey)
            defaults.set(template.enabled, forKey: template.id.enabledKey)
        }
    }
}

private struct ShiftTimeSettingsRow: View {
    let template: ShiftTimeTemplate
    let onToggle: (ShiftTimeTemplate) -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // ON/OFF Button
            Button {
                onToggle(template)
            } label: {
                Text(template.enabled ? "ON" : "OFF")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 28)
                    .background(template.enabled ? Color.blue : Color.gray)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Shift Name
            Text(LocalizedStringKey(template.nameKey.rawValue))
                .font(.body.weight(.medium))
                .foregroundColor(.primary)

            Spacer()

            // Time Range
            Text(template.displayTime)
                .font(.body)
                .foregroundColor(.secondary)
                .monospacedDigit()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

private struct ShiftTimeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager

    let shiftID: ShiftTimeTemplateID
    let onSave: (ShiftTimeTemplate) -> Void

    @State private var startTime: String
    @State private var endTime: String

    init(shiftID: ShiftTimeTemplateID, onSave: @escaping (ShiftTimeTemplate) -> Void) {
        self.shiftID = shiftID
        self.onSave = onSave
        let defaults = UserDefaults.standard
        _startTime = State(initialValue: defaults.string(forKey: shiftID.startTimeKey) ?? shiftID.defaultStartTime)
        _endTime = State(initialValue: defaults.string(forKey: shiftID.endTimeKey) ?? shiftID.defaultEndTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(localization.localized(.shiftTimeStartTime))
                                .font(.subheadline)
                            Spacer()
                            Text(startTime)
                                .font(.title3)
                                .monospacedDigit()
                                .foregroundColor(.primary)
                        }

                        DatePicker(
                            "",
                            selection: Binding(
                                get: { ShiftTimeTemplate.date(from: startTime) },
                                set: { startTime = ShiftTimeTemplate.normalizedTimeString(from: $0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }
                    .padding(.vertical, 8)

                    HStack {
                        Text(localization.localized(.shiftTimeEndTime))
                            .font(.subheadline)
                        Spacer()
                        Text(endTime)
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundColor(.primary)
                    }

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { ShiftTimeTemplate.date(from: endTime) },
                            set: { endTime = ShiftTimeTemplate.normalizedTimeString(from: $0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                } header: {
                    Text(localization.localized(shiftID.nameKey))
                } footer: {
                    Text(localization.localized(.shiftTimeEditFooter))
                }
            }
            .navigationTitle(localization.localized(.shiftTimeEditTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.cancel)) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.localized(.save)) {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        let template = ShiftTimeTemplate(
            id: shiftID,
            nameKey: shiftID.nameKey,
            startTime: startTime,
            endTime: endTime,
            enabled: true
        )
        onSave(template)
        dismiss()
    }
}
