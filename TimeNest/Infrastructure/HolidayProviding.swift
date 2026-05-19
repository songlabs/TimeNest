import Foundation

protocol HolidayProviding {
    func holidays(region: HolidayRegion, from: DateOnly, to: DateOnly) async throws -> [Holiday]
}
