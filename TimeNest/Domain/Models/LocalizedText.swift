import Foundation

struct LocalizedText: Codable, Hashable {
    let zhHans: String
    let ja: String
    let ko: String
    let enUS: String
    
    func localized(for language: DisplayLanguage) -> String {
        switch language {
        case .system:
            return zhHans
        case .zhHans:
            return zhHans
        case .ja:
            return ja
        case .ko:
            return ko
        case .enUS:
            return enUS
        }
    }
}
