import Foundation

struct ShiftTemplateFavoritesStore {
    static let storageKey = "shiftTemplate.favoriteIDs"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func favoriteIDs() -> [String] {
        defaults.stringArray(forKey: Self.storageKey) ?? []
    }

    func isFavorite(_ id: ShiftTimeTemplateID) -> Bool {
        favoriteIDs().contains(id.id)
    }

    @discardableResult
    func setFavorite(_ isFavorite: Bool, id: ShiftTimeTemplateID) -> [String] {
        var ids = favoriteIDs()
        ids.removeAll { $0 == id.id }
        if isFavorite {
            ids.append(id.id)
        }
        defaults.set(ids, forKey: Self.storageKey)
        return ids
    }

    @discardableResult
    func reconcile(validTemplateIDs: [ShiftTimeTemplateID]) -> [String] {
        let validIDs = Set(validTemplateIDs.map(\.id))
        let cleaned = favoriteIDs().filter(validIDs.contains)
        if cleaned != favoriteIDs() {
            defaults.set(cleaned, forKey: Self.storageKey)
        }
        return cleaned
    }
}
