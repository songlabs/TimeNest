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

    private let fileManager: FileManager
    private var cacheDirectory: URL
    private let lockQueue: DispatchQueue

    // 缓存数据（内存中）
    private var cache: [String: HolidayEventCache] = [:]

    init(fileManager: FileManager = .default, cacheDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.lockQueue = DispatchQueue(label: "com.timenest.holidaycache", attributes: .concurrent)

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
                self.cache[region.rawValue] = cache
            }
        }
    }

    /// 保存单个地区的缓存
    private func saveCache(for region: HolidayRegion) throws {
        guard let cache = cache[region.rawValue] else { return }

        let fileURL = cacheFileURL(for: region)
        let data = try JSONEncoder().encode(cache)
        try data.write(to: fileURL)
    }

    // MARK: - Public Methods

    func saveEvents(_ events: [HolidayEvent], for region: HolidayRegion) async throws {
        try await Task.detached(priority: .background) { [cacheDirectory = self.cacheDirectory, lockQueue = self.lockQueue, cache = self.cache] in
            var existingCache = cache[region.rawValue] ?? HolidayEventCache()

            // 移除该地区已有的旧事件
            existingCache.events.removeAll { $0.region == region }

            // 添加新事件
            existingCache.events.append(contentsOf: events)
            existingCache.lastSyncedAt = Date()

            // 保存到文件
            let fileURL = cacheDirectory.appendingPathComponent("\(region.rawValue)_holidays.json")
            let data = try JSONEncoder().encode(existingCache)
            try data.write(to: fileURL)

            lockQueue.async(flags: .barrier) {
                self.cache[region.rawValue] = existingCache
            }
        }.value
    }

    func getEvents(for regions: [HolidayRegion]) -> [HolidayEvent] {
        var events: [HolidayEvent] = []

        lockQueue.sync {
            for region in regions {
                if let cache = self.cache[region.rawValue] {
                    events.append(contentsOf: cache.events)
                }
            }
        }

        return events.sorted { $0.date < $1.date }
    }

    func getEvents(on date: DateOnly, for regions: [HolidayRegion]) -> [HolidayEvent] {
        lockQueue.sync {
            var events: [HolidayEvent] = []
            for region in regions {
                if let cache = self.cache[region.rawValue] {
                    events.append(contentsOf: cache.events(on: date))
                }
            }
            return events
        }
    }

    func getEvents(in range: ClosedRange<DateOnly>, for regions: [HolidayRegion]) -> [HolidayEvent] {
        // 如果 regions 为空，直接返回空数组
        guard !regions.isEmpty else {
            return []
        }
        let sorted = lockQueue.sync {
            var events: [HolidayEvent] = []
            for region in regions {
                if let cache = self.cache[region.rawValue] {
                    events.append(contentsOf: cache.events(in: range))
                }
            }
            return events.sorted { $0.date < $1.date }
        }

        return sorted
    }

    func clearEvents() async throws {
        try await Task.detached(priority: .background) { [cacheDirectory = self.cacheDirectory, lockQueue = self.lockQueue] in
            // Clear cache
            lockQueue.async(flags: .barrier) {
                self.cache.removeAll()
            }

            // Delete all cache files
            for region in HolidayRegion.allCases {
                let fileURL = cacheDirectory.appendingPathComponent("\(region.rawValue)_holidays.json")
                try? FileManager.default.removeItem(at: fileURL)
            }
        }.value
    }

    func getLastSyncTime(for region: HolidayRegion) -> Date? {
        lockQueue.sync {
            return self.cache[region.rawValue]?.lastSyncedAt
        }
    }
}
