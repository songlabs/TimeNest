import Foundation

struct Holiday: Identifiable, Hashable {
    let id: String
    let region: HolidayRegion
    let date: DateOnly
    let localizedNames: LocalizedText
    let type: HolidayType
    let isObserved: Bool
}
