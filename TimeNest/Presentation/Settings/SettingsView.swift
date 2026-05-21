import SwiftUI

struct SettingsView: View {
    @AppStorage("displayLanguage") private var displayLanguage: String = "system"
    @AppStorage("holidayRegion") private var holidayRegion: String = "japan"
    @AppStorage("weekStart") private var weekStart: String = "system"
    @AppStorage("themeMode") private var themeMode: String = "system"
    @AppStorage("notificationEnabled") private var notificationEnabled: Bool = true
    @AppStorage("showWeekNumbers") private var showWeekNumbers: Bool = false
    
    @State private var showVersionInfo: Bool = false
    
    var body: some View {
        Form {
            // MARK: - Language Section
            Section {
                Picker(LocalizedString.settingsLanguage.localized, selection: $displayLanguage) {
                    Text(LocalizedString.languageSystem.localized).tag("system")
                    Text(LocalizedString.languageSimplifiedChinese.localized).tag("zh_hans")
                    Text(LocalizedString.languageJapanese.localized).tag("ja")
                    Text(LocalizedString.languageKorean.localized).tag("ko")
                    Text(LocalizedString.languageEnglish.localized).tag("en_us")
                }
            } header: {
                Text(LocalizedString.settingsLanguage.localized)
            }
            
            // MARK: - Holiday Region Section
            Section {
                Picker(LocalizedString.settingsHolidayRegion.localized, selection: $holidayRegion) {
                    Text(LocalizedString.regionJapan.localized).tag("japan")
                    Text(LocalizedString.regionChina.localized).tag("china")
                    Text(LocalizedString.regionKorea.localized).tag("korea")
                    Text(LocalizedString.regionUnitedStates.localized).tag("united_states")
                }
            } header: {
                Text(LocalizedString.settingsHolidayRegion.localized)
            }
            
            // MARK: - Week Start Section
            Section {
                Picker(LocalizedString.settingsWeekStart.localized, selection: $weekStart) {
                    Text(LocalizedString.weekStartSystem.localized).tag("system")
                    Text(LocalizedString.weekStartSunday.localized).tag("sunday")
                    Text(LocalizedString.weekStartMonday.localized).tag("monday")
                }
            } header: {
                Text(LocalizedString.settingsWeekStart.localized)
            }
            
            // MARK: - Week Numbers Section
            Section {
                Toggle(LocalizedString.calendarShowWeekNumbers.localized, isOn: $showWeekNumbers)
            } header: {
                Text(LocalizedString.calendarSettings.localized)
            }
            
            // MARK: - Notification Section
            Section {
                Toggle(LocalizedString.notificationEnabled.localized, isOn: $notificationEnabled)
                
                // Placeholder for future notification time setting
                HStack {
                    Text(LocalizedString.notificationTime.localized)
                    Spacer()
                    Text(LocalizedString.notImplemented.localized)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .opacity(notificationEnabled ? 1.0 : 0.5)
                .disabled(!notificationEnabled)
            } header: {
                Text(LocalizedString.settingsNotification.localized)
            }
            
            // MARK: - Theme Section
            Section {
                Picker(LocalizedString.settingsTheme.localized, selection: $themeMode) {
                    Text(LocalizedString.themeLight.localized).tag("light")
                    Text(LocalizedString.themeDark.localized).tag("dark")
                    Text(LocalizedString.themeSystem.localized).tag("system")
                }
            } header: {
                Text(LocalizedString.settingsTheme.localized)
            }
            
            // MARK: - About Section
            Section {
                HStack {
                    Text(LocalizedString.aboutVersion.localized)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(LocalizedString.aboutDeveloper.localized)
                    Spacer()
                    Text("TimeNest Team")
                        .foregroundColor(.secondary)
                }
                
                // Placeholder links (not functional in preview)
                Link(destination: URL(string: "https://example.com/privacy")!) {
                    HStack {
                        Text(LocalizedString.aboutPrivacy.localized)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://example.com/terms")!) {
                    HStack {
                        Text(LocalizedString.aboutTerms.localized)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(LocalizedString.settingsAbout.localized)
            }
        }
        .navigationTitle(LocalizedString.settingsTitle.localized)
        .foregroundColor(.primary)
    }
}

// MARK: - Settings View Models

// DisplayLanguage is defined in Domain/Rules/DisplayLanguage.swift
// HolidayRegion is defined in Domain/Rules/HolidayRegion.swift
// WeekStartPolicy is defined in Domain/Rules/WeekStartPolicy.swift

// MARK: - Preview

#Preview {
    NavigationView {
        SettingsView()
    }
}
