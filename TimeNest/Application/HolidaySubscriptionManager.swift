import Foundation
import Combine

/// 订阅管理器错误
enum SubscriptionManagerError: Error, LocalizedError {
    case maxLimitExceeded
    case invalidURL
    case downloadFailed(Error)
    case parseFailed(Error)
    case syncInProgress

    var errorDescription: String? {
        switch self {
        case .maxLimitExceeded:
            return "最多只能启用 2 个订阅"
        case .invalidURL:
            return "无效的 URL"
        case .downloadFailed(let error):
            return "下载失败：\(error.localizedDescription)"
        case .parseFailed(let error):
            return "解析失败：\(error.localizedDescription)"
        case .syncInProgress:
            return "同步正在进行中"
        }
    }
}

/// 同步结果
struct SyncResult {
    let totalEvents: Int
    let error: Error?
    
    var isSuccess: Bool {
        error == nil
    }
}

/// 节假日订阅管理器
@MainActor
class HolidaySubscriptionManager: ObservableObject {
    
    // MARK: - Shared Instance
    
    static let shared = HolidaySubscriptionManager()

    // MARK: - Constants

    private let maxEnabledSubscriptions = 2
    private let syncCacheThresholdHours: TimeInterval = 24 * 60 * 60  // 24 小时

    // MARK: - Published Properties

    @Published private(set) var subscriptions: [HolidaySubscription] = []
    @Published private(set) var syncInProgress = false
    @Published private(set) var lastSyncError: Error?
    
    // MARK: - Computed Properties
    
    /// 获取已启用的地区
    var enabledRegions: [HolidayRegion] {
        enabledSubscriptions.map { $0.region }
    }

    // MARK: - Dependencies

    private let downloadService: ICSDownloading
    private let parseService: ICSParsing
    private let cacheRepository: HolidayEventCacheRepositoryProtocol
    private let userDefaults: UserDefaults

    // MARK: - Keys

    private enum Keys {
        static let subscriptionsKey = "holidaySubscriptions"
    }

    // MARK: - Init

    init(
        downloadService: ICSDownloading = ICSDownloadService(),
        parseService: ICSParsing = ICSParseService(),
        cacheRepository: HolidayEventCacheRepositoryProtocol = HolidayEventCacheRepository(),
        userDefaults: UserDefaults = .standard
    ) {
        self.downloadService = downloadService
        self.parseService = parseService
        self.cacheRepository = cacheRepository
        self.userDefaults = userDefaults

        loadSubscriptions()
    }

    // MARK: - Public Methods

    /// 获取所有可用地区的订阅
    var allAvailableSubscriptions: [HolidaySubscription] {
        HolidayRegion.allCases.map { region in
            subscriptions.first { $0.region == region } ?? createDefaultSubscription(for: region)
        }
    }

    /// 获取已启用的订阅
    var enabledSubscriptions: [HolidaySubscription] {
        let enabled = subscriptions.filter { $0.isEnabled }
        #if DEBUG
        print("[HolidaySubscriptionManager] enabledSubscriptions count =", enabled.count)
        for sub in enabled {
            print("[HolidaySubscriptionManager] - region:", sub.region.rawValue)
            print("[HolidaySubscriptionManager]   isEnabled:", sub.isEnabled)
            print("[HolidaySubscriptionManager]   url:", sub.urlString.isEmpty ? "(empty)" : sub.urlString)
            print("[HolidaySubscriptionManager]   lastSyncAt:", sub.lastUpdatedAt?.description ?? "nil")
            print("[HolidaySubscriptionManager]   lastSyncStatus:", sub.syncStatus.rawValue)
        }
        #endif
        return enabled
    }

    /// 检查是否可以启用新的订阅
    func canEnableMore() -> Bool {
        enabledSubscriptions.count < maxEnabledSubscriptions
    }

    /// 检查是否可以禁用当前订阅（允许禁用所有订阅）
    func canDisable(subscription: HolidaySubscription) -> Bool {
        // 允许禁用所有订阅，返回 true
        return true
    }

    /// 启用订阅
    func enable(subscription: HolidaySubscription) throws {
        if !canEnableMore() {
            throw SubscriptionManagerError.maxLimitExceeded
        }

        updateSubscription(subscription.id) {
            $0.isEnabled = true
            // 首次启用时立即同步
            if $0.syncStatus == .neverSynced {
                $0.syncStatus = .success  // 同步会在后台进行
            }
        }

        #if DEBUG
        print("[HolidaySubscriptionManager] enable subscription - region =", subscription.region.rawValue)
        print("[HolidaySubscriptionManager] enabled regions after enable =", enabledRegions.map { $0.rawValue })
        #endif

        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
    }

