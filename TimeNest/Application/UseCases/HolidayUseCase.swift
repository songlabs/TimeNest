import Foundation

class HolidayUseCase {
    private let holidayProvider: HolidayProviding?
    private let cacheRepository: HolidayEventCacheRepositoryProtocol

    /// 使用缓存仓库初始化（ICS 订阅模式）
    init(cacheRepository: HolidayEventCacheRepositoryProtocol = HolidayEventCacheRepository()) {
        self.holidayProvider = nil
        self.cacheRepository = cacheRepository
    }

    /// 使用提供者初始化（向后兼容，用于测试）
    init(holidayProvider: HolidayProviding, cacheRepository: HolidayEventCacheRepositoryProtocol = HolidayEventCacheRepository()) {
        self.holidayProvider = holidayProvider
        self.cacheRepository = cacheRepository
    }

    func holidays(region: HolidayRegion, from: DateOnly, to: DateOnly) async throws -> [Holiday] {
        // 优先从缓存读取
        let cachedEvents = cacheRepository.getEvents(in: from...to, for: [region])
        
        // 将 HolidayEvent 转换为 Holiday
        let holidays = cachedEvents.map { event in
            Holiday(
                id: event.id,
                region: event.region,
                date: event.date,
                localizedNames: LocalizedText(
                    zhHans: event.displayName(for: "zhHans"),
                    ja: event.displayName(for: "ja"),
                    ko: event.displayName(for: "ko"),
                    enUS: event.displayName(for: "enUS")
                ),
                type: holidayType(from: event.type),
                isObserved: true
            )
        }
        
        return holidays.sorted { $0.date < $1.date }
    }

    func holidays(regions: [HolidayRegion], from: DateOnly, to: DateOnly) async throws -> [Holiday] {
        // 优先从缓存读取
        let cachedEvents = cacheRepository.getEvents(in: from...to, for: regions)
        
        // 将 HolidayEvent 转换为 Holiday
        let holidays = cachedEvents.map { event in
            Holiday(
                id: event.id,
                region: event.region,
                date: event.date,
                localizedNames: LocalizedText(
                    zhHans: event.displayName(for: "zhHans"),
                    ja: event.displayName(for: "ja"),
                    ko: event.displayName(for: "ko"),
                    enUS: event.displayName(for: "enUS")
                ),
                type: holidayType(from: event.type),
                isObserved: true
            )
        }
        
        return holidays.sorted { $0.date < $1.date }
    }

    func holidaysInDateRange(from: DateOnly, to: DateOnly, setting: CalendarDisplaySetting) async throws -> [Holiday] {
        return try await holidays(regions: setting.selectedHolidayRegions, from: from, to: to)
    }
    
    // MARK: - Private
    
    private func holidayType(from eventType: HolidayEventType) -> HolidayType {
        switch eventType {
        case .publicHoliday:
            return .publicHoliday
        case .traditional:
            return .traditional
        case .observance:
            return .observance
        case .other:
            return .observance
        }
    }
}
