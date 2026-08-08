import Foundation

enum CalendarWeatherError: Equatable {
    case permissionRequired
    case locationDenied
    case locationRestricted
    case locationUnavailable
    case weatherUnavailable
}

@MainActor
final class CalendarWeatherStore: ObservableObject {
    static let enabledKey = "weather.isEnabled"
    static let locationCacheLifetime: TimeInterval = 6 * 60 * 60
    static let refreshThrottle: TimeInterval = 15 * 60
    static let expirationRefreshLeadTime: TimeInterval = 15 * 60
    static let significantLocationDistance: Double = 5_000

    @Published private(set) var isEnabled: Bool
    @Published private(set) var authorizationState: LocationAuthorizationState
    @Published private(set) var isLoading = false
    @Published private(set) var error: CalendarWeatherError?
    @Published private(set) var snapshot: WeatherSnapshot?

    private let locationProvider: LocationProviding
    private let weatherProvider: WeatherProviding
    private let cache: WeatherCacheProviding
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private var refreshTask: Task<Void, Never>?
    private var lastRefreshAttemptAt: Date?

    init(
        locationProvider: LocationProviding,
        weatherProvider: WeatherProviding,
        cache: WeatherCacheProviding,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.locationProvider = locationProvider
        self.weatherProvider = weatherProvider
        self.cache = cache
        self.defaults = defaults
        self.now = now
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        self.authorizationState = locationProvider.authorizationState
    }

    convenience init(defaults: UserDefaults = .standard) {
        self.init(
            locationProvider: CoreLocationLocationProvider(),
            weatherProvider: WeatherKitWeatherProvider(),
            cache: WeatherCacheRepository(),
            defaults: defaults
        )
    }

    var attribution: WeatherAttributionSnapshot? {
        snapshot?.attribution
    }

    var hasValidWeather: Bool {
        guard isEnabled, let snapshot else { return false }
        return snapshot.isValid(at: now())
    }

    func prepareForUse() async {
        authorizationState = locationProvider.authorizationState
        guard isEnabled else {
            snapshot = nil
            error = nil
            return
        }

        await loadValidCache()
        guard authorizationState != .notDetermined else {
            if snapshot == nil { error = .permissionRequired }
            return
        }
        await refreshIfNeeded()
    }

    func enableWeather() async {
        let wasEnabled = isEnabled
        isEnabled = true
        defaults.set(true, forKey: Self.enabledKey)
        authorizationState = locationProvider.authorizationState
        await loadValidCache()
        await refresh(
            force: !wasEnabled,
            allowsAuthorizationRequest: true
        )
    }

    func disableWeather() {
        refreshTask?.cancel()
        refreshTask = nil
        isEnabled = false
        defaults.set(false, forKey: Self.enabledKey)
        snapshot = nil
        error = nil
        isLoading = false
    }

    func refreshIfNeeded() async {
        await refresh(force: false, allowsAuthorizationRequest: false)
    }

