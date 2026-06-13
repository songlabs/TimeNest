import Foundation

actor BundleHolidayProvider: HolidayProviding {
    private let sampleHolidays: [Holiday] = [
        // MARK: - Japan 2026
        Holiday(
            id: "jp-newyear-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 1, day: 1),
            localizedNames: LocalizedText(region: .japan, displayName: "元日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-matsuri-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 1, day: 12),
            localizedNames: LocalizedText(region: .japan, displayName: "成人の日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-builders-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 2, day: 3),
            localizedNames: LocalizedText(region: .japan, displayName: "建国記念の日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-emperor-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 2, day: 23),
            localizedNames: LocalizedText(region: .japan, displayName: "天皇誕生日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-spring-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 3, day: 20),
            localizedNames: LocalizedText(region: .japan, displayName: "春分日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-showa-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 4, day: 29),
            localizedNames: LocalizedText(region: .japan, displayName: "昭和の日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-constitution-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 5, day: 3),
            localizedNames: LocalizedText(region: .japan, displayName: "憲法記念日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-midori-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 5, day: 4),
            localizedNames: LocalizedText(region: .japan, displayName: "みどりの日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-children-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 5, day: 5),
            localizedNames: LocalizedText(region: .japan, displayName: "こどもの日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-substitute-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 5, day: 6),
            localizedNames: LocalizedText(region: .japan, displayName: "振替休日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-marine-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 7, day: 20),
            localizedNames: LocalizedText(region: .japan, displayName: "海の日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-mountain-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 8, day: 11),
            localizedNames: LocalizedText(region: .japan, displayName: "山の日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-respect-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 9, day: 21),
            localizedNames: LocalizedText(region: .japan, displayName: "敬老の日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-autumn-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 9, day: 23),
            localizedNames: LocalizedText(region: .japan, displayName: "秋分日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-culture-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 11, day: 3),
            localizedNames: LocalizedText(region: .japan, displayName: "文化の日"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-thanksgiving-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 11, day: 23),
            localizedNames: LocalizedText(region: .japan, displayName: "勤労感謝の日"),
            type: .publicHoliday,
            isObserved: true
        ),
        // MARK: - China 2026
        Holiday(
            id: "cn-springfestival-2026",
            region: .china,
            date: DateOnly(year: 2026, month: 2, day: 17),
            localizedNames: LocalizedText(region: .china, displayName: "春节"),
            type: .traditional,
            isObserved: true
        ),
        Holiday(
            id: "cn-dragonboat-2026",
            region: .china,
            date: DateOnly(year: 2026, month: 6, day: 19),
            localizedNames: LocalizedText(region: .china, displayName: "端午节"),
            type: .traditional,
            isObserved: true
        ),
        Holiday(
            id: "cn-dragonboat-holiday-2026",
            region: .china,
            date: DateOnly(year: 2026, month: 6, day: 20),
            localizedNames: LocalizedText(region: .china, displayName: "端午节"),
            type: .traditional,
            isObserved: true
        ),
        Holiday(
            id: "cn-dragonboat-holiday2-2026",
            region: .china,
            date: DateOnly(year: 2026, month: 6, day: 21),
            localizedNames: LocalizedText(region: .china, displayName: "端午节"),
            type: .traditional,
            isObserved: true
        ),
        // MARK: - Korea 2026
        Holiday(
            id: "kr-salnal-2026",
            region: .korea,
            date: DateOnly(year: 2026, month: 2, day: 17),
            localizedNames: LocalizedText(region: .korea, displayName: "설날"),
            type: .traditional,
            isObserved: true
        ),
        // MARK: - United States 2026
        Holiday(
            id: "us-newyear-2026",
            region: .unitedStates,
            date: DateOnly(year: 2026, month: 1, day: 1),
            localizedNames: LocalizedText(region: .unitedStates, displayName: "New Year's Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "us-martinluther-2026",
            region: .unitedStates,
            date: DateOnly(year: 2026, month: 1, day: 19),
            localizedNames: LocalizedText(region: .unitedStates, displayName: "Martin Luther King Jr. Day"),
            type: .publicHoliday,
            isObserved: true
        )
    ]
    
    func holidays(region: HolidayRegion, from: DateOnly, to: DateOnly) async throws -> [Holiday] {
        sampleHolidays.filter {
            $0.region == region && $0.date >= from && $0.date <= to
        }
    }
}
