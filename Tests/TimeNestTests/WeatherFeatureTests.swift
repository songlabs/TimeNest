import Foundation
import XCTest
@testable import TimeNest

final class MonthSecondaryDisplayMigrationTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "MonthSecondaryDisplayMigrationTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testAllLegacyValuesFalseMigratesToNone() {
        setLegacy(lunar: false, rokuyo: false, solarTerm: false)

        XCTAssertEqual(MonthSecondaryDisplayMode.migrateIfNeeded(defaults: defaults), .none)
        XCTAssertEqual(defaults.string(forKey: MonthSecondaryDisplayMode.storageKey), "none")
    }

    func testEachSingleLegacyValueMapsToMatchingMode() {
        let cases: [(Bool, Bool, Bool, MonthSecondaryDisplayMode)] = [
            (true, false, false, .lunar),
            (false, true, false, .rokuyo),
            (false, false, true, .solarTerm)
        ]

        for (lunar, rokuyo, solarTerm, expected) in cases {
            defaults.removePersistentDomain(forName: suiteName)
            setLegacy(lunar: lunar, rokuyo: rokuyo, solarTerm: solarTerm)
            XCTAssertEqual(MonthSecondaryDisplayMode.resolved(defaults: defaults), expected)
        }
    }

    func testMultipleLegacyValuesUseLunarThenRokuyoThenSolarTermPriority() {
        setLegacy(lunar: false, rokuyo: true, solarTerm: true)
        XCTAssertEqual(MonthSecondaryDisplayMode.resolved(defaults: defaults), .rokuyo)

        setLegacy(lunar: true, rokuyo: true, solarTerm: true)
        XCTAssertEqual(MonthSecondaryDisplayMode.resolved(defaults: defaults), .lunar)
    }

    func testExistingNewKeyIsNeverOverwrittenByLegacyValues() {
        defaults.set(MonthSecondaryDisplayMode.solarTerm.rawValue, forKey: MonthSecondaryDisplayMode.storageKey)
        setLegacy(lunar: true, rokuyo: true, solarTerm: false)

        XCTAssertEqual(MonthSecondaryDisplayMode.migrateIfNeeded(defaults: defaults), .solarTerm)
        XCTAssertEqual(defaults.string(forKey: MonthSecondaryDisplayMode.storageKey), "solarTerm")
    }

    func testLegacyMigrationNeverSelectsWeather() {
        for mask in 0..<8 {
            defaults.removePersistentDomain(forName: suiteName)
            setLegacy(
                lunar: mask & 1 != 0,
                rokuyo: mask & 2 != 0,
                solarTerm: mask & 4 != 0
            )
            XCTAssertNotEqual(MonthSecondaryDisplayMode.resolved(defaults: defaults), .weather)
        }
    }

    func testSavingNewModeMirrorsLegacyKeysAsMutuallyExclusive() {
        for mode in MonthSecondaryDisplayMode.allCases {
            MonthSecondaryDisplayMode.save(mode, defaults: defaults)
            XCTAssertEqual(
                defaults.bool(forKey: TraditionalCalendarPreferences.showLunarCalendarKey),
                mode == .lunar
            )
            XCTAssertEqual(
                defaults.bool(forKey: TraditionalCalendarPreferences.showRokuyoKey),
                mode == .rokuyo
            )
            XCTAssertEqual(
                defaults.bool(forKey: TraditionalCalendarPreferences.showSolarTermsKey),
                mode == .solarTerm
            )
        }
    }

    private func setLegacy(lunar: Bool, rokuyo: Bool, solarTerm: Bool) {
        defaults.set(lunar, forKey: TraditionalCalendarPreferences.showLunarCalendarKey)
        defaults.set(rokuyo, forKey: TraditionalCalendarPreferences.showRokuyoKey)
        defaults.set(solarTerm, forKey: TraditionalCalendarPreferences.showSolarTermsKey)
    }
}

@MainActor
final class WeatherHeaderAttributionViewTests: XCTestCase {
    func testUsesWeatherKitSnapshotURLsForMarkLoadingAndLegalRouting() {
        let squareMarkURL = URL(string: "https://weather.example/square-mark.svg")!
        let legalPageURL = URL(string: "https://weather.example/legal")!
        let attribution = WeatherAttributionSnapshot(
            serviceName: "Apple Weather",
            combinedMarkLightURL: URL(string: "https://weather.example/combined-light.svg")!,
            combinedMarkDarkURL: URL(string: "https://weather.example/combined-dark.svg")!,
            squareMarkURL: squareMarkURL,
            legalPageURL: legalPageURL
        )

        let view = WeatherHeaderAttributionView(attribution: attribution)

        XCTAssertEqual(view.squareMarkURL, squareMarkURL)
        XCTAssertEqual(view.legalPageURL, legalPageURL)
    }
}

