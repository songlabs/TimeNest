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

    var isEnabledKey: String {
        "shiftTime.\(rawValue).isEnabled"
    }
}

struct ShiftTimeTemplate: Identifiable {
    let id: ShiftTimeTemplateID
    let nameKey: LocalizedString
    let startTime: String
    let endTime: String
    let isEnabled: Bool

    var displayTime: String {
        "\(startTime)～\(endTime)"
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
                isEnabled: defaults.object(forKey: id.isEnabledKey) as? Bool ?? true
            )
        }
    }

    static func enabled(from defaults: UserDefaults = .standard) -> [ShiftTimeTemplate] {
        all(from: defaults).filter(\.isEnabled)
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
}

struct ShiftTimeSettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        Form {
            ForEach(ShiftTimeTemplateID.allCases) { shiftID in
                Section {
                    ShiftTimeTemplateSettingsRow(shiftID: shiftID)
                } header: {
                    Text(localization.localized(shiftID.nameKey))
                }
            }
        }
        .navigationTitle(localization.localized(.shiftTimeSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShiftTimeTemplateSettingsRow: View {
    @EnvironmentObject private var localization: LocalizationManager
    let shiftID: ShiftTimeTemplateID

    @AppStorage private var startTime: String
    @AppStorage private var endTime: String

    init(shiftID: ShiftTimeTemplateID) {
        self.shiftID = shiftID
        _startTime = AppStorage(wrappedValue: shiftID.defaultStartTime, shiftID.startTimeKey)
        _endTime = AppStorage(wrappedValue: shiftID.defaultEndTime, shiftID.endTimeKey)
    }

    var body: some View {
        DatePicker(
            localization.localized(startTimeLabelKey),
            selection: timeBinding(for: $startTime),
            displayedComponents: .hourAndMinute
        )

        DatePicker(
            localization.localized(endTimeLabelKey),
            selection: timeBinding(for: $endTime),
            displayedComponents: .hourAndMinute
        )
    }

    private var startTimeLabelKey: LocalizedString {
        switch shiftID {
        case .day:
            return .shiftDayStart
        case .night:
            return .shiftNightStart
        }
    }

    private var endTimeLabelKey: LocalizedString {
        switch shiftID {
        case .day:
            return .shiftDayEnd
        case .night:
            return .shiftNightEnd
        }
    }

    private func timeBinding(for value: Binding<String>) -> Binding<Date> {
        Binding(
            get: { ShiftTimeTemplate.date(from: value.wrappedValue) },
            set: { value.wrappedValue = ShiftTimeTemplate.normalizedTimeString(from: $0) }
        )
    }
}
