import Foundation

struct DateOnly: Codable, Hashable, Comparable, Identifiable {
    let year: Int
    let month: Int
    let day: Int
    
    var id: String {
        "\(year)-\(month)-\(day)"
    }
    
    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
    
    init?(from date: Date, in timeZone: TimeZone = .current) {
        // 使用 Gregorian calendar 确保年份始终是西历（避免日本和历等导致年份错误）
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return nil
        }
        
        self.init(year: year, month: month, day: day)
    }
    
    func toDate(in timeZone: TimeZone = .current, at startOfDay: Bool = true) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        
        if startOfDay {
            components.hour = 0
            components.minute = 0
            components.second = 0
        }
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        return calendar.date(from: components) ?? Date()
    }
    
    static func < (lhs: DateOnly, rhs: DateOnly) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        if lhs.month != rhs.month {
            return lhs.month < rhs.month
        }
        return lhs.day < rhs.day
    }
    
    static func == (lhs: DateOnly, rhs: DateOnly) -> Bool {
        lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
    }
}
