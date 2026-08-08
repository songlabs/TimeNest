import CoreLocation
import Foundation

struct WeatherLocation: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let fetchedAt: Date

    init(latitude: Double, longitude: Double, fetchedAt: Date, roundsForStorage: Bool = true) {
        if roundsForStorage {
            self.latitude = Self.roundForStorage(latitude)
            self.longitude = Self.roundForStorage(longitude)
        } else {
            self.latitude = latitude
            self.longitude = longitude
        }
        self.fetchedAt = fetchedAt
    }

    var coreLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    func distance(from other: WeatherLocation) -> CLLocationDistance {
        coreLocation.distance(from: other.coreLocation)
    }

    private static func roundForStorage(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

struct CurrentWeatherSnapshot: Codable, Equatable, Sendable {
    let date: Date
    let symbolName: String
    let temperatureCelsius: Double
    let windSpeedMetersPerSecond: Double
}

struct DailyWeatherSnapshot: Codable, Equatable, Identifiable, Sendable {
    let date: Date
    let symbolName: String
    let highTemperatureCelsius: Double
    let lowTemperatureCelsius: Double
    let precipitationChance: Double
    let windSpeedMetersPerSecond: Double

    var id: Date { date }
}

struct HourlyWeatherSnapshot: Codable, Equatable, Identifiable, Sendable {
    let date: Date
    let symbolName: String
    let temperatureCelsius: Double
    let precipitationChance: Double
    let windSpeedMetersPerSecond: Double

    var id: Date { date }
}

struct WeatherAttributionSnapshot: Codable, Equatable, Sendable {
    let serviceName: String
    let combinedMarkLightURL: URL
    let combinedMarkDarkURL: URL
    let squareMarkURL: URL
    let legalPageURL: URL
}

struct WeatherSnapshot: Codable, Equatable, Sendable {
    let location: WeatherLocation
    let fetchedAt: Date
    let expirationDate: Date
    let current: CurrentWeatherSnapshot
    let daily: [DailyWeatherSnapshot]
    let hourly: [HourlyWeatherSnapshot]
    let attribution: WeatherAttributionSnapshot

    func isValid(at date: Date) -> Bool {
        expirationDate > date
    }
}

struct DayWeatherSnapshot: Equatable, Sendable {
    let symbolName: String
    let temperatureCelsius: Double
    let highTemperatureCelsius: Double
    let lowTemperatureCelsius: Double
    let precipitationChance: Double
    let windSpeedMetersPerSecond: Double
    let referenceDate: Date
    let usesCurrentWeather: Bool
    let hourly: [HourlyWeatherSnapshot]
}

enum WeatherValueFormatter {
    static func temperature(_ celsius: Double, locale: Locale, compact: Bool = false) -> String {
        let measurement = Measurement(value: celsius, unit: UnitTemperature.celsius)
        let numberStyle = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
        return measurement.formatted(
            .measurement(
                width: .narrow,
                usage: .weather,
                hidesScaleName: compact,
                numberFormatStyle: numberStyle
            )
            .locale(locale)
        )
    }

    static func windSpeed(_ metersPerSecond: Double, locale: Locale) -> String {
        Measurement(value: metersPerSecond, unit: UnitSpeed.metersPerSecond).formatted(
            .measurement(
                width: .abbreviated,
                usage: .general,
                numberFormatStyle: .number.precision(.fractionLength(0...1))
            )
            .locale(locale)
        )
    }

    static func percentage(_ value: Double, locale: Locale) -> String {
        value.formatted(
            .percent
                .precision(.fractionLength(0))
                .locale(locale)
        )
    }

    static func hour(_ date: Date, locale: Locale) -> String {
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(locale)
        )
    }

    static func updatedAt(_ date: Date, locale: Locale) -> String {
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(locale)
        )
    }
}
