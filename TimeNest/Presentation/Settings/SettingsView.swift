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