final class MonthWeatherPresentationPolicyTests: XCTestCase {
    func testWeatherDisplayRequiresVisibleAttributionMark() {
        XCTAssertTrue(
            MonthWeatherPresentationPolicy.allowsWeatherDisplay(
                isWeatherEnabled: true,
                secondaryDisplayMode: .weather,
                isAttributionMarkVisible: true
            )
        )
        XCTAssertFalse(
            MonthWeatherPresentationPolicy.allowsWeatherDisplay(
                isWeatherEnabled: true,
                secondaryDisplayMode: .weather,
                isAttributionMarkVisible: false
            )
        )
    }

    func testNonWeatherModesNeverDisplayWeather() {
        for mode in MonthSecondaryDisplayMode.allCases where mode != .weather {
            XCTAssertFalse(
                MonthWeatherPresentationPolicy.allowsWeatherDisplay(
                    isWeatherEnabled: true,
                    secondaryDisplayMode: mode,
                    isAttributionMarkVisible: true
                ),
                mode.rawValue
            )
        }
    }

    func testWeatherDisplayCanRecoverWhenAttributionBecomesVisible() {
        var isMarkVisible = false
        XCTAssertFalse(
            MonthWeatherPresentationPolicy.allowsWeatherDisplay(
                isWeatherEnabled: true,
                secondaryDisplayMode: .weather,
                isAttributionMarkVisible: isMarkVisible
            )
        )

        isMarkVisible = true

        XCTAssertTrue(
            MonthWeatherPresentationPolicy.allowsWeatherDisplay(
                isWeatherEnabled: true,
                secondaryDisplayMode: .weather,
                isAttributionMarkVisible: isMarkVisible
            )
        )
    }
}

