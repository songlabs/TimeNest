import Foundation

struct TraditionalCalendarPreferences: Equatable {
    static let showLunarCalendarKey = "traditionalCalendar.showLunarCalendar"
    static let showRokuyoKey = "traditionalCalendar.showRokuyo"
    static let showSolarTermsKey = "traditionalCalendar.showSolarTerms"

    let showLunarCalendar: Bool
    let showRokuyo: Bool
    let showSolarTerms: Bool

    init(
        showLunarCalendar: Bool,
        showRokuyo: Bool,
        showSolarTerms: Bool
    ) {
        self.showLunarCalendar = showLunarCalendar
        self.showRokuyo = showRokuyo
        self.showSolarTerms = showSolarTerms
    }

    init(defaults: UserDefaults = .standard) {
        // object(forKey:) keeps a missing or invalid legacy value opt-in safe.
        showLunarCalendar = defaults.object(forKey: Self.showLunarCalendarKey) as? Bool ?? false
        showRokuyo = defaults.object(forKey: Self.showRokuyoKey) as? Bool ?? false
        showSolarTerms = defaults.object(forKey: Self.showSolarTermsKey) as? Bool ?? false
    }

    var isAnyDisplayEnabled: Bool {
        showLunarCalendar || showRokuyo || showSolarTerms
    }
}
