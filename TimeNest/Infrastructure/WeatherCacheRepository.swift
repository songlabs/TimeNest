import Foundation

protocol WeatherCacheProviding: Sendable {
    func load() async -> WeatherSnapshot?
    func save(_ snapshot: WeatherSnapshot) async throws
    func clear() async throws
}

actor WeatherCacheRepository: WeatherCacheProviding {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let fileURL: URL
    private var memory: WeatherSnapshot?

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        let directory = directoryURL
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("Weather", isDirectory: true)
        self.directoryURL = directory
        self.fileURL = directory.appendingPathComponent("forecast.json")
    }

    func load() async -> WeatherSnapshot? {
        if let memory { return memory }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(WeatherSnapshot.self, from: data) else {
            return nil
        }
        memory = decoded
        return decoded
    }

    func save(_ snapshot: WeatherSnapshot) async throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
        memory = snapshot
    }

    func clear() async throws {
        memory = nil
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
}
