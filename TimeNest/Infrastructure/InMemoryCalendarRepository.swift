import Foundation

actor InMemoryCalendarRepository: CalendarRepository {
    private var storage: [UUID: TimeNestCalendar]

    init(calendars: [TimeNestCalendar] = []) {
        storage = Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) })
    }

    func calendars() -> [TimeNestCalendar] {
        Array(storage.values)
    }

    func calendar(id: UUID) -> TimeNestCalendar? {
        storage[id]
    }

    func save(_ calendar: TimeNestCalendar) {
        storage[calendar.id] = calendar
    }

    func delete(id: UUID) {
        guard id != TimeNestCalendar.personalID else { return }
        storage.removeValue(forKey: id)
    }
}
