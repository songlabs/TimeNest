import Foundation

class CalendarLocalizationUseCase {
    func monthTitle(year: Int, month: Int, language: DisplayLanguage) -> String {
        switch language {
        case .system, .zhHans, .ja:
            return "\(year)年\(month)月"
        case .ko:
            return "\(year)년 \(month)월"
        case .enUS:
            let months = [
                "January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November", "December"
            ]
            return "\(months[month - 1]) \(year)"
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
        
        switch weekStartPolicy {
        case .sunday:
            break
        case .monday:
            symbolsArray.append(symbolsArray.removeFirst())
        case .saturday:
            let last = symbolsArray.removeLast()
            symbolsArray.insert(last, at: 0)
        case .system:
            let firstWeekday = Calendar.current.firstWeekday
            if firstWeekday == 2 {
                symbolsArray.append(symbolsArray.removeFirst())
            } else if firstWeekday == 7 {
                let last = symbolsArray.removeLast()
                symbolsArray.insert(last, at: 0)
            }
        }

        return symbolsArray
    }
    
    func holidayName(_ holiday: Holiday, language: DisplayLanguage) -> String {
        // 根据节假日所属地区选择对应语言名称，而不是根据当前 App 语言
        holiday.localizedNames.displayName(for: holiday.region)
    }
}
