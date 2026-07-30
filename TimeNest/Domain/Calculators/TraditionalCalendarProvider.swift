import Foundation

struct TraditionalLunarDate: Equatable {
    let month: Int
    let day: Int
    let isLeapMonth: Bool
}

enum TraditionalRokuyo: Int, CaseIterable, Equatable {
    // Remainder of (lunar month + lunar day) % 6.
    case taian = 0
    case shakko = 1
    case sensho = 2
    case tomobiki = 3
    case senbu = 4
    case butsumetsu = 5
}

enum TraditionalSolarTerm: Int, CaseIterable, Equatable {
    case springCommences
    case rainWater
    case insectsAwaken
    case springEquinox
    case clearAndBright
    case grainRain
    case summerCommences
    case grainFull
    case grainInEar
    case summerSolstice
    case minorHeat
    case majorHeat
    case autumnCommences
    case endOfHeat
    case whiteDew
    case autumnEquinox
    case coldDew
    case frostDescent
    case winterCommences
    case minorSnow
    case majorSnow
    case winterSolstice
    case minorCold
    case majorCold

    fileprivate var targetLongitude: Double {
        switch self {
        case .springCommences: 315
        case .rainWater: 330
        case .insectsAwaken: 345
        case .springEquinox: 0
        case .clearAndBright: 15
        case .grainRain: 30
        case .summerCommences: 45
        case .grainFull: 60
        case .grainInEar: 75
        case .summerSolstice: 90
        case .minorHeat: 105
        case .majorHeat: 120
        case .autumnCommences: 135
        case .endOfHeat: 150
        case .whiteDew: 165
        case .autumnEquinox: 180
        case .coldDew: 195
        case .frostDescent: 210
        case .winterCommences: 225
        case .minorSnow: 240
        case .majorSnow: 255
        case .winterSolstice: 270
        case .minorCold: 285
        case .majorCold: 300
        }
    }

    fileprivate var seedMonthAndDay: (month: Int, day: Int) {
        switch self {
        case .minorCold: (1, 5)
        case .majorCold: (1, 20)
        case .springCommences: (2, 4)
        case .rainWater: (2, 19)
        case .insectsAwaken: (3, 5)
        case .springEquinox: (3, 20)
        case .clearAndBright: (4, 4)
        case .grainRain: (4, 20)
        case .summerCommences: (5, 5)
        case .grainFull: (5, 21)
        case .grainInEar: (6, 5)
        case .summerSolstice: (6, 21)
        case .minorHeat: (7, 7)
        case .majorHeat: (7, 23)
        case .autumnCommences: (8, 7)
        case .endOfHeat: (8, 23)
        case .whiteDew: (9, 7)
        case .autumnEquinox: (9, 23)
        case .coldDew: (10, 8)
        case .frostDescent: (10, 23)
        case .winterCommences: (11, 7)
        case .minorSnow: (11, 22)
        case .majorSnow: (12, 7)
        case .winterSolstice: (12, 22)
        }
    }
}

/// Produces compact, local-only traditional calendar text for month cells.
///
/// Lunar dates use Foundation's Chinese calendar. Rokuyo reuses that exact
/// lunar conversion and applies `(month + day) % 6`.
///
/// Solar terms are the instants at which apparent solar longitude reaches a
/// multiple of 15 degrees (the definition published by the National
/// Astronomical Observatory of Japan). The original implementation below uses
/// the low-order Meeus solar-position equations documented by NOAA and solves
/// each longitude crossing numerically. It is intentionally limited to
/// 1901...2099 and intended for local-date labels, not minute-precision
/// astronomical work. No third-party code or data table is embedded.
struct TraditionalCalendarProvider {
    static let solarTermSupportedYears = 1901...2099

    private static let meanSolarMotionDegreesPerDay = 0.98564736
    private static let secondsPerDay = 86_400.0

    private let localization: LocalizationManager

