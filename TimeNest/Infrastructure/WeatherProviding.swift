import Foundation

protocol WeatherProviding {
    func weather(for date: Date, in region: HolidayRegion) async throws -> WeatherInfo?
}

struct WeatherInfo: Hashable {
    let temperature: Double
    let condition: String
}
