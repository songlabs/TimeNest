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
        return mapping[normalizedKey] ?? cleanName
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

    /// 节假日名称本地化映射表
    /// 键：标准化后的英文名称（去掉前缀、apostrophe、空格、转小写）
    /// 值：对应地区语言的显示名称
    private var localizedMappings: [HolidayRegion: [String: String]] {
        [
            .japan: [
                // 2026 年 5 月
                "greenery day": "みどりの日",
                "constitution memorial day": "憲法記念日",
                "childrens day": "こどもの日",
                "substitute holiday": "振替休日",
                // 其他日本节假日
                "new years day": "元日",
                "coming of age day": "成人の日",
                "national foundation day": "建国記念の日",
                "emperors birthday": "天皇誕生日",
                "vernal equinox day": "春分の日",
                "showa day": "昭和の日",
                "marine day": "海の日",
                "mountain day": "山の日",
                "respect for the aged day": "敬老の日",
                "autumnal equinox day": "秋分の日",
                "sports day": "スポーツの日",
                "culture day": "文化の日",
                "thanksgiving day": "勤労感謝の日"
            ],
            .china: [
                // 2026 年 5 月
                "labor day": "劳动节",
                "youth day": "青年节",
                // 其他中国节假日
                "new years day": "元旦",
                "spring festival": "春节",
                "lantern festival": "元宵节",
                "qingming festival": "清明节",
                "dragon boat festival": "端午节",
                "mid-autumn festival": "中秋节",
                "national day": "国庆节"
            ],
            .korea: [
                // 2026 年 5 月
                "childrens day": "어린이날",
                "buddhas birthday": "부처님 오신 날",
                // 其他韩国节假日
                "new years day": "새해",
                "lunar new year": "설날",
                "independence movement day": "3·1절",
                "constitution day": "제헌절",
                "victory day": "광복절",
                "chuseok": "추석",
                "hangul day": "한글날"
            ],
            .unitedStates: [
                // 美国节假日保持英文
                "new years day": "New Year's Day",
                "martin luther king jr day": "Martin Luther King Jr. Day",
                "presidents day": "Presidents' Day",
                "memorial day": "Memorial Day",
                "independence day": "Independence Day",
                "labor day": "Labor Day",
                "columbus day": "Columbus Day",
                "halloween": "Halloween",
                "veterans day": "Veterans Day",
                "thanksgiving": "Thanksgiving",
                "christmas": "Christmas"
            ]
        ]
    }
}
