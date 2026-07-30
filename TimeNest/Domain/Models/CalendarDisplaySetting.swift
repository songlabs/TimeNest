import Foundation

struct CalendarDisplaySetting: Codable, Hashable {
    var displayLanguage: DisplayLanguage
    var selectedHolidayRegions: [HolidayRegion]
    var weekStartPolicy: WeekStartPolicy
    var showLunarCalendar: Bool
    var showRokuyo: Bool
    var showSolarTerms: Bool

    init(
        displayLanguage: DisplayLanguage,
        selectedHolidayRegions: [HolidayRegion],
        weekStartPolicy: WeekStartPolicy,
        showLunarCalendar: Bool = false,
        showRokuyo: Bool = false,
        showSolarTerms: Bool = false
    ) {
        self.displayLanguage = displayLanguage
        self.selectedHolidayRegions = selectedHolidayRegions
        self.weekStartPolicy = weekStartPolicy
        self.showLunarCalendar = showLunarCalendar
        self.showRokuyo = showRokuyo
        self.showSolarTerms = showSolarTerms
    }
}
