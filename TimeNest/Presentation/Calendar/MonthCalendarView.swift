import SwiftUI

struct MonthCalendarView: View {
    @StateObject private var viewModel: MonthCalendarViewModel

    init(calendarDisplayUseCase: CalendarDisplayUseCase, eventUseCase: EventUseCase) {
        _viewModel = StateObject(
            wrappedValue: MonthCalendarViewModel(
                calendarDisplayUseCase: calendarDisplayUseCase,
                eventUseCase: eventUseCase
            )
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            headerSection

            weekdaySymbolsSection

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
            } else if let grid = viewModel.grid {
                monthGridSection(grid)
            } else {
                EmptyView()
            }
        }
        .padding()
        .onAppear {
            Task {
                await viewModel.reloadMonth()
            }
        }
        .sheet(isPresented: $viewModel.showingEventEditor) {
            EventEditorView(
                isPresented: $viewModel.showingEventEditor,
                mode: .create(initialDate: Date()),
                onSave: { title, date, isAllDay in
                    try await viewModel.createEvent(
                        title: title,
                        date: date,
                        isAllDay: isAllDay
                    )
                }
            )
        }
        .sheet(isPresented: $viewModel.showingDayDetail) {
            if let cell = viewModel.selectedDayCell {
                DayDetailView(
                    cell: cell,
                    onDeleteEvent: { eventID in
                        Task {
                            await viewModel.deleteEvent(id: eventID)
                        }
                    },
                    onUpdateEvent: { eventID, title, date, isAllDay in
                        await viewModel.updateEvent(
                            id: eventID,
                            title: title,
                            date: date,
                            isAllDay: isAllDay
                        )
                    }
                )
            }
        }
    }

    private var headerSection: some View {
        HStack {
            Button(action: {
                Task {
                    await viewModel.goToPreviousMonth()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            if let grid = viewModel.grid {
                Text(grid.title)
                    .font(.title)
                    .fontWeight(.semibold)
            }

            Spacer()

            Button(action: {
                Task {
                    await viewModel.goToNextMonth()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }

            Button(action: {
                viewModel.showingEventEditor = true
            }) {
                Image(systemName: "plus")
                    .font(.title3)
            }
        }
    }

    private var todayButtonSection: some View {
        Button(action: {
            Task {
                await viewModel.goToToday()
            }
        }) {
            Text("Today")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
        }
    }

    private var weekdaySymbolsSection: some View {
        Group {
            if let grid = viewModel.grid {
                HStack(spacing: 0) {
                    ForEach(grid.weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .frame(maxWidth: .infinity)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func monthGridSection(_ grid: MonthGrid) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(grid.days) { cell in
                DayCellView(cell: cell)
                    .onTapGesture {
                        viewModel.selectDay(cell)
                    }
            }
        }
    }
}

struct DayCellView: View {
    let cell: CalendarDayCell

    var body: some View {
        VStack(spacing: 2) {
            Text(cell.dayText)
                .font(.body)
                .fontWeight(cell.isToday ? .bold : .regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(cell.isToday ? Color.blue : Color.gray.opacity(0.1))
                )
                .foregroundColor(cell.isToday ? .white : .primary)

            if !cell.events.isEmpty {
                Text("\(cell.events.count)")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
            } else if !cell.holidays.isEmpty {
                Text(holidayName(cell.holidays.first!))
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .opacity(cell.isInCurrentMonth ? 1.0 : 0.4)
    }

    private func holidayName(_ holiday: Holiday) -> String {
        holiday.localizedNames.localized(for: .zhHans)
    }
}