    /// 禁用订阅
    func disable(subscription: HolidaySubscription) throws {
        #if DEBUG
        print("[HolidaySubscription] before disable - enabledRegions =", enabledRegions.map { $0.rawValue })
        #endif
        
        updateSubscription(subscription.id) {
            $0.isEnabled = false
        }

        #if DEBUG
        print("[HolidaySubscription] after disable - enabledRegions =", enabledRegions.map { $0.rawValue })
        #endif

        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
    }

    /// 更新订阅的 URL
    func updateURL(for region: HolidayRegion, newURL: String) throws {
        let trimmedURL = newURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // 验证 URL
        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme,
              scheme.lowercased() == "https" else {
            throw SubscriptionManagerError.invalidURL
        }

        updateSubscriptionByRegion(region) {
            $0.urlString = trimmedURL
            // URL 更新后重置同步状态
            $0.syncStatus = .neverSynced
            $0.lastUpdatedAt = nil
            $0.errorMessage = nil
        }

        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
    }

    /// 恢复默认 URL
    func resetToDefaultURL(for region: HolidayRegion) {
        let defaultURL = DefaultICSSources.defaultURL(for: region)
        updateSubscriptionByRegion(region) {
            $0.urlString = defaultURL
            $0.syncStatus = .neverSynced
            $0.lastUpdatedAt = nil
            $0.errorMessage = nil
        }

        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
    }

    /// 手动同步所有启用的订阅
    /// - Returns: 同步结果，包含成功解析的事件总数和错误信息（如果有）
    func syncAllEnabled() async -> SyncResult {
        guard !syncInProgress else {
            return SyncResult(totalEvents: 0, error: SubscriptionManagerError.syncInProgress)
        }

        #if DEBUG
        print("[HolidaySubscriptionManager] syncAllEnabled started")
        #endif

        syncInProgress = true
        lastSyncError = nil

        defer {
            Task { @MainActor in
                self.syncInProgress = false
            }
        }

        let enabled = enabledSubscriptions

        guard !enabled.isEmpty else {
            #if DEBUG
            print("[HolidaySubscriptionManager] no enabled subscriptions")
            #endif
            return SyncResult(totalEvents: 0, error: nil)
        }

        #if DEBUG
        print("[HolidaySubscriptionManager] enabled subscriptions count =", enabled.count)
        for sub in enabled {
            print("[HolidaySubscriptionManager] - region:", sub.region.rawValue, "URL:", sub.urlString)
        }
        #endif

        var totalEvents = 0
        var firstError: Error?

        for subscription in enabled {
            do {
                let events = try await syncSingleWithResult(subscription: subscription)
                totalEvents += events
            } catch {
                #if DEBUG
                print("[HolidaySubscriptionManager] sync failed for", subscription.region.rawValue, ":", error.localizedDescription)
                #endif
                updateSubscription(subscription.id) {
                    $0.syncStatus = .failed
                    $0.errorMessage = error.localizedDescription
                }
                if firstError == nil {
                    firstError = error
                    lastSyncError = error
                }
            }
        }

        #if DEBUG
        print("[HolidaySubscriptionManager] syncAllEnabled completed, total events =", totalEvents)
        #endif

        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
        
        return SyncResult(totalEvents: totalEvents, error: firstError)
    }
    
    /// 同步单个订阅并返回事件数量
    private func syncSingleWithResult(subscription: HolidaySubscription) async throws -> Int {
        #if DEBUG
        print("[HolidaySubscriptionManager] syncSingleWithResult started for", subscription.region.rawValue)
        print("[HolidaySubscriptionManager] URL =", subscription.urlString)
        #endif

        guard let url = URL(string: subscription.urlString) else {
            throw SubscriptionManagerError.invalidURL
        }

        let host = url.host ?? ""
        let regionName = subscription.region.localizedKey

        // 下载 ICS 数据
        let data = try await downloadService.download(from: url, timeout: 30, region: regionName, host: host)

        #if DEBUG
        print("[HolidaySubscriptionManager] download succeeded, data size =", data.count)
        #endif

        // 解析 ICS
        let events = try await Task.detached { [parseService] in
            try parseService.parse(data: data, region: subscription.region, sourceURL: subscription.urlString)
        }.value

        #if DEBUG
        print("[HolidaySubscriptionManager] parsed holidays count =", events.count)
        if let firstEvent = events.first {
            print("[HolidaySubscriptionManager] first holiday =", firstEvent.name, "on", firstEvent.date)
        }
        #endif

        // 保存到缓存
        try await cacheRepository.saveEvents(events, for: subscription.region)

        #if DEBUG
        print("[HolidaySubscriptionManager] events saved to cache")
        #endif

        // 更新订阅状态
        updateSubscription(subscription.id) {
            $0.syncStatus = .success
            $0.lastUpdatedAt = Date()
            $0.errorMessage = nil
        }

        #if DEBUG
        print("[HolidaySubscriptionManager] syncSingleWithResult completed for", subscription.region.rawValue)
        #endif

        NotificationCenter.default.post(name: .holidayEventsDidUpdate, object: nil)
        
        return events.count
    }

