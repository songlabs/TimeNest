import Foundation

actor BundleHolidayProvider: HolidayProviding {
    private let sampleHolidays: [Holiday] = [
        Holiday(
            id: "jp-newyear-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 1, day: 1),
            localizedNames: LocalizedText(zhHans: "元旦", ja: "元日", ko: "신정", enUS: "New Year's Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-matsuri-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 1, day: 12),
            localizedNames: LocalizedText(zhHans: "成人节", ja: "成人の日", ko: "성인의 날", enUS: "Coming of Age Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "cn-springfestival-2026",
            region: .china,
            date: DateOnly(year: 2026, month: 2, day: 17),
            localizedNames: LocalizedText(zhHans: "春节", ja: "春節", ko: "설날", enUS: "Spring Festival"),
            type: .traditional,
            isObserved: true
        ),
        Holiday(
            id: "kr-salnal-2026",
            region: .korea,
            date: DateOnly(year: 2026, month: 2, day: 17),
            localizedNames: LocalizedText(zhHans: "春节", ja: "春節", ko: "설날", enUS: "Lunar New Year"),
            type: .traditional,
            isObserved: true
        ),
        Holiday(
            id: "us-newyear-2026",
            region: .unitedStates,
            date: DateOnly(year: 2026, month: 1, day: 1),
            localizedNames: LocalizedText(zhHans: "元旦", ja: "元日", ko: "신정", enUS: "New Year's Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "us-martinluther-2026",
            region: .unitedStates,
            date: DateOnly(year: 2026, month: 1, day: 19),
            localizedNames: LocalizedText(zhHans: "马丁·路德·金纪念日", ja: "マーティン・ルーサー・キング・ジュニア記念日", ko: "마틴 루터 킹 기념일", enUS: "Martin Luther King Jr. Day"),
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
