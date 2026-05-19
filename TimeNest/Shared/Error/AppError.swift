import Foundation

enum AppError: Error, LocalizedError {
    case persistence
    case validation
    case permissionDenied
    case notification
    case holidayData
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .persistence:
            return "持久化操作失败"
        case .validation:
            return "验证失败"
        case .permissionDenied:
            return "权限被拒绝"
        case .notification:
            return "通知操作失败"
        case .holidayData:
            return "节假日数据获取失败"
        case .unknown:
            return "未知错误"
        }
    }
}