@MainActor
final class CalendarWeatherStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let location = WeatherLocation(
        latitude: 35.68,
        longitude: 139.76,
        fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "CalendarWeatherStoreTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: CalendarWeatherStore.enabledKey)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testValidCacheIsPublishedWithoutWeatherRequest() async {
        let cached = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(cacheSnapshot: cached, response: cached)

        await dependencies.store.prepareForUse()

        XCTAssertEqual(dependencies.store.snapshot, cached)
        XCTAssertNil(dependencies.store.error)
        let callCount = await dependencies.weatherProvider.callCount
        XCTAssertEqual(callCount, 0)
    }

    func testExpiredCacheIsNotDisplayedAndSuccessfulRefreshReplacesIt() async {
        let expired = makeSnapshot(expiration: now.addingTimeInterval(-1))
        let refreshed = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(cacheSnapshot: expired, response: refreshed)

        await dependencies.store.prepareForUse()

        XCTAssertEqual(dependencies.store.snapshot, refreshed)
        let savedSnapshots = await dependencies.cache.savedSnapshots
        let callCount = await dependencies.weatherProvider.callCount
        XCTAssertEqual(savedSnapshots, [refreshed])
        XCTAssertEqual(callCount, 1)
    }

    func testRefreshSuccessPublishesAndCachesWeather() async {
        let refreshed = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(cacheSnapshot: nil, response: refreshed)

        await dependencies.store.refresh(force: false)

        XCTAssertEqual(dependencies.store.snapshot, refreshed)
        XCTAssertNil(dependencies.store.error)
        let savedSnapshots = await dependencies.cache.savedSnapshots
        XCTAssertEqual(savedSnapshots, [refreshed])
    }

    func testRefreshFailureWithoutValidCacheDegradesToUnavailable() async {
        let dependencies = makeDependencies(
            cacheSnapshot: nil,
            response: makeSnapshot(expiration: now.addingTimeInterval(3_600)),
            weatherFails: true
        )

        await dependencies.store.refresh(force: false)

        XCTAssertNil(dependencies.store.snapshot)
        XCTAssertEqual(dependencies.store.error, .weatherUnavailable)
        XCTAssertFalse(dependencies.store.isLoading)
    }

    func testRefreshFailureKeepsStillValidCacheButReportsError() async {
        let cached = makeSnapshot(expiration: now.addingTimeInterval(5 * 60))
        let dependencies = makeDependencies(
            cacheSnapshot: cached,
            response: cached,
            weatherFails: true
        )

        await dependencies.store.prepareForUse()

        XCTAssertEqual(dependencies.store.snapshot, cached)
        XCTAssertEqual(dependencies.store.error, .weatherUnavailable)
    }

    func testDeniedLocationClearsWeatherAndNeverCallsProvider() async {
        let cached = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(
            authorization: .denied,
            cacheSnapshot: cached,
            response: cached
        )

        await dependencies.store.prepareForUse()

        XCTAssertNil(dependencies.store.snapshot)
        XCTAssertEqual(dependencies.store.error, .locationDenied)
        let callCount = await dependencies.weatherProvider.callCount
        XCTAssertEqual(callCount, 0)
    }

    func testRestrictedLocationClearsWeatherAndNeverCallsProvider() async {
        let cached = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(
            authorization: .restricted,
            cacheSnapshot: cached,
            response: cached
        )

        await dependencies.store.prepareForUse()

        XCTAssertNil(dependencies.store.snapshot)
        XCTAssertEqual(dependencies.store.error, .locationRestricted)
        let callCount = await dependencies.weatherProvider.callCount
        XCTAssertEqual(callCount, 0)
    }

    func testAutomaticPreparationNeverPromptsWhenAuthorizationIsUndetermined() async {
        let response = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(
            authorization: .notDetermined,
            cacheSnapshot: nil,
            response: response
        )

        await dependencies.store.prepareForUse()

        XCTAssertEqual(dependencies.store.error, .permissionRequired)
        XCTAssertEqual(dependencies.locationProvider.requestCount, 0)
        let callCount = await dependencies.weatherProvider.callCount
        XCTAssertEqual(callCount, 0)
    }

    func testConcurrentRefreshesAreDeduplicated() async {
        let response = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(cacheSnapshot: nil, response: response)
        await dependencies.weatherProvider.setSuspended(true)

        let first = Task { await dependencies.store.refresh(force: true) }
        await waitForWeatherCalls(dependencies.weatherProvider, count: 1)
        let second = Task { await dependencies.store.refresh(force: true) }
        await Task.yield()

        let callCountWhileSuspended = await dependencies.weatherProvider.callCount
        XCTAssertEqual(callCountWhileSuspended, 1)
        await dependencies.weatherProvider.release()
        await first.value
        await second.value
        let finalCallCount = await dependencies.weatherProvider.callCount
        XCTAssertEqual(finalCallCount, 1)
    }

    func testDisablingDuringRefreshDoesNotRepublishWeather() async {
        let response = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(cacheSnapshot: nil, response: response)
        await dependencies.weatherProvider.setSuspended(true)

        let refresh = Task { await dependencies.store.refresh(force: true) }
        await waitForWeatherCalls(dependencies.weatherProvider, count: 1)
        dependencies.store.disableWeather()
        await dependencies.weatherProvider.release()
        await refresh.value

        XCTAssertFalse(dependencies.store.isEnabled)
        XCTAssertNil(dependencies.store.snapshot)
        XCTAssertNil(dependencies.store.error)
    }

    func testFailedAutomaticRefreshIsThrottled() async {
        let response = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(
            cacheSnapshot: nil,
            response: response,
            weatherFails: true
        )

        await dependencies.store.refresh(force: false)
        await dependencies.store.refresh(force: false)

        let callCount = await dependencies.weatherProvider.callCount
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(dependencies.store.error, .weatherUnavailable)
    }

    func testFailedLocationRefreshIsThrottled() async {
        let response = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(cacheSnapshot: nil, response: response)
        dependencies.locationProvider.cached = nil
        dependencies.locationProvider.requestResult = .failure(LocationProviderError.unavailable)

        await dependencies.store.refresh(force: false)
        await dependencies.store.refresh(force: false)

        XCTAssertEqual(dependencies.locationProvider.requestCount, 1)
        XCTAssertEqual(dependencies.store.error, .locationUnavailable)
        let weatherCallCount = await dependencies.weatherProvider.callCount
        XCTAssertEqual(weatherCallCount, 0)
    }

    func testWeatherFailureIsContainedWithinWeatherStore() async {
        var calendarState = "calendar-remains-visible"
        let response = makeSnapshot(expiration: now.addingTimeInterval(3_600))
        let dependencies = makeDependencies(
            cacheSnapshot: nil,
            response: response,
            weatherFails: true
        )

        await dependencies.store.refresh(force: false)
        calendarState += ""

        XCTAssertEqual(calendarState, "calendar-remains-visible")
        XCTAssertEqual(dependencies.store.error, .weatherUnavailable)
    }

    func testMonthWeatherSymbolUsesCurrentWeatherForToday() async throws {
        let snapshot = makeSnapshot(
            expiration: now.addingTimeInterval(3_600),
            currentSymbolName: "cloud.rain.fill",
            dailySymbolName: "sun.max.fill"
        )
        let dependencies = makeDependencies(cacheSnapshot: snapshot, response: snapshot)

        await dependencies.store.prepareForUse()
        let today = try XCTUnwrap(DateOnly(from: now))

        XCTAssertEqual(dependencies.store.monthWeatherSymbolName(for: today), "cloud.rain.fill")
    }

    func testMonthWeatherSymbolKeepsDailyForecastForFutureDate() async throws {
        let futureDate = now.addingTimeInterval(24 * 60 * 60)
        let snapshot = makeSnapshot(
            expiration: now.addingTimeInterval(3_600),
            dailyDate: futureDate,
            currentSymbolName: "cloud.rain.fill",
            dailySymbolName: "sun.max.fill"
        )
        let dependencies = makeDependencies(cacheSnapshot: snapshot, response: snapshot)

        await dependencies.store.prepareForUse()
        let futureDay = try XCTUnwrap(DateOnly(from: futureDate))

        XCTAssertEqual(dependencies.store.monthWeatherSymbolName(for: futureDay), "sun.max.fill")
    }

    func testMonthWeatherUsesCurrentTodayAndEachAvailableDailyForecast() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let dates = try (0...4).map { offset in
            try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: now))
        }
        let dailySymbols = [
            "sun.max.fill",
            "cloud.sun.fill",
            "cloud.rain.fill",
            "cloud.snow.fill"
        ]
        let dailyForecasts = zip(dates.prefix(4), dailySymbols).map { pair in
            let (date, symbolName) = pair
            return DailyWeatherSnapshot(
                date: date,
                symbolName: symbolName,
                highTemperatureCelsius: 30,
                lowTemperatureCelsius: 21,
                precipitationChance: 0.2,
                windSpeedMetersPerSecond: 3
            )
        }
        let snapshot = makeSnapshot(
            expiration: now.addingTimeInterval(3_600),
            currentSymbolName: "cloud.bolt.rain.fill",
            dailyForecasts: dailyForecasts
        )
        let dependencies = makeDependencies(cacheSnapshot: snapshot, response: snapshot)

        await dependencies.store.prepareForUse()
        let dateOnlyValues = try dates.map { try XCTUnwrap(DateOnly(from: $0)) }

        func presentedSymbols(isAttributionMarkVisible: Bool) -> [String?] {
            dateOnlyValues.map { date in
                guard MonthWeatherPresentationPolicy.allowsWeatherDisplay(
                    isWeatherEnabled: dependencies.store.isEnabled,
                    secondaryDisplayMode: .weather,
                    isAttributionMarkVisible: isAttributionMarkVisible
                ) else {
                    return nil
                }
                return dependencies.store.monthWeatherSymbolName(for: date)
            }
        }

        XCTAssertEqual(
            presentedSymbols(isAttributionMarkVisible: true),
            [
                "cloud.bolt.rain.fill",
                "cloud.sun.fill",
                "cloud.rain.fill",
                "cloud.snow.fill",
                nil
            ]
        )
        XCTAssertEqual(
            presentedSymbols(isAttributionMarkVisible: false),
            [nil, nil, nil, nil, nil]
        )
    }

    func testFutureDayUsesThatDaysHourlyForecastRatherThanCurrentWeather() async throws {
        let futureDate = now.addingTimeInterval(24 * 60 * 60)
        let futureHour = futureDate.addingTimeInterval(12 * 60 * 60)
        let snapshot = makeSnapshot(
            expiration: now.addingTimeInterval(3_600),
            dailyDate: futureHour,
            hourlyDate: futureHour,
            hourlyTemperature: 18
        )
        let dependencies = makeDependencies(cacheSnapshot: snapshot, response: snapshot)

        await dependencies.store.prepareForUse()
        let day = try XCTUnwrap(dependencies.store.dayWeather(for: futureHour))

        XCTAssertFalse(day.usesCurrentWeather)
        XCTAssertEqual(day.temperatureCelsius, 18)
        XCTAssertNotEqual(day.temperatureCelsius, snapshot.current.temperatureCelsius)
    }

    private func makeDependencies(
        authorization: LocationAuthorizationState = .authorized,
        cacheSnapshot: WeatherSnapshot?,
        response: WeatherSnapshot,
        weatherFails: Bool = false
    ) -> WeatherDependencies {
        let locationProvider = MockLocationProvider(
            authorizationState: authorization,
            cached: location
        )
        let weatherProvider = MockWeatherProvider(snapshot: response, fails: weatherFails)
        let cache = MockWeatherCache(snapshot: cacheSnapshot)
        let store = CalendarWeatherStore(
            locationProvider: locationProvider,
            weatherProvider: weatherProvider,
            cache: cache,
            defaults: defaults,
            now: { [now] in now }
        )
        return WeatherDependencies(
            store: store,
            locationProvider: locationProvider,
            weatherProvider: weatherProvider,
            cache: cache
        )
    }

    private func makeSnapshot(
        expiration: Date,
        dailyDate: Date? = nil,
        hourlyDate: Date? = nil,
        hourlyTemperature: Double = 22,
        currentSymbolName: String = "sun.max.fill",
        dailySymbolName: String = "sun.max.fill",
        dailyForecasts: [DailyWeatherSnapshot]? = nil
    ) -> WeatherSnapshot {
        let forecastDate = dailyDate ?? now
        let hourDate = hourlyDate ?? now
        return WeatherSnapshot(
            location: location,
            fetchedAt: now,
            expirationDate: expiration,
            current: CurrentWeatherSnapshot(
                date: now,
                symbolName: currentSymbolName,
                temperatureCelsius: 27,
                windSpeedMetersPerSecond: 3
            ),
            daily: dailyForecasts ?? [
                DailyWeatherSnapshot(
                    date: forecastDate,
                    symbolName: dailySymbolName,
                    highTemperatureCelsius: 30,
                    lowTemperatureCelsius: 21,
                    precipitationChance: 0.2,
                    windSpeedMetersPerSecond: 3
                )
            ],
            hourly: [
                HourlyWeatherSnapshot(
                    date: hourDate,
                    symbolName: "cloud.sun.fill",
                    temperatureCelsius: hourlyTemperature,
                    precipitationChance: 0.15,
                    windSpeedMetersPerSecond: 2
                )
            ],
            attribution: WeatherAttributionSnapshot(
                serviceName: "Apple Weather",
                combinedMarkLightURL: URL(string: "https://example.com/light.svg")!,
                combinedMarkDarkURL: URL(string: "https://example.com/dark.svg")!,
                squareMarkURL: URL(string: "https://example.com/square.svg")!,
                legalPageURL: URL(string: "https://example.com/legal")!
            )
        )
    }

    private func waitForWeatherCalls(_ provider: MockWeatherProvider, count: Int) async {
        for _ in 0..<100 {
            if await provider.callCount >= count { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Weather provider did not receive \(count) call(s)")
    }
}

private struct WeatherDependencies {
    let store: CalendarWeatherStore
    let locationProvider: MockLocationProvider
    let weatherProvider: MockWeatherProvider
    let cache: MockWeatherCache
}

@MainActor
private final class MockLocationProvider: LocationProviding {
    var authorizationState: LocationAuthorizationState
    var cached: WeatherLocation?
    var requestResult: Result<WeatherLocation, Error>
    private(set) var requestCount = 0

    init(authorizationState: LocationAuthorizationState, cached: WeatherLocation) {
        self.authorizationState = authorizationState
        self.cached = cached
        self.requestResult = .success(cached)
    }

    func cachedLocation(maxAge: TimeInterval, now: Date) -> WeatherLocation? {
        guard let cached,
              now.timeIntervalSince(cached.fetchedAt) < maxAge else {
            return nil
        }
        return cached
    }

    func requestLocation() async throws -> WeatherLocation {
        requestCount += 1
        return try requestResult.get()
    }
}

private actor MockWeatherProvider: WeatherProviding {
    private let snapshot: WeatherSnapshot
    private let fails: Bool
    private var suspended = false
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var callCount = 0

    init(snapshot: WeatherSnapshot, fails: Bool) {
        self.snapshot = snapshot
        self.fails = fails
    }

    func setSuspended(_ value: Bool) {
        suspended = value
    }

    func release() {
        suspended = false
        continuation?.resume()
        continuation = nil
    }

    func weather(for location: WeatherLocation) async throws -> WeatherSnapshot {
        callCount += 1
        if suspended {
            await withCheckedContinuation { continuation = $0 }
        }
        if fails { throw MockWeatherError.requestFailed }
        return snapshot
    }
}

private actor MockWeatherCache: WeatherCacheProviding {
    private var snapshot: WeatherSnapshot?
    private(set) var savedSnapshots: [WeatherSnapshot] = []

    init(snapshot: WeatherSnapshot?) {
        self.snapshot = snapshot
    }

    func load() async -> WeatherSnapshot? {
        snapshot
    }

    func save(_ snapshot: WeatherSnapshot) async throws {
        self.snapshot = snapshot
        savedSnapshots.append(snapshot)
    }

    func clear() async throws {
        snapshot = nil
    }
}

private enum MockWeatherError: Error {
    case requestFailed
}
