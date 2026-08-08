import Foundation

enum MonthSecondaryDisplayMode: String, CaseIterable, Codable, Hashable, Identifiable {
    case none
    case weather
    case lunar
    case rokuyo
    case solarTerm

    static let storageKey = "calendar.monthSecondaryDisplayMode"

    var id: String { rawValue }

    static func resolved(defaults: UserDefaults = .standard) -> MonthSecondaryDisplayMode {
        if let storedValue = defaults.string(forKey: storageKey),
           let storedMode = MonthSecondaryDisplayMode(rawValue: storedValue) {
            return storedMode
        }

        let legacy = TraditionalCalendarPreferences(defaults: defaults)
        if legacy.showLunarCalendar { return .lunar }
        if legacy.showRokuyo { return .rokuyo }
        if legacy.showSolarTerms { return .solarTerm }
        return .none
    }

    @discardableResult
    static func migrateIfNeeded(defaults: UserDefaults = .standard) -> MonthSecondaryDisplayMode {
        let mode = resolved(defaults: defaults)
        if defaults.object(forKey: storageKey) == nil {
            defaults.set(mode.rawValue, forKey: storageKey)
        }
        return mode
    }

    static func save(_ mode: MonthSecondaryDisplayMode, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: storageKey)

        // Keep the previous keys as a one-version compatibility mirror.
        defaults.set(mode == .lunar, forKey: TraditionalCalendarPreferences.showLunarCalendarKey)
        defaults.set(mode == .rokuyo, forKey: TraditionalCalendarPreferences.showRokuyoKey)
        defaults.set(mode == .solarTerm, forKey: TraditionalCalendarPreferences.showSolarTermsKey)
    }

    var traditionalPreferences: TraditionalCalendarPreferences {
        TraditionalCalendarPreferences(
            showLunarCalendar: self == .lunar,
            showRokuyo: self == .rokuyo,
            showSolarTerms: self == .solarTerm
        )
    }
}
