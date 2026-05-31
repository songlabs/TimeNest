import Foundation

/// 节假日名称本地化映射器
/// 将 ICS 中的英文节假日名称映射到对应国家/地区的本地语言名称
struct HolidayNameLocalizer {

    // MARK: - Public

    /// 获取节假日的本地化显示名称
    /// - Parameters:
    ///   - rawName: ICS 中的原始名称（可能包含地区前缀）
    ///   - region: 节假日所属地区
    /// - Returns: 对应地区语言的显示名称，如果映射不到则返回清理前缀后的名称
    func localizedDisplayName(for rawName: String, in region: HolidayRegion) -> String {
        let cleanName = cleanRegionPrefix(from: rawName, region: region)
        let normalizedKey = normalizeName(cleanName)

        let mapping = localizedMappings[region] ?? [:]

        // 先尝试精确匹配
        if let directMatch = mapping[normalizedKey] {
            return directMatch
        }

        // 尝试去掉尾部数字变体后匹配（如 "Labour Day Holiday 2" -> "Labour Day Holiday"）
        let baseKey = extractBaseKey(from: normalizedKey)
        if baseKey != normalizedKey, let baseMatch = mapping[baseKey] {
            return baseMatch
        }

        return cleanName
    }

    // MARK: - Private

    /// 清理地区前缀
    private func cleanRegionPrefix(from name: String, region: HolidayRegion) -> String {
        let prefixesToCheck: [String]
        switch region {
        case .japan:
            prefixesToCheck = ["Japan:", "Japan : ", "Japan: ", "日本:", "日本：", "JP:", "JP: "]
        case .china:
            prefixesToCheck = ["China:", "China : ", "China: ", "中国:", "中国：", "CN:", "CN: "]
        case .korea:
            prefixesToCheck = ["Korea:", "Korea : ", "Korea: ", "韩国:", "韩国：", "KR:", "KR: "]
        case .unitedStates:
            prefixesToCheck = ["US:", "US : ", "US: ", "USA:", "USA : ", "USA: ", "United States:", "United States: ", "美国:", "美国：", "US: "]
        }

        var cleaned = name
        for prefix in prefixesToCheck {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        return cleaned.isEmpty ? name : cleaned
    }

    /// 标准化名称用于映射查找
    private func normalizeName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "'", with: "")  // 去掉 apostrophe
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// 提取标准化键（去掉尾部数字变体）
    /// 例如："labour day holiday 2" -> "labour day holiday"
    private func extractBaseKey(from normalizedName: String) -> String {
        let pattern = #"^(.+?)\s+\d+$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalizedName, range: NSRange(normalizedName.startIndex..., in: normalizedName)),
              match.numberOfRanges == 2,
              let baseRange = Range(match.range(at: 1), in: normalizedName) else {
            return normalizedName
        }
        return String(normalizedName[baseRange])
    }

    // MARK: - China Holiday Mappings

    /// 中国节假日别名定义
    /// 使用别名数组生成映射表，避免 Dictionary literal 中重复 key 导致运行时崩溃
    private struct ChinaHoliday {
        let canonicalName: String
        let aliases: [String]
    }

    private static let chinaHolidays: [ChinaHoliday] = [
        // 春节相关
        ChinaHoliday(canonicalName: "春节", aliases: [
            "spring festival", "spring festival holiday", "spring festival holiday 1",
            "spring festival holiday 2", "spring festival holiday 3", "spring festival holiday 4",
            "spring festival holiday 5", "chinese new year", "chinese new year holiday",
            "lunar new year", "lunar new year holiday"
        ]),
        // 清明节相关
        ChinaHoliday(canonicalName: "清明节", aliases: [
            "qingming festival", "ching ming festival", "qing ming festival",
            "tomb sweeping day", "tomb-sweeping day", "ching ming festival holiday",
            "qingming festival holiday"
        ]),
        // 劳动节相关
        ChinaHoliday(canonicalName: "劳动节", aliases: [
            "labor day", "labour day", "labour day holiday", "labor day holiday",
            "labour day holiday 1", "labour day holiday 2", "labour day holiday 3",
            "labor day holiday 1", "labor day holiday 2", "labor day holiday 3",
            "international workers day", "workers day", "international workers' day",
            "workers' day"
        ]),
        // 端午节相关
        ChinaHoliday(canonicalName: "端午节", aliases: [
            "dragon boat festival", "dragon boat festival holiday", "tuen ng festival",
            "tuen ng festival holiday"
        ]),
        // 中秋节相关
        ChinaHoliday(canonicalName: "中秋节", aliases: [
            "mid-autumn festival", "mid autumn festival", "mid-autumn festival holiday",
            "mid autumn festival holiday", "moon festival"
        ]),
        // 国庆节相关
        ChinaHoliday(canonicalName: "国庆节", aliases: [
            "national day", "chinese national day", "national day holiday",
            "national day holiday 1", "national day holiday 2", "national day holiday 3",
            "golden week holiday", "golden week"
        ]),
        // 元旦相关
        ChinaHoliday(canonicalName: "元旦", aliases: [
            "new years day", "new year holiday", "new year's day"
        ]),
        // 其他中国节假日
        ChinaHoliday(canonicalName: "青年节", aliases: ["youth day"]),
        ChinaHoliday(canonicalName: "元宵节", aliases: ["lantern festival"])
    ]

