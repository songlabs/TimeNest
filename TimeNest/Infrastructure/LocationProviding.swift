import CoreLocation
import Foundation

enum LocationAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum LocationProviderError: LocalizedError, Equatable {
    case denied
    case restricted
    case unavailable
    case requestInProgress

    var errorDescription: String? {
        switch self {
        case .denied:
            "Location permission is denied."
        case .restricted:
            "Location access is restricted."
        case .unavailable:
            "The current location is unavailable."
        case .requestInProgress:
            "A location request is already in progress."
        }
    }
}

@MainActor
protocol LocationProviding: AnyObject {
    var authorizationState: LocationAuthorizationState { get }
    func cachedLocation(maxAge: TimeInterval, now: Date) -> WeatherLocation?
    func requestLocation() async throws -> WeatherLocation
}

@MainActor
final class CoreLocationLocationProvider: NSObject, LocationProviding {
    private let manager: CLLocationManager
    private let cache: WeatherLocationCacheRepository
    private var requestContinuation: CheckedContinuation<WeatherLocation, Error>?

    init(
        manager: CLLocationManager = CLLocationManager(),
        cache: WeatherLocationCacheRepository = WeatherLocationCacheRepository()
    ) {
        self.manager = manager
        self.cache = cache
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorizationState: LocationAuthorizationState {
        switch manager.authorizationStatus {
        case .notDetermined:
            .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .restricted
        }
    }

    func cachedLocation(maxAge: TimeInterval, now: Date = Date()) -> WeatherLocation? {
        guard let location = cache.load(),
              now.timeIntervalSince(location.fetchedAt) >= 0,
              now.timeIntervalSince(location.fetchedAt) < maxAge else {
            return nil
        }
        return location
    }

    func requestLocation() async throws -> WeatherLocation {
        guard requestContinuation == nil else {
            throw LocationProviderError.requestInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            requestContinuation = continuation
            continueRequest(for: authorizationState)
        }
    }

    private func continueRequest(for state: LocationAuthorizationState) {
        switch state {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorized:
            manager.requestLocation()
        case .denied:
            finish(with: .failure(LocationProviderError.denied))
        case .restricted:
            finish(with: .failure(LocationProviderError.restricted))
        }
    }

    private func finish(with result: Result<WeatherLocation, Error>) {
        guard let continuation = requestContinuation else { return }
        requestContinuation = nil
        continuation.resume(with: result)
    }
}

extension CoreLocationLocationProvider: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard requestContinuation != nil else { return }
        continueRequest(for: authorizationState)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last(where: { $0.horizontalAccuracy >= 0 }) else {
            finish(with: .failure(LocationProviderError.unavailable))
            return
        }

        let snapshot = WeatherLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            fetchedAt: location.timestamp
        )
        cache.save(snapshot)
        finish(with: .success(snapshot))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        switch authorizationState {
        case .denied:
            finish(with: .failure(LocationProviderError.denied))
        case .restricted:
            finish(with: .failure(LocationProviderError.restricted))
        case .notDetermined, .authorized:
            finish(with: .failure(LocationProviderError.unavailable))
        }
    }
}

final class WeatherLocationCacheRepository: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var memory: WeatherLocation?

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        let weatherDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Weather", isDirectory: true)
        try? fileManager.createDirectory(at: weatherDirectory, withIntermediateDirectories: true)
        self.fileURL = fileURL ?? weatherDirectory.appendingPathComponent("location.json")

        if let data = try? Data(contentsOf: self.fileURL) {
            memory = try? JSONDecoder().decode(WeatherLocation.self, from: data)
        }
    }

    func load() -> WeatherLocation? {
        lock.withLock { memory }
    }

    func save(_ location: WeatherLocation) {
        lock.withLock { memory = location }
        guard let data = try? JSONEncoder().encode(location) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
