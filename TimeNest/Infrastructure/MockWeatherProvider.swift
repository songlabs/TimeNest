import Foundation

actor MockWeatherProvider: WeatherProviding {
    func weather(for date: Date, in region: HolidayRegion) async throws -> WeatherInfo? {
        nil
    }
}
