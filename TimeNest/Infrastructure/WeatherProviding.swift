import Foundation
import WeatherKit

protocol WeatherProviding: Sendable {
    func weather(for location: WeatherLocation) async throws -> WeatherSnapshot
}

final class WeatherKitWeatherProvider: WeatherProviding, @unchecked Sendable {
    private let service: WeatherService

    init(service: WeatherService = .shared) {
        self.service = service
    }

    func weather(for location: WeatherLocation) async throws -> WeatherSnapshot {
        async let weatherData = service.weather(
            for: location.coreLocation,
            including: .current,
            .daily,
            .hourly
        )
        async let attributionData = service.attribution

        let ((current, daily, hourly), attribution) = try await (weatherData, attributionData)
        let fetchedAt = Date()
        let expirationDate = min(
            current.metadata.expirationDate,
            daily.metadata.expirationDate,
            hourly.metadata.expirationDate
        )

        return WeatherSnapshot(
            location: location,
            fetchedAt: fetchedAt,
            expirationDate: expirationDate,
            current: CurrentWeatherSnapshot(
                date: current.date,
                symbolName: current.symbolName,
                temperatureCelsius: current.temperature.converted(to: .celsius).value,
                windSpeedMetersPerSecond: current.wind.speed.converted(to: .metersPerSecond).value
            ),
            daily: daily.forecast.map { day in
                DailyWeatherSnapshot(
                    date: day.date,
                    symbolName: day.symbolName,
                    highTemperatureCelsius: day.highTemperature.converted(to: .celsius).value,
                    lowTemperatureCelsius: day.lowTemperature.converted(to: .celsius).value,
                    precipitationChance: day.precipitationChance,
                    windSpeedMetersPerSecond: day.wind.speed.converted(to: .metersPerSecond).value
                )
            },
            hourly: hourly.forecast.map { hour in
                HourlyWeatherSnapshot(
                    date: hour.date,
                    symbolName: hour.symbolName,
                    temperatureCelsius: hour.temperature.converted(to: .celsius).value,
                    precipitationChance: hour.precipitationChance,
                    windSpeedMetersPerSecond: hour.wind.speed.converted(to: .metersPerSecond).value
                )
            },
            attribution: WeatherAttributionSnapshot(
                serviceName: attribution.serviceName,
                combinedMarkLightURL: attribution.combinedMarkLightURL,
                combinedMarkDarkURL: attribution.combinedMarkDarkURL,
                squareMarkURL: attribution.squareMarkURL,
                legalPageURL: attribution.legalPageURL
            )
        )
    }
}
