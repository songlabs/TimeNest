import Foundation
import WidgetKit

@MainActor
final class WidgetSnapshotCoordinator {
    private let builder: WidgetSnapshotBuilder
    private var refreshTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init(builder: WidgetSnapshotBuilder) {
        self.builder = builder
        observeSnapshotInputs()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    func refresh() async {
        do {
            let snapshot = try await builder.build()
            try WidgetSnapshotStore.save(snapshot)
            Self.widgetKinds.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0) }
        } catch {
            // Widget snapshots are best-effort; the app must remain usable if refresh fails.
        }
    }

    private func observeSnapshotInputs() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .holidaySubscriptionsDidChange,
            .holidayEventsDidUpdate,
            .timeNestDataDidRestore,
            UserDefaults.didChangeNotification
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.scheduleRefresh() }
            }
        }
    }

    private static let widgetKinds = [
        "TimeNestMonthWidget",
        "TimeNestMonthScheduleWidget",
        "TimeNestTwoMonthsWidget",
        "TimeNestWeekScheduleWidget",
        "TimeNestUpcomingWidget",
        "TimeNestAccessoryWidget"
    ]
}
