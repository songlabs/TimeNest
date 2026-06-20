import SwiftUI
import WidgetKit

@main
struct TimeNestWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimeNestMonthWidget()
        TimeNestMonthScheduleWidget()
        TimeNestTwoMonthsWidget()
        TimeNestWeekScheduleWidget()
        TimeNestUpcomingWidget()
        TimeNestAccessoryWidget()
    }
}
