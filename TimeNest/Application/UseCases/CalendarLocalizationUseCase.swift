import Foundation

class CalendarLocalizationUseCase {
    func monthTitle(year: Int, month: Int, language: DisplayLanguage) -> String {
        let months: [DisplayLanguage: [String]] = [
            .zhHans: ["1 月", "2 月", "3 月", "4 月", "5 月", "6 月", "7 月", "8 月", "9 月", "10 月", "11 月", "12 月"],
            .ja: ["1 月", "2 月", "3 月", "4 月", "5 月", "6 月", "7 月", "8 月", "9 月", "10 月", "11 月", "12 月"],
            .ko: ["1 월", "2 월", "3 월", "4 월", "5 월", "6 월", "7 월", "8 월", "9 월", "10 월", "11 월", "12 월"],
            .enUS: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        ]
        
        let monthArray = months[language] ?? months[.zhHans]!
        let title = monthArray[month - 1]
        
        switch language {
        case .system, .zhHans, .ja, .ko:
            return "\(year)年 \(title)"
        case .enUS:
            return "\(title) \(year)"
        }
    }
    
    func weekdaySymbols(language: DisplayLanguage, weekStartPolicy: WeekStartPolicy) -> [String] {
        let symbols: [DisplayLanguage: [String]] = [
            .zhHans: ["日", "一", "二", "三", "四", "五", "六"],
            .ja: ["日", "月", "火", "水", "木", "金", "土"],
            .ko: ["일", "월", "화", "수", "목", "금", "토"],
            .enUS: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        ]
        
        var symbolsArray = symbols[language] ?? symbols[.zhHans]!
        
        if weekStartPolicy == .monday {
            symbolsArray.append(symbolsArray.removeFirst())
        }
        
        return symbolsArray
    }
    
    func holidayName(_ holiday: Holiday, language: DisplayLanguage) -> String {
        holiday.localizedNames.localized(for: language)
    }
}