    init(localization: LocalizationManager = .shared) {
        self.localization = localization
    }

    func displays(
        for dates: [DateOnly],
        preferences: TraditionalCalendarPreferences,
        language: DisplayLanguage,
        timeZone: TimeZone
    ) -> [DateOnly: TraditionalCalendarDisplay] {
        guard preferences.isAnyDisplayEnabled else { return [:] }

        let lunarMonthNames = preferences.showLunarCalendar
            ? localizedItems(.traditionalCalendarLunarMonthNames, count: 12, language: language)
            : nil
        let lunarDayNames = preferences.showLunarCalendar
            ? localizedItems(.traditionalCalendarLunarDayNames, count: 30, language: language)
            : nil
        let leapPrefix = preferences.showLunarCalendar
            ? localization.localized(.traditionalCalendarLunarLeapPrefix, language: language)
            : nil
        let rokuyoNames = preferences.showRokuyo
            ? localizedItems(.traditionalCalendarRokuyoNames, count: 6, language: language)
            : nil
        let solarTermNames = preferences.showSolarTerms
            ? localizedItems(.traditionalCalendarSolarTermNames, count: 24, language: language)
            : nil

        let solarTermsByDate: [DateOnly: TraditionalSolarTerm]
        if preferences.showSolarTerms {
            let years = Set(dates.map(\.year))
            solarTermsByDate = solarTerms(for: years, timeZone: timeZone)
        } else {
            solarTermsByDate = [:]
        }

        let needsLunarConversion = preferences.showLunarCalendar || preferences.showRokuyo
        var results: [DateOnly: TraditionalCalendarDisplay] = [:]
        results.reserveCapacity(dates.count)

        for date in dates {
            // One conversion is shared by the lunar and Rokuyo branches.
            let lunar = needsLunarConversion ? lunarDate(for: date, timeZone: timeZone) : nil

            let lunarText: String?
            if preferences.showLunarCalendar,
               let lunar,
               let lunarMonthNames,
               let lunarDayNames,
               let leapPrefix {
                lunarText = formatLunar(
                    lunar,
                    monthNames: lunarMonthNames,
                    dayNames: lunarDayNames,
                    leapPrefix: leapPrefix
                )
            } else {
                lunarText = nil
            }

            let rokuyoText: String?
            if preferences.showRokuyo,
               let lunar,
               let rokuyoNames {
                let rokuyo = rokuyo(for: lunar)
                rokuyoText = rokuyoNames[rokuyo.rawValue]
            } else {
                rokuyoText = nil
            }

            let solarTermText: String?
            if preferences.showSolarTerms,
               let solarTerm = solarTermsByDate[date],
               let solarTermNames {
                solarTermText = solarTermNames[solarTerm.rawValue]
            } else {
                solarTermText = nil
            }

            let display = TraditionalCalendarDisplay(
                lunarText: lunarText,
                rokuyoText: rokuyoText,
                solarTermText: solarTermText
            )
            if !display.isEmpty {
                results[date] = display
            }
        }

        return results
    }

    func lunarDate(for date: DateOnly, timeZone: TimeZone) -> TraditionalLunarDate? {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone

        // Local noon avoids nonexistent/repeated local-midnight edge cases.
        var components = DateComponents()
        components.timeZone = timeZone
        components.year = date.year
        components.month = date.month
        components.day = date.day
        components.hour = 12

        guard let localNoon = gregorian.date(from: components) else {
            return nil
        }

        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = timeZone
        let lunar = chinese.dateComponents([.month, .day, .isLeapMonth], from: localNoon)

        guard let month = lunar.month,
              let day = lunar.day,
              (1...12).contains(month),
              (1...30).contains(day) else {
            return nil
        }

        return TraditionalLunarDate(
            month: month,
            day: day,
            isLeapMonth: lunar.isLeapMonth ?? false
        )
    }

