import Foundation

struct CalendarDisplaySetting: Codable, Hashable {
    var displayLanguage: DisplayLanguage
    var primaryHolidayRegion: HolidayRegion
    var additionalHolidayRegions: [HolidayRegion]
    var weekStartPolicy: WeekStartPolicy
    var showLunarCalendar: Bool
}
