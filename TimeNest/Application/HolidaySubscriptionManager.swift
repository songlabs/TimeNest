import Foundation
import Combine

/// 订阅管理器错误
enum SubscriptionManagerError: Error, LocalizedError {
    case maxLimitExceeded
    case invalidURL
    case invalidSubscriptionURL(region: HolidayRegion, rawURL: String)
    case downloadFailed(Error)
    case parseFailed(Error)
    case syncInProgress

    var errorDescription: String? {
        switch self {
        case .maxLimitExceeded:
            return LocalizationManager.shared.localized(.holidaySubscriptionErrorMaxLimitExceeded)
        case .invalidURL:
            return LocalizationManager.shared.localized(.holidaySubscriptionErrorInvalidURL)
        case .invalidSubscriptionURL:
            return LocalizationManager.shared.localized(.holidaySubscriptionErrorInvalidURL)
        case .downloadFailed(let error):
            return String(
                format: LocalizationManager.shared.localized(.holidaySubscriptionErrorDownloadFailed),
                error.localizedDescription
            )
        case .parseFailed(let error):
            return String(
                format: LocalizationManager.shared.localized(.holidaySubscriptionErrorParseFailed),
                error.localizedDescription
            )
        case .syncInProgress:
            return LocalizationManager.shared.localized(.holidaySubscriptionErrorSyncInProgress)
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

struct HolidaySourceValidationResult: Sendable {
    let eventCount: Int
    let effectiveSourceURL: String
}

/// Preserves both failures when the exact built-in source and its clean
/// fallback fail. The user-facing description intentionally avoids source
/// URLs; callers that need diagnostics can inspect the two typed errors.
struct HolidaySourceFallbackError: Error, LocalizedError {
    let primaryError: Error
    let fallbackError: Error

    var errorDescription: String? {
        LocalizationManager.shared.localized(.holidaySubscriptionSyncFailed)
    }
}

private struct LoadedHolidayEvents {
    let events: [HolidayEvent]
    let effectiveSourceURL: String
}

private enum HolidaySyncOperationKind: Hashable {
    case persistedSync
    case validation
}

private enum HolidaySyncPersistencePolicy: Hashable {
    case persistedCache
    case validationOnly
}

private struct HolidaySyncTaskKey: Hashable {
    let operationKind: HolidaySyncOperationKind
    let sourceIdentity: String
    let region: HolidayRegion
    let normalizedURL: String
    let persistencePolicy: HolidaySyncPersistencePolicy
}

private enum HolidaySyncControlError: Error {
    case superseded
}

/// 节假日订阅管理器
@MainActor
class HolidaySubscriptionManager: ObservableObject {
    
    // MARK: - Shared Instance
    
    static let shared = HolidaySubscriptionManager(cacheRepository: HolidayEventCacheRepository.shared)

    // MARK: - Constants

    private let maxEnabledSubscriptions = 2
    private let syncCacheThresholdHours: TimeInterval = 24 * 60 * 60  // 24 小时

    // MARK: - Published Properties

    @Published private(set) var subscriptions: [HolidaySubscription] = []
    @Published private(set) var syncInProgress = false
    @Published private(set) var syncingRegions: Set<HolidayRegion> = []
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
    private let now: () -> Date
    private let autoSyncMinimumInterval: TimeInterval
    private var lastAutoSyncAttemptAt: Date?
    private var syncAllCallCount = 0
    private var persistedSyncTasks: [HolidaySyncTaskKey: Task<Int, Error>] = [:]
    private var validationTasks: [
        HolidaySyncTaskKey: Task<HolidaySourceValidationResult, Error>
    ] = [:]

    // MARK: - Keys

    private enum Keys {
        static let subscriptionsKey = "holidaySubscriptions"
    }

    // MARK: - Init

    init(
        downloadService: ICSDownloading = ICSDownloadService(),
        parseService: ICSParsing = ICSParseService(),
        cacheRepository: HolidayEventCacheRepositoryProtocol = HolidayEventCacheRepository.shared,
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        autoSyncMinimumInterval: TimeInterval = 15 * 60
    ) {
        self.downloadService = downloadService
        self.parseService = parseService
        self.cacheRepository = cacheRepository
        self.userDefaults = userDefaults
        self.now = now
        self.autoSyncMinimumInterval = max(0, autoSyncMinimumInterval)

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
        }

        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
    }

    /// 禁用订阅
    func disable(subscription: HolidaySubscription) throws {
        
        updateSubscription(subscription.id) {
            $0.isEnabled = false
        }


        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
    }

    /// 更新订阅的 URL
    func updateURL(for region: HolidayRegion, newURL: String) throws {
        let trimmedURL = newURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // 允许空字符串（用于清除 URL）
        guard !trimmedURL.isEmpty else {
            updateSubscriptionByRegion(region) {
                $0.urlString = ""
                // URL 更新后重置同步状态
                $0.syncStatus = .neverSynced
                $0.lastUpdatedAt = nil
                $0.errorMessage = nil
            }
            NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
            return
        }

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
        let defaultURL = recommendedURLString(for: region) ?? DefaultICSSources.defaultURL(for: region)
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
        let enabled = enabledSubscriptions

        guard !enabled.isEmpty else {
            return SyncResult(totalEvents: 0, error: nil)
        }

        syncAllCallCount += 1
        refreshSyncActivityState()
        defer {
            syncAllCallCount -= 1
            refreshSyncActivityState()
        }
        lastSyncError = nil
        let result = await syncSubscriptions(enabled)

        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
        return result
    }

    /// Validate a candidate source using the exact same download, fallback,
    /// content validation, and parsing pipeline used by persisted sync.
    func validateSourceURL(
        _ rawURLString: String,
        for region: HolidayRegion
    ) async throws -> HolidaySourceValidationResult {
        let trimmedURLString = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        try downloadService.validateURL(trimmedURLString)
        guard validHTTPSURL(from: trimmedURLString) != nil else {
            throw SubscriptionManagerError.invalidURL
        }

        let sourceIdentity = subscriptions.first(where: { $0.region == region })
            .map { "subscription:\($0.id.uuidString.lowercased())" }
            ?? "region:\(region.rawValue)"
        let key = HolidaySyncTaskKey(
            operationKind: .validation,
            sourceIdentity: sourceIdentity,
            region: region,
            normalizedURL: normalizedTaskURLString(trimmedURLString),
            persistencePolicy: .validationOnly
        )
        return try await runValidationSingleFlight(
            key: key,
            sourceURLString: trimmedURLString,
            region: region
        )
    }

    func hasCachedData(for region: HolidayRegion) -> Bool {
        cacheRepository.getLastSyncTime(for: region) != nil
    }

    private func syncSubscription(_ subscription: HolidaySubscription) async throws -> Int {
        let syncURLString: String
        do {
            syncURLString = try resolvedURLString(for: subscription)
        } catch {
            markFailed(subscriptionID: subscription.id, error: error)
            throw error
        }

        let key = HolidaySyncTaskKey(
            operationKind: .persistedSync,
            sourceIdentity: "subscription:\(subscription.id.uuidString.lowercased())",
            region: subscription.region,
            normalizedURL: normalizedTaskURLString(syncURLString),
            persistencePolicy: .persistedCache
        )
        return try await runPersistedSingleFlight(
            key: key,
            subscription: subscription,
            sourceURLString: syncURLString
        )
    }

    /// 同步单个订阅并返回事件数量
    private func syncSingleWithResult(
        subscription: HolidaySubscription,
        sourceURLString: String
    ) async throws -> Int {
        do {
            let loaded = try await loadEvents(
                from: sourceURLString,
                region: subscription.region
            )

            // A URL/toggle edit can happen while the network request is
            // suspended. Never commit a result for a superseded configuration.
            guard isCurrentConfiguration(
                subscriptionID: subscription.id,
                expectedURLString: sourceURLString,
                requiresEnabled: true
            ) else {
                throw HolidaySyncControlError.superseded
            }

            try await cacheRepository.saveEvents(loaded.events, for: subscription.region)

            guard isCurrentConfiguration(
                subscriptionID: subscription.id,
                expectedURLString: sourceURLString,
                requiresEnabled: true
            ) else {
                throw HolidaySyncControlError.superseded
            }

            let successfulSyncTime = now()
            updateSubscription(subscription.id) {
                $0.syncStatus = .success
                $0.lastUpdatedAt = successfulSyncTime
                $0.errorMessage = nil
            }

            NotificationCenter.default.post(name: .holidayEventsDidUpdate, object: nil)
            return loaded.events.count
        } catch HolidaySyncControlError.superseded {
            throw HolidaySyncControlError.superseded
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if isCurrentConfiguration(
                subscriptionID: subscription.id,
                expectedURLString: sourceURLString,
                requiresEnabled: true
            ) {
                markFailed(subscriptionID: subscription.id, error: error)
            }
            throw error
        }
    }

    private func syncSubscriptions(
        _ subscriptions: [HolidaySubscription]
    ) async -> SyncResult {
        let tasks: [Task<Int, Error>] = subscriptions.map { subscription in
            Task { @MainActor [weak self] in
                guard let self else { throw CancellationError() }
                return try await self.syncSubscription(subscription)
            }
        }
        defer { tasks.forEach { $0.cancel() } }

        var totalEvents = 0
        var firstError: Error?
        for task in tasks {
            do {
                totalEvents += try await value(of: task)
            } catch HolidaySyncControlError.superseded {
                continue
            } catch {
                if firstError == nil {
                    firstError = error
                    lastSyncError = error
                }
            }
        }
        return SyncResult(totalEvents: totalEvents, error: firstError)
    }

    private func runPersistedSingleFlight(
        key: HolidaySyncTaskKey,
        subscription: HolidaySubscription,
        sourceURLString: String
    ) async throws -> Int {
        if let existingTask = persistedSyncTasks[key] {
            return try await value(of: existingTask)
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.syncSingleWithResult(
                subscription: subscription,
                sourceURLString: sourceURLString
            )
        }
        persistedSyncTasks[key] = task
        refreshSyncActivityState()
        defer {
            persistedSyncTasks.removeValue(forKey: key)
            refreshSyncActivityState()
        }
        return try await value(of: task)
    }

    private func runValidationSingleFlight(
        key: HolidaySyncTaskKey,
        sourceURLString: String,
        region: HolidayRegion
    ) async throws -> HolidaySourceValidationResult {
        if let existingTask = validationTasks[key] {
            return try await value(of: existingTask)
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { throw CancellationError() }
            let loaded = try await self.loadEvents(
                from: sourceURLString,
                region: region
            )
            return HolidaySourceValidationResult(
                eventCount: loaded.events.count,
                effectiveSourceURL: loaded.effectiveSourceURL
            )
        }
        validationTasks[key] = task
        refreshSyncActivityState()
        defer {
            validationTasks.removeValue(forKey: key)
            refreshSyncActivityState()
        }
        return try await value(of: task)
    }

    private func value<Success: Sendable>(
        of task: Task<Success, Error>
    ) async throws -> Success {
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func refreshSyncActivityState() {
        syncInProgress = syncAllCallCount > 0
        syncingRegions = Set(
            persistedSyncTasks.keys.map(\.region)
                + validationTasks.keys.map(\.region)
        )
    }

    private func loadEvents(
        from sourceURLString: String,
        region: HolidayRegion
    ) async throws -> LoadedHolidayEvents {
        do {
            return try await loadEventsOnce(from: sourceURLString, region: region)
        } catch let primaryError as EnhancedICSError {
            guard case .invalidHTTPStatus(500) = primaryError,
                  let cleanURLString = HolidayRecommendedSources.cleanFallbackURL(
                forRequestedURL: sourceURLString,
                region: region
            ) else {
                throw primaryError
            }

            do {
                return try await loadEventsOnce(from: cleanURLString, region: region)
            } catch {
                throw HolidaySourceFallbackError(
                    primaryError: primaryError,
                    fallbackError: error
                )
            }
        }
    }

    private func loadEventsOnce(
        from sourceURLString: String,
        region: HolidayRegion
    ) async throws -> LoadedHolidayEvents {
        guard let url = validHTTPSURL(from: sourceURLString) else {
            throw SubscriptionManagerError.invalidSubscriptionURL(
                region: region,
                rawURL: sourceURLString
            )
        }

        let data = try await downloadService.download(
            from: url,
            timeout: 30,
            region: region.localizedKey,
            host: url.host ?? ""
        )
        try downloadService.validateICSContent(data)

        let events = try await Task.detached { [parseService] in
            try parseService.parse(
                data: data,
                region: region,
                sourceURL: sourceURLString
            )
        }.value

        guard !events.isEmpty else {
            throw EnhancedICSError.noEvents
        }

        return LoadedHolidayEvents(
            events: events,
            effectiveSourceURL: sourceURLString
        )
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

        // Cache presence and its own successful write timestamp are the source
        // of truth. A recent UserDefaults timestamp must not hide a missing or
        // corrupt cache file.
        guard let cacheLastSyncedAt = cacheRepository.getLastSyncTime(for: region) else {
            return true
        }

        return now().timeIntervalSince(cacheLastSyncedAt) > syncCacheThresholdHours
    }

    /// 执行启动时的自动同步
    func performAutoSync() async {
        let attemptTime = now()
        if let lastAttempt = lastAutoSyncAttemptAt {
            let elapsed = attemptTime.timeIntervalSince(lastAttempt)
            if elapsed >= 0 && elapsed < autoSyncMinimumInterval {
                return
            }
        }
        // Record checks as well as network attempts so rapid active/inactive
        // transitions cannot repeatedly hit a failing, cache-less source.
        lastAutoSyncAttemptAt = attemptTime

        let regionsNeedingSync = HolidayRegion.allCases.filter { shouldAutoSync(for: $0) }

        guard !regionsNeedingSync.isEmpty else {
            return
        }

        lastSyncError = nil
        let subscriptionsToSync = regionsNeedingSync.compactMap { region in
            subscriptions.first(where: { $0.region == region })
        }
        _ = await syncSubscriptions(subscriptionsToSync)

        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
    }

    /// 获取指定地区的节假日（从缓存）
    func holidays(for regions: [HolidayRegion]) -> [HolidayEvent] {
        cacheRepository.getEvents(for: regions)
    }

    /// 获取指定日期的节假日（从缓存）
    func holidays(on date: DateOnly, for regions: [HolidayRegion]) -> [HolidayEvent] {
        cacheRepository.getEvents(on: date, for: regions)
    }

    func reloadFromPersistence() {
        loadSubscriptions()
        NotificationCenter.default.post(name: .holidaySubscriptionsDidChange, object: nil)
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

        // 旧版在首次启用时可能未同步即写入 success。
        for index in subscriptions.indices
        where subscriptions[index].syncStatus == .success && subscriptions[index].lastUpdatedAt == nil {
            subscriptions[index].syncStatus = .neverSynced
        }

        // 确保所有地区都有订阅
        for region in HolidayRegion.allCases {
            if !subscriptions.contains(where: { $0.region == region }) {
                subscriptions.append(createDefaultSubscription(for: region))
            }
        }

        normalizeMissingDefaultURLs()

        saveSubscriptions()
    }

    private func createDefaultSubscription(for region: HolidayRegion) -> HolidaySubscription {
        HolidaySubscription(
            region: region,
            displayNameKey: DefaultICSSources.displayNameKey(for: region),
            urlString: recommendedURLString(for: region) ?? DefaultICSSources.defaultURL(for: region),
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

    private func resolvedURLString(for subscription: HolidaySubscription) throws -> String {
        if let urlString = validHTTPSURLString(from: subscription.urlString) {
            return urlString
        }

        if isMissingURL(subscription.urlString),
           let fallbackURLString = recommendedURLString(for: subscription.region) {
            updateSubscription(subscription.id) {
                $0.urlString = fallbackURLString
                $0.syncStatus = .neverSynced
                $0.lastUpdatedAt = nil
                $0.errorMessage = nil
            }
            return fallbackURLString
        }

        throw SubscriptionManagerError.invalidSubscriptionURL(
            region: subscription.region,
            rawURL: subscription.urlString
        )
    }

    private func normalizeMissingDefaultURLs() {
        for index in subscriptions.indices {
            let region = subscriptions[index].region
            guard isMissingURL(subscriptions[index].urlString),
                  let fallbackURLString = recommendedURLString(for: region) else {
                continue
            }

            subscriptions[index].urlString = fallbackURLString
            subscriptions[index].syncStatus = .neverSynced
            subscriptions[index].lastUpdatedAt = nil
            subscriptions[index].errorMessage = nil
        }
    }

    private func isMissingURL(_ urlString: String) -> Bool {
        urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func recommendedURLString(for region: HolidayRegion) -> String? {
        validHTTPSURLString(from: HolidayRecommendedSources.preferredURL(for: region) ?? "")
    }

    private func validHTTPSURLString(from urlString: String) -> String? {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validHTTPSURL(from: trimmedURL) != nil else {
            return nil
        }
        return trimmedURL
    }

    private func normalizedTaskURLString(_ urlString: String) -> String {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmedURL) else {
            return trimmedURL
        }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        if components.scheme == "https", components.port == 443 {
            components.port = nil
        }
        return components.url?.absoluteString ?? components.string ?? trimmedURL
    }

    private func validHTTPSURL(from urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              scheme.lowercased() == "https",
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return url
    }

    private func isCurrentConfiguration(
        subscriptionID: UUID,
        expectedURLString: String,
        requiresEnabled: Bool
    ) -> Bool {
        guard let current = subscriptions.first(where: { $0.id == subscriptionID }) else {
            return false
        }

        let currentURLString = current.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let expected = expectedURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentURLString == expected else {
            return false
        }

        return !requiresEnabled || current.isEnabled
    }

    private func markFailed(subscriptionID: UUID, error: Error) {
        updateSubscription(subscriptionID) {
            $0.syncStatus = .failed
            // lastUpdatedAt intentionally remains the last successful sync.
            $0.errorMessage = error.localizedDescription
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
