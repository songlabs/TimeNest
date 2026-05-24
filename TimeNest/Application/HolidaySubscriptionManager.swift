import Foundation
import Combine

/// 订阅管理器错误
enum SubscriptionManagerError: Error, LocalizedError {
    case maxLimitExceeded
    case minLimitRequired
    case invalidURL
    case downloadFailed(Error)
    case parseFailed(Error)
    case noEnabledSubscriptions

    var errorDescription: String? {
        switch self {
        case .maxLimitExceeded:
            return "最多只能启用 2 个订阅"
        case .minLimitRequired:
            return "至少需要启用 1 个订阅"
        case .invalidURL:
            return "无效的 URL"
        case .downloadFailed(let error):
            return "下载失败：\(error.localizedDescription)"
        case .parseFailed(let error):
            return "解析失败：\(error.localizedDescription)"
        case .noEnabledSubscriptions:
            return "没有启用的订阅"
        }
    }
}

/// 节假日订阅管理器
@MainActor
class HolidaySubscriptionManager: ObservableObject {

    // MARK: - Constants

    private let maxEnabledSubscriptions = 2
    private let minEnabledSubscriptions = 1
    private let syncCacheThresholdHours: TimeInterval = 24 * 60 * 60  // 24 小时

    // MARK: - Published Properties

    @Published private(set) var subscriptions: [HolidaySubscription] = []
    @Published private(set) var syncInProgress = false
    @Published private(set) var lastSyncError: Error?

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
        subscriptions.filter { $0.isEnabled }
    }

    /// 获取已启用的地区
    var enabledRegions: [HolidayRegion] {
        enabledSubscriptions.map { $0.region }
    }

    /// 检查是否可以启用新的订阅
    func canEnableMore() -> Bool {
        enabledSubscriptions.count < maxEnabledSubscriptions
    }

    /// 检查是否可以禁用当前订阅
    func canDisable(subscription: HolidaySubscription) -> Bool {
        let enabledCount = subscriptions.filter { $0.isEnabled && $0.id != subscription.id }.count
        return enabledCount >= minEnabledSubscriptions
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

        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
    }

    /// 禁用订阅
    func disable(subscription: HolidaySubscription) throws {
        if !canDisable(subscription: subscription) {
            throw SubscriptionManagerError.minLimitRequired
        }

        updateSubscription(subscription.id) {
            $0.isEnabled = false
        }

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
    func syncAllEnabled() async {
        guard !syncInProgress else { return }

        syncInProgress = true
        lastSyncError = nil

        defer {
            Task { @MainActor in
                self.syncInProgress = false
            }
        }

        let enabled = enabledSubscriptions

        guard !enabled.isEmpty else {
            return
        }

        for subscription in enabled {
            do {
                try await syncSingle(subscription: subscription)
            } catch {
                updateSubscription(subscription.id) {
                    $0.syncStatus = .failed
                    $0.errorMessage = error.localizedDescription
                }
                lastSyncError = error
            }
        }

        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
    }

    /// 同步单个订阅
    private func syncSingle(subscription: HolidaySubscription) async throws {
        guard let url = URL(string: subscription.urlString) else {
            throw SubscriptionManagerError.invalidURL
        }

        let host = url.host ?? ""
        let regionName = subscription.region.localizedKey

        // 下载 ICS 数据
        let data = try await downloadService.download(from: url, timeout: 30, region: regionName, host: host)

        // 解析 ICS
        let events = try await Task.detached { [parseService] in
            try parseService.parse(data: data, region: subscription.region, sourceURL: subscription.urlString)
        }.value

        // 保存到缓存
        try await cacheRepository.saveEvents(events, for: subscription.region)

        // 更新订阅状态
        updateSubscription(subscription.id) {
            $0.syncStatus = .success
            $0.lastUpdatedAt = Date()
            $0.errorMessage = nil
        }

        NotificationCenter.default.post(name: .holidayEventsDidUpdate, object: nil)
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
