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
            return LocalizationManager.shared.localized(.appErrorPersistence)
        case .validation:
            return LocalizationManager.shared.localized(.appErrorValidation)
        case .permissionDenied:
            return LocalizationManager.shared.localized(.appErrorPermissionDenied)
        case .notification:
            return LocalizationManager.shared.localized(.appErrorNotification)
        case .holidayData:
            return LocalizationManager.shared.localized(.appErrorHolidayData)
        case .unknown:
            return LocalizationManager.shared.localized(.appErrorUnknown)
        }
    }
}
