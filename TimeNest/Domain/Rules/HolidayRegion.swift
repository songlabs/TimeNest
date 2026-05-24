import Foundation

enum HolidayRegion: String, Codable, Hashable, CaseIterable, Identifiable {
    case japan
    case china
    case korea
    case unitedStates
    
    var id: String { rawValue }
    
    var localizedKey: String {
        switch self {
        case .japan: return "region.japan"
        case .china: return "region.china"
        case .korea: return "region.korea"
        case .unitedStates: return "region.united_states"
        }
    }
}