    func refresh(
        force: Bool,
        allowsAuthorizationRequest: Bool = false
    ) async {
        guard isEnabled else { return }

        if let refreshTask {
            await refreshTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(
                force: force,
                allowsAuthorizationRequest: allowsAuthorizationRequest
            )
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    func dailyWeather(for date: DateOnly) -> DailyWeatherSnapshot? {
        guard hasValidWeather else { return nil }
        return snapshot?.daily.first(where: { DateOnly(from: $0.date) == date })
    }

    func monthWeatherSymbolName(for date: DateOnly) -> String? {
        guard hasValidWeather, let snapshot else { return nil }
        if let today = DateOnly(from: now()), date == today {
            return snapshot.current.symbolName
        }
        return dailyWeather(for: date)?.symbolName
    }

    func dayWeather(for date: Date) -> DayWeatherSnapshot? {
        guard hasValidWeather,
              let snapshot,
              let dateOnly = DateOnly(from: date),
              let daily = dailyWeather(for: dateOnly) else {
            return nil
        }

        let calendar = Calendar(identifier: .gregorian)
        let hours = snapshot.hourly.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let isToday = calendar.isDate(date, inSameDayAs: now())

        if isToday {
            let currentHourStart = calendar.dateInterval(of: .hour, for: now())?.start ?? now()
            return DayWeatherSnapshot(
                symbolName: snapshot.current.symbolName,
                temperatureCelsius: snapshot.current.temperatureCelsius,
                highTemperatureCelsius: daily.highTemperatureCelsius,
                lowTemperatureCelsius: daily.lowTemperatureCelsius,
                precipitationChance: daily.precipitationChance,
                windSpeedMetersPerSecond: snapshot.current.windSpeedMetersPerSecond,
                referenceDate: snapshot.current.date,
                usesCurrentWeather: true,
                hourly: hours.filter { $0.date >= currentHourStart }
            )
        }

        guard let nearestHour = hours.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else {
            return nil
        }

        return DayWeatherSnapshot(
            symbolName: nearestHour.symbolName,
            temperatureCelsius: nearestHour.temperatureCelsius,
            highTemperatureCelsius: daily.highTemperatureCelsius,
            lowTemperatureCelsius: daily.lowTemperatureCelsius,
            precipitationChance: daily.precipitationChance,
            windSpeedMetersPerSecond: nearestHour.windSpeedMetersPerSecond,
            referenceDate: nearestHour.date,
            usesCurrentWeather: false,
            hourly: hours
        )
    }

    private func loadValidCache() async {
        guard let cached = await cache.load(), cached.isValid(at: now()) else {
            snapshot = nil
            return
        }
        snapshot = cached
    }

    private func performRefresh(force: Bool, allowsAuthorizationRequest: Bool) async {
        authorizationState = locationProvider.authorizationState
        if snapshot == nil {
            await loadValidCache()
        }

        switch authorizationState {
        case .denied:
            publishAuthorizationError(.locationDenied)
            return
        case .restricted:
            publishAuthorizationError(.locationRestricted)
            return
        case .notDetermined where !allowsAuthorizationRequest:
            publishAuthorizationError(.permissionRequired)
            return
        case .notDetermined, .authorized:
            break
        }

        let requestDate = now()
        if !force,
           let lastRefreshAttemptAt,
           requestDate.timeIntervalSince(lastRefreshAttemptAt) < Self.refreshThrottle {
            discardExpiredSnapshot(at: requestDate)
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }
        lastRefreshAttemptAt = requestDate

        do {
            let location = try await resolvedLocation(at: requestDate)
            guard isEnabled, !Task.isCancelled else { return }
            authorizationState = locationProvider.authorizationState

            if let snapshot,
               snapshot.isValid(at: requestDate),
               snapshot.location.distance(from: location) < Self.significantLocationDistance,
               snapshot.expirationDate.timeIntervalSince(requestDate) > Self.expirationRefreshLeadTime {
                return
            }

            let refreshed = try await weatherProvider.weather(for: location)
            guard isEnabled, !Task.isCancelled else { return }
            guard refreshed.isValid(at: now()) else {
                throw CalendarWeatherInternalError.expiredResponse
            }
            try await cache.save(refreshed)
            snapshot = refreshed
            error = nil
        } catch let locationError as LocationProviderError {
            authorizationState = locationProvider.authorizationState
            switch locationError {
            case .denied:
                publishAuthorizationError(.locationDenied)
            case .restricted:
                publishAuthorizationError(.locationRestricted)
            case .unavailable, .requestInProgress:
                publishRecoverableError(.locationUnavailable)
            }
        } catch {
            publishRecoverableError(.weatherUnavailable)
        }
    }

    private func resolvedLocation(at date: Date) async throws -> WeatherLocation {
        if let cachedLocation = locationProvider.cachedLocation(
            maxAge: Self.locationCacheLifetime,
            now: date
        ) {
            return cachedLocation
        }
        return try await locationProvider.requestLocation()
    }

    private func publishAuthorizationError(_ value: CalendarWeatherError) {
        snapshot = nil
        error = value
    }

    private func publishRecoverableError(_ value: CalendarWeatherError) {
        discardExpiredSnapshot(at: now())
        error = value
    }

    private func discardExpiredSnapshot(at date: Date) {
        if let snapshot, !snapshot.isValid(at: date) {
            self.snapshot = nil
        }
    }
}

private enum CalendarWeatherInternalError: Error {
    case expiredResponse
}