    private func buildChinaMappings() -> [String: String] {
        var dict: [String: String] = [:]
        for holiday in HolidayNameLocalizer.chinaHolidays {
            for alias in holiday.aliases {
                let normalizedKey = alias.replacingOccurrences(of: "'", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                #if DEBUG
                if dict[normalizedKey] != nil {
                    assertionFailure("Duplicate alias detected for China holiday: \"\(normalizedKey)\" maps to \"\(holiday.canonicalName)\"")
                }
                #endif
                dict[normalizedKey] = holiday.canonicalName
            }
        }
        return dict
    }

    // MARK: - Japan Holiday Mappings

    private func buildJapanMappings() -> [String: String] {
        var dict: [String: String] = [:]
        let mappings: [(String, String)] = [
            // 2026 年 5 月
            ("greenery day", "みどりの日"),
            ("greenery day (in lieu)", "みどりの日 振替休日"),
            ("constitution memorial day", "憲法記念日"),
            ("constitution memorial day (in lieu)", "憲法記念日 振替休日"),
            ("childrens day", "こどもの日"),
            ("childrens day (in lieu)", "こどもの日 振替休日"),
            ("substitute holiday", "振替休日"),
            // 其他日本节假日
            ("new years day", "元日"),
            ("coming of age day", "成人の日"),
            ("national foundation day", "建国記念の日"),
            ("emperors birthday", "天皇誕生日"),
            ("vernal equinox day", "春分の日"),
            ("showa day", "昭和の日"),
            ("marine day", "海の日"),
            ("mountain day", "山の日"),
            ("respect for the aged day", "敬老の日"),
            ("autumnal equinox day", "秋分の日"),
            ("sports day", "スポーツの日"),
            ("culture day", "文化の日"),
            ("thanksgiving day", "勤労感謝の日")
        ]
        for (key, value) in mappings {
            let normalizedKey = key.lowercased()
            #if DEBUG
            if dict[normalizedKey] != nil {
                assertionFailure("Duplicate Japan holiday alias detected: \"\(normalizedKey)\" maps to \"\(value)\"")
            }
            #endif
            dict[normalizedKey] = value
        }
        return dict
    }

    // MARK: - Korea Holiday Mappings

    private func buildKoreaMappings() -> [String: String] {
        var dict: [String: String] = [:]
        let mappings: [(String, String)] = [
            // 2026 年 5 月
            ("childrens day", "어린이날"),
            ("buddhas birthday", "부처님 오신 날"),
            // 其他韩国节假日
            ("new years day", "새해"),
            ("lunar new year", "설날"),
            ("independence movement day", "3·1절"),
            ("constitution day", "제헌절"),
            ("victory day", "광복절"),
            ("chuseok", "추석"),
            ("hangul day", "한글날")
        ]
        for (key, value) in mappings {
            let normalizedKey = key.lowercased()
            #if DEBUG
            if dict[normalizedKey] != nil {
                assertionFailure("Duplicate Korea holiday alias detected: \"\(normalizedKey)\" maps to \"\(value)\"")
            }
            #endif
            dict[normalizedKey] = value
        }
        return dict
    }

    // MARK: - USA Holiday Mappings

    private func buildUSAMappings() -> [String: String] {
        var dict: [String: String] = [:]
        let mappings: [(String, String)] = [
            ("new years day", "New Year's Day"),
            ("martin luther king jr day", "Martin Luther King Jr. Day"),
            ("presidents day", "Presidents' Day"),
            ("memorial day", "Memorial Day"),
            ("independence day", "Independence Day"),
            ("labor day", "Labor Day"),
            ("columbus day", "Columbus Day"),
            ("halloween", "Halloween"),
            ("veterans day", "Veterans Day"),
            ("thanksgiving", "Thanksgiving"),
            ("christmas", "Christmas")
        ]
        for (key, value) in mappings {
            let normalizedKey = key.lowercased()
            #if DEBUG
            if dict[normalizedKey] != nil {
                assertionFailure("Duplicate USA holiday alias detected: \"\(normalizedKey)\" maps to \"\(value)\"")
            }
            #endif
            dict[normalizedKey] = value
        }
        return dict
    }

    /// 节假日名称本地化映射表
    /// 键：标准化后的英文名称（去掉前缀、apostrophe、空格、转小写）
    /// 值：对应地区语言的显示名称
    private var localizedMappings: [HolidayRegion: [String: String]] {
        [
            .japan: buildJapanMappings(),
            .china: buildChinaMappings(),
            .korea: buildKoreaMappings(),
            .unitedStates: buildUSAMappings()
        ]
    }
}
