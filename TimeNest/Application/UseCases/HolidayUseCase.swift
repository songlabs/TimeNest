import Foundation

class HolidayUseCase {
    private let holidayProvider: HolidayProviding

    init(holidayProvider: HolidayProviding) {
        self.holidayProvider = holidayProvider
    }

    func holidays(region: HolidayRegion, from: DateOnly, to: DateOnly) async throws -> [Holiday] {
        try await holidayProvider.holidays(region: region, from: from, to: to)
    }

    func holidays(regions: [HolidayRegion], from: DateOnly, to: DateOnly) async throws -> [Holiday] {
        var allHolidays: [Holiday] = []
        for region in regions {
            let holidays = try await holidayProvider.holidays(region: region, from: from, to: to)
            allHolidays.append(contentsOf: holidays)
        }
        return allHolidays.sorted { $0.date < $1.date }
    }

    func holidaysInDateRange(from: DateOnly, to: DateOnly, setting: CalendarDisplaySetting) async throws -> [Holiday] {
        let allRegions = [setting.primaryHolidayRegion] + setting.additionalHolidayRegions
        return try await holidays(regions: allRegions, from: from, to: to)
    }
}
