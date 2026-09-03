import Foundation

enum DisplayLanguage: String, Codable, Hashable, Sendable {
    case system
    case zhHans
    case zhHant = "zh-Hant"
    case ja
    case ko
    case enUS

    func resolved(systemLocale: Locale = .current) -> DisplayLanguage {
        guard self == .system else { return self }

        let languageCode = systemLocale.language.languageCode?.identifier.lowercased()
        switch languageCode {
        case "zh":
            let identifier = systemLocale.identifier.lowercased()
                .replacingOccurrences(of: "_", with: "-")
            let usesTraditionalChinese = identifier.contains("hant")
                || identifier.contains("-tw")
                || identifier.contains("-hk")
                || identifier.contains("-mo")
            return usesTraditionalChinese ? .zhHant : .zhHans
        case "ja":
            return .ja
        case "ko":
            return .ko
        case "en":
            return .enUS
        default:
            return .enUS
        }
    }
}

struct CalendarOCRLanguage: Equatable, Sendable {
    let appLanguage: DisplayLanguage
    let resolvedAppLanguage: DisplayLanguage
    let visionRecognitionLanguageCode: String

    static func resolve(
        appLanguage: DisplayLanguage,
        systemLocale: Locale = .current
    ) -> CalendarOCRLanguage {
        let resolvedLanguage = appLanguage.resolved(systemLocale: systemLocale)
        return CalendarOCRLanguage(
            appLanguage: appLanguage,
            resolvedAppLanguage: resolvedLanguage,
            visionRecognitionLanguageCode: visionLanguageCode(for: resolvedLanguage)
        )
    }

    func preferredVisionRecognitionLanguages(supported: [String]) -> [String] {
        let normalizedDesired = Self.normalized(visionRecognitionLanguageCode)
        if let exact = supported.first(where: {
            Self.normalized($0) == normalizedDesired
        }) {
            return [exact]
        }

        guard let compatible = supported.first(where: {
            Self.isCompatible($0, with: resolvedAppLanguage)
        }) else {
            return []
        }
        return [compatible]
    }

    private static func visionLanguageCode(for language: DisplayLanguage) -> String {
        switch language {
        case .ja:
            return "ja-JP"
        case .zhHans:
            return "zh-Hans"
        case .zhHant:
            return "zh-Hant"
        case .ko:
            return "ko-KR"
        case .enUS, .system:
            return "en-US"
        }
    }

    private static func isCompatible(
        _ supportedLanguage: String,
        with language: DisplayLanguage
    ) -> Bool {
        let value = normalized(supportedLanguage)
        switch language {
        case .zhHans:
            return value.contains("hans") || value == "zh-cn" || value == "zh-sg"
        case .zhHant:
            return value.contains("hant") || value == "zh-tw"
                || value == "zh-hk" || value == "zh-mo"
        case .ja:
            return value == "ja" || value.hasPrefix("ja-")
        case .ko:
            return value == "ko" || value.hasPrefix("ko-")
        case .enUS:
            return value == "en" || value.hasPrefix("en-")
        case .system:
            return false
        }
    }

    private static func normalized(_ languageCode: String) -> String {
        languageCode.lowercased().replacingOccurrences(of: "_", with: "-")
    }
}

enum CalendarOCRLanguageError: Error, Equatable {
    case unsupportedByVision(String)
}
