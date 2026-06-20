import Foundation

/// 节假日缓存仓库协议
protocol HolidayEventCacheRepositoryProtocol {
    func saveEvents(_ events: [HolidayEvent], for region: HolidayRegion) async throws
    func getEvents(for regions: [HolidayRegion]) -> [HolidayEvent]
    func getEvents(on date: DateOnly, for regions: [HolidayRegion]) -> [HolidayEvent]
    func getEvents(in range: ClosedRange<DateOnly>, for regions: [HolidayRegion]) -> [HolidayEvent]
    func clearEvents() async throws
    func getLastSyncTime(for region: HolidayRegion) -> Date?
}

/// 本地文件缓存仓库
class HolidayEventCacheRepository: HolidayEventCacheRepositoryProtocol {

    static let shared = HolidayEventCacheRepository()

    private final class CacheStorage: @unchecked Sendable {
        private let lockQueue = DispatchQueue(label: "com.timenest.holidaycache", attributes: .concurrent)
        private var cache: [String: HolidayEventCache] = [:]

        func cache(for region: HolidayRegion) -> HolidayEventCache? {
            lockQueue.sync { cache[region.rawValue] }
        }

        func setCache(_ holidayCache: HolidayEventCache, for region: HolidayRegion) {
            lockQueue.sync(flags: .barrier) {
                cache[region.rawValue] = holidayCache
            }
        }

        func removeAll() {
            lockQueue.sync(flags: .barrier) {
                cache.removeAll()
            }
        }

        func events(for regions: [HolidayRegion]) -> [HolidayEvent] {
            lockQueue.sync {
                regions.flatMap { cache[$0.rawValue]?.events ?? [] }
            }
        }

        func events(on date: DateOnly, for regions: [HolidayRegion]) -> [HolidayEvent] {
            lockQueue.sync {
                regions.flatMap { cache[$0.rawValue]?.events(on: date) ?? [] }
            }
        }

        func events(in range: ClosedRange<DateOnly>, for regions: [HolidayRegion]) -> [HolidayEvent] {
            lockQueue.sync {
                regions.flatMap { cache[$0.rawValue]?.events(in: range) ?? [] }
            }
        }

        func lastSyncTime(for region: HolidayRegion) -> Date? {
            lockQueue.sync { cache[region.rawValue]?.lastSyncedAt }
        }
    }

    private var cacheDirectory: URL
    private let storage = CacheStorage()

    init(fileManager: FileManager = .default, cacheDirectory: URL? = nil) {
        // 确定缓存目录
        if let customDir = cacheDirectory {
            self.cacheDirectory = customDir
        } else {
            let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            self.cacheDirectory = urls.first!.appendingPathComponent("HolidayCache", isDirectory: true)
        }

        // 创建缓存目录
        try? fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)

        // 加载现有缓存
        loadAllCaches()
    }

    /// 获取缓存文件 URL
    private func cacheFileURL(for region: HolidayRegion) -> URL {
        cacheDirectory.appendingPathComponent("\(region.rawValue)_holidays.json")
    }

    /// 加载所有缓存
    private func loadAllCaches() {
        for region in HolidayRegion.allCases {
            let fileURL = cacheFileURL(for: region)
            if let data = try? Data(contentsOf: fileURL),
               let cache = try? JSONDecoder().decode(HolidayEventCache.self, from: data) {
                storage.setCache(cache, for: region)
            }
        }
    }

    /// 保存单个地区的缓存
    private func saveCache(for region: HolidayRegion) throws {
        guard let cache = storage.cache(for: region) else { return }

        let fileURL = cacheFileURL(for: region)
        let data = try JSONEncoder().encode(cache)
        try data.write(to: fileURL)
    }

    // MARK: - Public Methods

    func saveEvents(_ events: [HolidayEvent], for region: HolidayRegion) async throws {
        let cacheDirectory = self.cacheDirectory
        let storage = self.storage

        try await Task.detached(priority: .background) {
            var existingCache = storage.cache(for: region) ?? HolidayEventCache()

            // 移除该地区已有的旧事件
            existingCache.events.removeAll { $0.region == region }

            // 添加新事件
            existingCache.events.append(contentsOf: events)
            existingCache.lastSyncedAt = Date()

            // 保存到文件
            let fileURL = cacheDirectory.appendingPathComponent("\(region.rawValue)_holidays.json")
            let data = try JSONEncoder().encode(existingCache)
            try data.write(to: fileURL)

            storage.setCache(existingCache, for: region)
        }.value
    }

    func getEvents(for regions: [HolidayRegion]) -> [HolidayEvent] {
        storage.events(for: regions).sorted { $0.date < $1.date }
    }

    func getEvents(on date: DateOnly, for regions: [HolidayRegion]) -> [HolidayEvent] {
        storage.events(on: date, for: regions)
    }

    func getEvents(in range: ClosedRange<DateOnly>, for regions: [HolidayRegion]) -> [HolidayEvent] {
        // 如果 regions 为空，直接返回空数组
        guard !regions.isEmpty else {
            return []
        }
        return storage.events(in: range, for: regions).sorted { $0.date < $1.date }
    }

    func clearEvents() async throws {
        let cacheDirectory = self.cacheDirectory
        let storage = self.storage

        await Task.detached(priority: .background) {
            // Clear cache
            storage.removeAll()

            // Delete all cache files
            for region in HolidayRegion.allCases {
                let fileURL = cacheDirectory.appendingPathComponent("\(region.rawValue)_holidays.json")
                try? FileManager.default.removeItem(at: fileURL)
            }
        }.value
    }

    func getLastSyncTime(for region: HolidayRegion) -> Date? {
        storage.lastSyncTime(for: region)
    }
}
