import Foundation

struct CalendarDisplaySetting: Codable, Hashable {
    var displayLanguage: DisplayLanguage
    var selectedHolidayRegions: [HolidayRegion]
    var weekStartPolicy: WeekStartPolicy
    var showLunarCalendar: Bool
}