    func rokuyo(for lunarDate: TraditionalLunarDate) -> TraditionalRokuyo {
        TraditionalRokuyo(rawValue: (lunarDate.month + lunarDate.day) % 6) ?? .taian
    }

    func solarTerm(on date: DateOnly, timeZone: TimeZone) -> TraditionalSolarTerm? {
        guard Self.solarTermSupportedYears.contains(date.year) else {
            return nil
        }
        return solarTerms(for: [date.year], timeZone: timeZone)[date]
    }

    func solarTermInstant(_ term: TraditionalSolarTerm, year: Int) -> Date? {
        guard Self.solarTermSupportedYears.contains(year) else {
            return nil
        }

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let seed = term.seedMonthAndDay
        guard var estimate = utcCalendar.date(
            from: DateComponents(
                timeZone: utcCalendar.timeZone,
                year: year,
                month: seed.month,
                day: seed.day,
                hour: 12
            )
        ) else {
            return nil
        }

        // Solar longitude is monotonic across the short seed window. Newton
        // iteration with the mean daily motion converges well within a second.
        for _ in 0..<10 {
            let currentLongitude = apparentSolarLongitude(at: estimate)
            let correction = signedDegrees(term.targetLongitude - currentLongitude)
                / Self.meanSolarMotionDegreesPerDay
            estimate = estimate.addingTimeInterval(correction * Self.secondsPerDay)
        }

        return estimate
    }

    private func solarTerms(
        for years: Set<Int>,
        timeZone: TimeZone
    ) -> [DateOnly: TraditionalSolarTerm] {
        var result: [DateOnly: TraditionalSolarTerm] = [:]

        for year in years.sorted() where Self.solarTermSupportedYears.contains(year) {
            for term in TraditionalSolarTerm.allCases {
                guard let instant = solarTermInstant(term, year: year),
                      let localDate = DateOnly(from: instant, in: timeZone) else {
                    continue
                }
                result[localDate] = term
            }
        }

        return result
    }

    private func formatLunar(
        _ lunar: TraditionalLunarDate,
        monthNames: [String],
        dayNames: [String],
        leapPrefix: String
    ) -> String {
        let base = lunar.day == 1
            ? monthNames[lunar.month - 1]
            : dayNames[lunar.day - 1]
        return lunar.isLeapMonth ? leapPrefix + base : base
    }

    private func localizedItems(
        _ key: LocalizedString,
        count: Int,
        language: DisplayLanguage
    ) -> [String]? {
        let items = localization
            .localized(key, language: language)
            .split(separator: "|", omittingEmptySubsequences: false)
            .map(String.init)
        return items.count == count ? items : nil
    }

    private func apparentSolarLongitude(at date: Date) -> Double {
        let julianDay = date.timeIntervalSince1970 / Self.secondsPerDay + 2_440_587.5
        let centuries = (julianDay - 2_451_545.0) / 36_525.0

        let meanLongitude = normalizedDegrees(
            280.46646
                + centuries * (36_000.76983 + centuries * 0.0003032)
        )
        let meanAnomaly = degreesToRadians(
            normalizedDegrees(
                357.52911
                    + centuries * (35_999.05029 - 0.0001537 * centuries)
            )
        )
        let equationOfCenter =
            sin(meanAnomaly) * (1.914602 - centuries * (0.004817 + 0.000014 * centuries))
            + sin(2 * meanAnomaly) * (0.019993 - 0.000101 * centuries)
            + sin(3 * meanAnomaly) * 0.000289
        let omega = degreesToRadians(125.04 - 1_934.136 * centuries)

        return normalizedDegrees(
            meanLongitude + equationOfCenter - 0.00569 - 0.00478 * sin(omega)
        )
    }

    private func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private func normalizedDegrees(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }

    private func signedDegrees(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value <= -180 {
            value += 360
        } else if value > 180 {
            value -= 360
        }
        return value
    }
}