    /// 同步单个订阅（不返回事件数量）
    private func syncSingle(subscription: HolidaySubscription) async throws {
        _ = try await syncSingleWithResult(subscription: subscription)
    }

    /// 检查是否需要自动同步
    func shouldAutoSync(for region: HolidayRegion) -> Bool {
        guard let subscription = subscriptions.first(where: { $0.region == region }),
              subscription.isEnabled else {
            return false
        }

        // 从未同步过
        if subscription.syncStatus == .neverSynced {
            return true
        }

        // 超过 24 小时
        if let lastSynced = subscription.lastUpdatedAt {
            return Date().timeIntervalSince(lastSynced) > syncCacheThresholdHours
        }

        return false
    }

    /// 执行启动时的自动同步
    func performAutoSync() async {
        let regionsNeedingSync = HolidayRegion.allCases.filter { shouldAutoSync(for: $0) }

        guard !regionsNeedingSync.isEmpty else {
            return
        }

        for region in regionsNeedingSync {
            if let subscription = subscriptions.first(where: { $0.region == region }) {
                do {
                    try await syncSingle(subscription: subscription)
                } catch {
                    // 静默失败，继续使用缓存
                    print("Auto sync failed for \(region.rawValue): \(error)")
                }
            }
        }
    }

    /// 获取指定地区的节假日（从缓存）
    func holidays(for regions: [HolidayRegion]) -> [HolidayEvent] {
        cacheRepository.getEvents(for: regions)
    }

    /// 获取指定日期的节假日（从缓存）
    func holidays(on date: DateOnly, for regions: [HolidayRegion]) -> [HolidayEvent] {
        cacheRepository.getEvents(on: date, for: regions)
    }

    // MARK: - Private Methods

    private func loadSubscriptions() {
        guard let json = userDefaults.string(forKey: Keys.subscriptionsKey),
              let data = json.data(using: .utf8),
              let loaded = try? JSONDecoder().decode([HolidaySubscription].self, from: data) else {
            // 初始化默认订阅
            subscriptions = HolidayRegion.allCases.map { createDefaultSubscription(for: $0) }
            saveSubscriptions()
            return
        }

        subscriptions = loaded

        // 确保所有地区都有订阅
        for region in HolidayRegion.allCases {
            if !subscriptions.contains(where: { $0.region == region }) {
                subscriptions.append(createDefaultSubscription(for: region))
            }
        }

        saveSubscriptions()
    }

    private func createDefaultSubscription(for region: HolidayRegion) -> HolidaySubscription {
        HolidaySubscription(
            region: region,
            displayNameKey: DefaultICSSources.displayNameKey(for: region),
            urlString: DefaultICSSources.defaultURL(for: region),
            isEnabled: region == .japan,  // 默认启用日本
            syncStatus: .neverSynced
        )
    }

    private func saveSubscriptions() {
        if let data = try? JSONEncoder().encode(subscriptions),
           let json = String(data: data, encoding: .utf8) {
            userDefaults.set(json, forKey: Keys.subscriptionsKey)
        }
    }

    private func updateSubscription(_ id: UUID, update: (inout HolidaySubscription) -> Void) {
        if let index = subscriptions.firstIndex(where: { $0.id == id }) {
            var subscription = subscriptions[index]
            update(&subscription)
            subscriptions[index] = subscription
            saveSubscriptions()
        }
    }

    private func updateSubscriptionByRegion(_ region: HolidayRegion, update: (inout HolidaySubscription) -> Void) {
        if let index = subscriptions.firstIndex(where: { $0.region == region }) {
            var subscription = subscriptions[index]
            update(&subscription)
            subscriptions[index] = subscription
            saveSubscriptions()
        }
    }
}
