import Foundation

actor BundleHolidayProvider: HolidayProviding {
    private let sampleHolidays: [Holiday] = [
        // MARK: - Japan 2026
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
            localizedNames: LocalizedText(zhHans: "成人节", ja: "成人の日", ko: "성인의 날", enUS: "Coming-of-Age Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-builders-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 2, day: 3),
            localizedNames: LocalizedText(zhHans: "建国纪念日", ja: "建国記念の日", ko: "건국기념일", enUS: "National Foundation Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-emperor-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 2, day: 23),
            localizedNames: LocalizedText(zhHans: "天皇诞生日", ja: "天皇誕生日", ko: "천황 생일", enUS: "Emperor's Birthday"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-spring-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 3, day: 20),
            localizedNames: LocalizedText(zhHans: "春分日", ja: "春分日", ko: "춘분", enUS: "Vernal Equinox Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-showa-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 4, day: 29),
            localizedNames: LocalizedText(zhHans: "昭和之日", ja: "昭和の日", ko: "쇼와의 날", enUS: "Showa Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-constitution-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 5, day: 3),
            localizedNames: LocalizedText(zhHans: "宪法纪念日", ja: "憲法記念日", ko: "헌법기념일", enUS: "Constitution Memorial Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-midori-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 5, day: 4),
            localizedNames: LocalizedText(zhHans: "绿色之日", ja: "みどりの日", ko: "녹색의 날", enUS: "Greenery Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-children-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 5, day: 5),
            localizedNames: LocalizedText(zhHans: "儿童之日", ja: "こどもの日", ko: "어린이 날", enUS: "Children's Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-substitute-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 5, day: 6),
            localizedNames: LocalizedText(zhHans: "补休日", ja: "振替休日", ko: "대체공휴일", enUS: "Substitute Holiday"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-marine-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 7, day: 20),
            localizedNames: LocalizedText(zhHans: "海之日", ja: "海の日", ko: "해의 날", enUS: "Marine Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-mountain-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 8, day: 11),
            localizedNames: LocalizedText(zhHans: "山之日", ja: "山の日", ko: "산의 날", enUS: "Mountain Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-respect-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 9, day: 21),
            localizedNames: LocalizedText(zhHans: "敬老日", ja: "敬老の日", ko: "경로의 날", enUS: "Respect for the Aged Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-autumn-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 9, day: 23),
            localizedNames: LocalizedText(zhHans: "秋分日", ja: "秋分日", ko: "추분", enUS: "Autumnal Equinox Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-culture-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 11, day: 3),
            localizedNames: LocalizedText(zhHans: "文化之日", ja: "文化の日", ko: "문화의 날", enUS: "Culture Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        Holiday(
            id: "jp-thanksgiving-2026",
            region: .japan,
            date: DateOnly(year: 2026, month: 11, day: 23),
            localizedNames: LocalizedText(zhHans: "勤劳感谢之日", ja: "勤労感謝の日", ko: "노동 감사의 날", enUS: "Labor Thanksgiving Day"),
            type: .publicHoliday,
            isObserved: true
        ),
        // MARK: - China 2026
        Holiday(
            id: "cn-springfestival-2026",
            region: .china,
            date: DateOnly(year: 2026, month: 2, day: 17),
            localizedNames: LocalizedText(zhHans: "春节", ja: "春節", ko: "설날", enUS: "Spring Festival"),
            type: .traditional,
            isObserved: true
        ),
        Holiday(
            id: "cn-dragonboat-2026",
            region: .china,
            date: DateOnly(year: 2026, month: 6, day: 19),
            localizedNames: LocalizedText(zhHans: "端午节", ja: "端午の節句", ko: "단오", enUS: "Dragon Boat Festival"),
            type: .traditional,
            isObserved: true
        ),
        Holiday(
            id: "cn-dragonboat-holiday-2026",
            region: .china,
            date: DateOnly(year: 2026, month: 6, day: 20),
            localizedNames: LocalizedText(zhHans: "端午节假", ja: "端午の節句休暇", ko: "단오 연휴", enUS: "Dragon Boat Festival Holiday"),
            type: .traditional,
            isObserved: true
        ),
        Holiday(
            id: "cn-dragonboat-holiday2-2026",
            region: .china,
            date: DateOnly(year: 2026, month: 6, day: 21),
            localizedNames: LocalizedText(zhHans: "端午节假", ja: "端午の節句休暇", ko: "단오 연휴", enUS: "Dragon Boat Festival Holiday"),
            type: .traditional,
            isObserved: true
        ),
        // MARK: - Korea 2026
        Holiday(
            id: "kr-salnal-2026",
            region: .korea,
            date: DateOnly(year: 2026, month: 2, day: 17),
            localizedNames: LocalizedText(zhHans: "春节", ja: "春節", ko: "설날", enUS: "Lunar New Year"),
            type: .traditional,
            isObserved: true
        ),
        // MARK: - United States 2026
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
