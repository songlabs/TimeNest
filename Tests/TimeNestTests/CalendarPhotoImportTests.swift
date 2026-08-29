import XCTest
@testable import TimeNest

final class CalendarPhotoImportTests: XCTestCase {
    private let calendarID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testSeptember2026AssignsMonthStartAndEndWithoutAdjacentMonthCells() throws {
        var observations = september2026DateObservations()
        observations.append(contentsOf: [
            observation("Previous 30 note", column: 0, row: 0, line: 0),
            observation("Previous 31 note", column: 1, row: 0, line: 0),
            observation("8:50-16:30 Opening", day: 1, line: 0),
            observation("Closing", day: 30, line: 0),
            observation("Next 1 note", column: 4, row: 4, line: 0),
            observation("Next 2 note", column: 5, row: 4, line: 0),
            observation("Next 3 note", column: 6, row: 4, line: 0)
        ])

        let result = try CalendarPhotoParser().parse(
            observations: observations,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        XCTAssertEqual(result.yearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(result.candidates.map(\.title), ["Opening", "Closing"])
        XCTAssertEqual(dateComponents(result.candidates[0].date), DateComponents(year: 2026, month: 9, day: 1))
        XCTAssertEqual(dateComponents(result.candidates[1].date), DateComponents(year: 2026, month: 9, day: 30))
        XCTAssertFalse(result.candidates.contains { $0.title.contains("Previous") })
        XCTAssertFalse(result.candidates.contains { $0.title.contains("Next") })
    }

    func testTimeParserSupportsRangesSingleTimeJapaneseAndInvalidText() {
        XCTAssertEqual(
            CalendarImportTimeParser.parse("8:50-16:30"),
            CalendarImportParsedTime(startMinutes: 8 * 60 + 50, endMinutes: 16 * 60 + 30)
        )
        XCTAssertEqual(
            CalendarImportTimeParser.parse("17:30～20:30"),
            CalendarImportParsedTime(startMinutes: 17 * 60 + 30, endMinutes: 20 * 60 + 30)
        )
        XCTAssertEqual(
            CalendarImportTimeParser.parse("10:00"),
            CalendarImportParsedTime(startMinutes: 10 * 60, endMinutes: nil)
        )
        XCTAssertEqual(
            CalendarImportTimeParser.parse("17時30分"),
            CalendarImportParsedTime(startMinutes: 17 * 60 + 30, endMinutes: nil)
        )
        XCTAssertNil(CalendarImportTimeParser.parse("25:90 Meeting"))
        XCTAssertNil(CalendarImportTimeParser.parse("No time"))
    }

    func testSingleTimeCandidateRequiresReviewAndDoesNotGuessEndTime() throws {
        var observations = september2026DateObservations()
        observations.append(observation("10:00 Appointment", day: 12, line: 0))

        let result = try CalendarPhotoParser().parse(
            observations: observations,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )
        let candidate = try XCTUnwrap(result.candidates.first)

        XCTAssertEqual(candidate.startTimeMinutes, 10 * 60)
        XCTAssertNil(candidate.endTimeMinutes)
        XCTAssertTrue(candidate.needsReview)
        XCTAssertFalse(candidate.isValidForSaving)
    }

    func testCellAssignmentUsesObservationPosition() {
        let regions = [
            CalendarImportDayRegion(
                day: 3,
                boundingBox: CalendarOCRBoundingBox(x: 0.0, y: 0.5, width: 0.2, height: 0.2)
            ),
            CalendarImportDayRegion(
                day: 4,
                boundingBox: CalendarOCRBoundingBox(x: 0.2, y: 0.5, width: 0.2, height: 0.2)
            )
        ]
        let content = CalendarOCRObservation(
            text: "Meeting",
            confidence: 0.95,
            boundingBox: CalendarOCRBoundingBox(x: 0.23, y: 0.56, width: 0.12, height: 0.03)
        )

        XCTAssertEqual(CalendarPhotoParser.day(for: content, in: regions), 4)
    }

    func testMultipleEventsAndPersonMarkersRemainIndependentCandidates() throws {
        var observations = september2026DateObservations()
        observations.append(contentsOf: [
            observation("○ち 8:50-16:30 Clinic", day: 8, line: 0),
            observation("○と 17:30～20:30 Class", day: 8, line: 1),
            observation("○う Dinner", day: 9, line: 0)
        ])

        let result = try CalendarPhotoParser().parse(
            observations: observations,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        XCTAssertEqual(result.candidates.count, 3)
        let dayEight = result.candidates.filter {
            dateComponents($0.date).day == 8
        }
        XCTAssertEqual(dayEight.count, 2)
        XCTAssertEqual(Set(dayEight.compactMap(\.personToken)), Set(["○ち", "○と"]))
        XCTAssertTrue(dayEight.allSatisfy(\.includesPersonTokenInTitle))
        XCTAssertTrue(result.candidates.allSatisfy(\.needsReview))
        XCTAssertEqual(
            result.candidates.first { $0.personToken == "○う" }?.title,
            "Dinner"
        )
    }

    func testMissingYearMonthRequiresExplicitSelectionBeforeCandidates() throws {
        var observations = september2026DateObservations(includeHeader: false)
        observations.append(observation("Meeting", day: 1, line: 0))

        let result = try CalendarPhotoParser().parse(
            observations: observations,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        XCTAssertTrue(result.requiresYearMonthSelection)
        XCTAssertNil(result.yearMonth)
        XCTAssertTrue(result.candidates.isEmpty)

        let reparsed = try CalendarPhotoParser().parse(
            observations: observations,
            overridingYearMonth: CalendarImportYearMonth(year: 2026, month: 9),
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(reparsed.candidates.map(\.title), ["Meeting"])
    }

    func testLargeStandaloneMonthNumberPairsWithIndependentYear() throws {
        var observations = september2026DateObservations(includeHeader: false)
        observations.append(contentsOf: [
            CalendarOCRObservation(
                text: "9",
                confidence: 0.99,
                boundingBox: CalendarOCRBoundingBox(x: 0.05, y: 0.91, width: 0.08, height: 0.10)
            ),
            CalendarOCRObservation(
                text: "2026",
                confidence: 0.99,
                boundingBox: CalendarOCRBoundingBox(x: 0.16, y: 0.94, width: 0.10, height: 0.035)
            ),
            CalendarOCRObservation(
                text: "SEPTEM8ER",
                confidence: 0.82,
                boundingBox: CalendarOCRBoundingBox(x: 0.16, y: 0.90, width: 0.18, height: 0.03)
            ),
            observation("8:50-16:30 Work", day: 6, line: 0)
        ])

        let result = try CalendarPhotoParser().parse(
            observations: observations,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        XCTAssertEqual(result.yearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(result.candidates.map(\.title), ["Work"])
        XCTAssertEqual(
            dateComponents(try XCTUnwrap(result.candidates.first).date),
            DateComponents(year: 2026, month: 9, day: 6)
        )
    }

    func testOrdinaryDateNumbersDoNotGuessMonth() throws {
        var observations = september2026DateObservations(includeHeader: false)
        observations.append(contentsOf: [
            CalendarOCRObservation(
                text: "2026",
                confidence: 0.99,
                boundingBox: CalendarOCRBoundingBox(x: 0.16, y: 0.94, width: 0.10, height: 0.035)
            ),
            observation("Meeting", day: 9, line: 0)
        ])

        let result = try CalendarPhotoParser().parse(
            observations: observations,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        XCTAssertNil(result.yearMonth)
        XCTAssertTrue(result.candidates.isEmpty)
    }

    func testDirectionSelectorCorrectsEveryQuarterTurn() throws {
        var upright = september2026DateObservations()
        upright.append(observation("Meeting", day: 9, line: 0))
        let selector = CalendarPhotoOrientationSelector()

        for sourceRotation in CalendarPhotoRotation.allCases {
            let candidates = CalendarPhotoRotation.allCases.map { appliedRotation in
                CalendarPhotoOrientationCandidate(
                    rotation: appliedRotation,
                    observations: rotatedObservations(
                        upright,
                        by: combinedRotation(sourceRotation, appliedRotation)
                    )
                )
            }
            let selection = try XCTUnwrap(selector.selectBest(
                from: candidates,
                calendar: utcGregorianCalendar()
            ))

            XCTAssertEqual(
                selection.rotation,
                inverseRotation(sourceRotation),
                "Failed to correct source rotation \(sourceRotation.rawValue)"
            )
            XCTAssertEqual(
                selection.evidence.yearMonth,
                CalendarImportYearMonth(year: 2026, month: 9)
            )
            XCTAssertEqual(selection.evidence.columnCount, 7)
            XCTAssertEqual(selection.evidence.rowCount, 5)
            XCTAssertEqual(selection.evidence.matchedDateAnchorCount, 30)
        }
    }

    func testRotatedLayoutOnlyFormsSevenColumnGridAfterCorrection() throws {
        let upright = september2026DateObservations()
        let sideways = rotatedObservations(upright, by: .degrees90)
        let parser = CalendarPhotoParser()
        let sidewaysEvidence = parser.orientationEvidence(
            observations: sideways,
            calendar: utcGregorianCalendar()
        )
        let correctedEvidence = parser.orientationEvidence(
            observations: rotatedObservations(sideways, by: .degrees270),
            calendar: utcGregorianCalendar()
        )

        XCTAssertFalse(sidewaysEvidence.hasReliableCalendarStructure)
        XCTAssertEqual(
            correctedEvidence.yearMonth,
            CalendarImportYearMonth(year: 2026, month: 9)
        )
        XCTAssertTrue(correctedEvidence.hasReliableCalendarStructure)
        XCTAssertEqual(correctedEvidence.columnCount, 7)
        XCTAssertEqual(correctedEvidence.rowCount, 5)
        XCTAssertEqual(correctedEvidence.matchedDateAnchorCount, 30)
    }

    func testManualYearMonthParsesSelectedCorrectedObservations() throws {
        var upright = september2026DateObservations(includeHeader: false)
        upright.append(observation("Meeting", day: 12, line: 0))
        let sourceRotation = CalendarPhotoRotation.degrees90
        let candidates = CalendarPhotoRotation.allCases.map { appliedRotation in
            CalendarPhotoOrientationCandidate(
                rotation: appliedRotation,
                observations: rotatedObservations(
                    upright,
                    by: combinedRotation(sourceRotation, appliedRotation)
                )
            )
        }
        let selection = try XCTUnwrap(CalendarPhotoOrientationSelector().selectBest(
            from: candidates,
            calendar: utcGregorianCalendar()
        ))

        XCTAssertEqual(selection.rotation, .degrees270)
        XCTAssertNil(selection.evidence.yearMonth)
        XCTAssertTrue(selection.evidence.hasReliableCalendarStructure)

        let result = try CalendarPhotoParser().parse(
            observations: selection.observations,
            overridingYearMonth: CalendarImportYearMonth(year: 2026, month: 9),
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )
        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.title, "Meeting")
        XCTAssertEqual(
            dateComponents(candidate.date),
            DateComponents(year: 2026, month: 9, day: 12)
        )
    }

    func testMissingDatesAndEmptyOCRFailSafely() {
        XCTAssertThrowsError(try CalendarPhotoParser().parse(
            observations: [],
            defaultCalendarID: calendarID
        )) { error in
            XCTAssertEqual(error as? CalendarPhotoImportParseError, .noText)
        }

        XCTAssertThrowsError(try CalendarPhotoParser().parse(
            observations: [CalendarOCRObservation(
                text: "2026 SEPTEMBER Meeting",
                confidence: 0.98,
                boundingBox: CalendarOCRBoundingBox(x: 0.1, y: 0.9, width: 0.5, height: 0.05)
            )],
            defaultCalendarID: calendarID
        )) { error in
            XCTAssertEqual(error as? CalendarPhotoImportParseError, .noDateStructure)
        }
    }

    private func september2026DateObservations(
        includeHeader: Bool = true
    ) -> [CalendarOCRObservation] {
        var observations: [CalendarOCRObservation] = []
        if includeHeader {
            observations.append(CalendarOCRObservation(
                text: "2026 SEPTEMBER",
                confidence: 0.99,
                boundingBox: CalendarOCRBoundingBox(x: 0.25, y: 0.93, width: 0.5, height: 0.04)
            ))
        }

        // September 1, 2026 is Tuesday in a Sunday-first grid.
        observations.append(observation("30", column: 0, row: 0, line: -1))
        observations.append(observation("31", column: 1, row: 0, line: -1))
        for day in 1...30 {
            let index = 2 + day - 1
            observations.append(observation(
                "\(day)",
                column: index % 7,
                row: index / 7,
                line: -1
            ))
        }
        for (offset, nextMonthDay) in (1...3).enumerated() {
            observations.append(observation(
                "\(nextMonthDay)",
                column: 4 + offset,
                row: 4,
                line: -1
            ))
        }
        return observations
    }

    private func observation(
        _ text: String,
        day: Int,
        line: Int
    ) -> CalendarOCRObservation {
        let index = 2 + day - 1
        return observation(text, column: index % 7, row: index / 7, line: line)
    }

    private func observation(
        _ text: String,
        column: Int,
        row: Int,
        line: Int
    ) -> CalendarOCRObservation {
        let dateY = 0.80 - Double(row) * 0.15
        let y: Double
        if line < 0 {
            y = dateY
        } else {
            y = dateY - 0.045 - Double(line) * 0.04
        }
        return CalendarOCRObservation(
            text: text,
            confidence: 0.94,
            boundingBox: CalendarOCRBoundingBox(
                x: 0.055 + Double(column) * 0.13,
                y: y,
                width: line < 0 ? 0.03 : 0.10,
                height: 0.025
            )
        )
    }

    private func rotatedObservations(
        _ observations: [CalendarOCRObservation],
        by rotation: CalendarPhotoRotation
    ) -> [CalendarOCRObservation] {
        observations.map { observation in
            CalendarOCRObservation(
                text: observation.text,
                confidence: observation.confidence,
                boundingBox: rotatedBoundingBox(observation.boundingBox, by: rotation)
            )
        }
    }

    private func rotatedBoundingBox(
        _ box: CalendarOCRBoundingBox,
        by rotation: CalendarPhotoRotation
    ) -> CalendarOCRBoundingBox {
        switch rotation {
        case .degrees0:
            return box
        case .degrees90:
            return CalendarOCRBoundingBox(
                x: box.minY,
                y: 1 - box.maxX,
                width: box.height,
                height: box.width
            )
        case .degrees180:
            return CalendarOCRBoundingBox(
                x: 1 - box.maxX,
                y: 1 - box.maxY,
                width: box.width,
                height: box.height
            )
        case .degrees270:
            return CalendarOCRBoundingBox(
                x: 1 - box.maxY,
                y: box.minX,
                width: box.height,
                height: box.width
            )
        }
    }

    private func combinedRotation(
        _ lhs: CalendarPhotoRotation,
        _ rhs: CalendarPhotoRotation
    ) -> CalendarPhotoRotation {
        CalendarPhotoRotation(rawValue: (lhs.rawValue + rhs.rawValue) % 360)!
    }

    private func inverseRotation(
        _ rotation: CalendarPhotoRotation
    ) -> CalendarPhotoRotation {
        CalendarPhotoRotation(rawValue: (360 - rotation.rawValue) % 360)!
    }

    private func utcGregorianCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func dateComponents(_ date: Date) -> DateComponents {
        utcGregorianCalendar().dateComponents([.year, .month, .day], from: date)
    }
}
