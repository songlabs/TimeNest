import Foundation

class CalendarLocalizationUseCase {
    func monthTitle(year: Int, month: Int, language: DisplayLanguage) -> String {
        LocalizationManager.shared.monthTitle(year: year, month: month, language: language)
    }
    
    func weekdaySymbols(language: DisplayLanguage, weekStartPolicy: WeekStartPolicy) -> [String] {
        LocalizationManager.shared.shortWeekdaySymbols(language: language, weekStartPolicy: weekStartPolicy)
    }
    
    func holidayName(_ holiday: Holiday, language: DisplayLanguage) -> String {
        // 根据节假日所属地区选择对应语言名称，而不是根据当前 App 语言
        holiday.localizedNames.displayName(for: holiday.region)
    }
}
