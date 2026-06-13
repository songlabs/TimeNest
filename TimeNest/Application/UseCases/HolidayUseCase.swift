import Foundation

class HolidayUseCase {
    private let holidayProvider: HolidayProviding?
    private let cacheRepository: HolidayEventCacheRepositoryProtocol
    private let localizer: HolidayNameLocalizer

    /// 使用缓存仓库初始化（ICS 订阅模式）
    init(cacheRepository: HolidayEventCacheRepositoryProtocol = HolidayEventCacheRepository()) {
        self.holidayProvider = nil
        self.cacheRepository = cacheRepository
        self.localizer = HolidayNameLocalizer()
    }

    /// 使用提供者初始化（向后兼容，用于测试）
    init(holidayProvider: HolidayProviding, cacheRepository: HolidayEventCacheRepositoryProtocol = HolidayEventCacheRepository()) {
        self.holidayProvider = holidayProvider
        self.cacheRepository = cacheRepository
        self.localizer = HolidayNameLocalizer()
    }

    func holidays(region: HolidayRegion, from: DateOnly, to: DateOnly) async throws -> [Holiday] {
        // 优先从缓存读取
        let cachedEvents = cacheRepository.getEvents(in: from...to, for: [region])

        // 将 HolidayEvent 转换为 Holiday
        var holidays: [Holiday] = []
        for event in cachedEvents {
            let displayName = localizer.localizedDisplayName(for: event.name, in: event.region)
            holidays.append(
                Holiday(
                    id: event.id,
                    region: event.region,
                    date: event.date,
                    localizedNames: LocalizedText(region: event.region, displayName: displayName),
                    type: holidayType(from: event.type),
                    isObserved: true
                )
            )
        }

        // 如果缓存没有数据，尝试从 BundleHolidayProvider 读取
        if holidays.isEmpty, let provider = holidayProvider {
            do {
                let bundleHolidays = try await provider.holidays(region: region, from: from, to: to)
                holidays.append(contentsOf: bundleHolidays)
            } catch {
                // 静默处理错误，继续返回空数组
            }
        }

        return holidays.sorted { $0.date < $1.date }
    }

    func holidays(regions: [HolidayRegion], from: DateOnly, to: DateOnly) async throws -> [Holiday] {
        // 优先从缓存读取
        let cachedEvents = cacheRepository.getEvents(in: from...to, for: regions)

        // 将 HolidayEvent 转换为 Holiday
        var holidays: [Holiday] = []
        for event in cachedEvents {
            let displayName = localizer.localizedDisplayName(for: event.name, in: event.region)
            holidays.append(
                Holiday(
                    id: event.id,
                    region: event.region,
                    date: event.date,
                    localizedNames: LocalizedText(region: event.region, displayName: displayName),
                    type: holidayType(from: event.type),
                    isObserved: true
                )
            )
        }

        // 如果缓存没有数据，尝试从 BundleHolidayProvider 读取
        if holidays.isEmpty, let provider = holidayProvider {
            for region in regions {
                do {
                    let bundleHolidays = try await provider.holidays(region: region, from: from, to: to)
                    holidays.append(contentsOf: bundleHolidays)
                } catch {
                    // 静默处理错误，继续处理下一个地区
                }
            }
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
