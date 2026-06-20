import SwiftUI

struct WidgetMonthGridView: View {
    let snapshot: WidgetSnapshot
    let month: WidgetSnapshotMonth
    let referenceDate: Date
    var showsEventLabel = false
    var compact = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(spacing: compact ? 2 : 4) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(snapshot.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: compact ? 8 : 10, weight: .semibold))
                        .foregroundStyle(headerColor(at: index))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: compact ? 1 : 3) {
                ForEach(month.days) { day in
                    Link(destination: TimeNestWidgetDeepLink.url(for: day.date)!) {
                        dayCell(day)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: WidgetSnapshotDay) -> some View {
        VStack(spacing: compact ? 0 : 1) {
            ZStack {
                if isToday(day.date) {
                    Circle().fill(WidgetStyle.today)
                }
                Text("\(day.day)")
                    .font(.system(size: compact ? 9 : 12, weight: isToday(day.date) ? .semibold : .regular))
                    .foregroundStyle(dayTextColor(day))
                    .minimumScaleFactor(0.7)
            }
            .frame(width: compact ? 18 : 23, height: compact ? 18 : 23)

            if showsEventLabel, let event = day.events.first {
                WidgetEventTag(event: event)
            } else {
                HStack(spacing: 2) {
                    ForEach(Array(day.events.prefix(2))) { event in
                        Circle()
                            .fill(Color(widgetHex: event.colorHex))
                            .frame(width: compact ? 2.5 : 3.5, height: compact ? 2.5 : 3.5)
                    }
                }
                .frame(height: compact ? 3 : 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: showsEventLabel ? (compact ? 28 : 34) : (compact ? 21 : 28), alignment: .top)
        .opacity(day.isInDisplayedMonth ? 1 : 0.32)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar(identifier: .gregorian).isDate(date, inSameDayAs: referenceDate)
    }

    private func dayTextColor(_ day: WidgetSnapshotDay) -> Color {
        if isToday(day.date) { return .white }
        return WidgetStyle.weekdayColor(day.weekday)
    }

    private func headerColor(at index: Int) -> Color {
        guard let firstDay = month.days.first, month.days.count >= 7 else { return .secondary }
        return WidgetStyle.weekdayColor(month.days[index].weekday)
    }
}

struct WidgetMonthHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline.weight(.bold))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
