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
        var missingYearMonthDiagnostics: CalendarPhotoImportDiagnostics?

        let result = try CalendarPhotoParser().parse(
            observations: observations,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { missingYearMonthDiagnostics = $0 }
        )

        XCTAssertTrue(result.requiresYearMonthSelection)
        XCTAssertNil(result.yearMonth)
        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertNil(missingYearMonthDiagnostics?.manualYearMonth)
        XCTAssertNil(missingYearMonthDiagnostics?.resolvedYearMonth)
        XCTAssertEqual(missingYearMonthDiagnostics?.parseStage, .yearMonth)
        XCTAssertEqual(missingYearMonthDiagnostics?.failureReason, .missingYearMonth)
        XCTAssertTrue(missingYearMonthDiagnostics?.shouldDisplay == true)

        var diagnostics: CalendarPhotoImportDiagnostics?
        let reparsed = try CalendarPhotoParser().parse(
            observations: observations,
            overridingYearMonth: CalendarImportYearMonth(year: 2026, month: 9),
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )
        XCTAssertEqual(reparsed.yearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(reparsed.dayRegions.count, 30)
        XCTAssertEqual(reparsed.candidates.map(\.title), ["Meeting"])
        XCTAssertEqual(diagnostics?.manualYearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(diagnostics?.resolvedYearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(diagnostics?.parseStage, .completed)
        XCTAssertEqual(diagnostics?.gridAccepted, true)
        XCTAssertEqual(diagnostics?.gridColumnCount, 7)
        XCTAssertEqual(diagnostics?.gridRowCount, 5)
        XCTAssertEqual(diagnostics?.dayRegionCount, 30)
        XCTAssertEqual(diagnostics?.candidateCount, 1)
        XCTAssertNil(diagnostics?.failureReason)
        XCTAssertFalse(diagnostics?.shouldDisplay == true)
    }

    func testDiagnosticsPlainTextContainsOnlyStructuralValues() throws {
        var observations = september2026DateObservations(includeHeader: false)
        observations.append(contentsOf: [
            observation("Private Person Appointment", day: 12, line: 0),
            observation("○秘 9:00 Candidate Secret", day: 13, line: 0)
        ])
        var diagnostics: CalendarPhotoImportDiagnostics?

        _ = try CalendarPhotoParser().parse(
            observations: observations,
            overridingYearMonth: CalendarImportYearMonth(year: 2026, month: 9),
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )

        let text = try XCTUnwrap(diagnostics).plainText
        XCTAssertTrue(text.hasPrefix("CalendarImportDiagnostics\n"))
        XCTAssertTrue(text.contains("manualYearMonth=2026-09"))
        XCTAssertTrue(text.contains("resolvedYearMonth=2026-09"))
        XCTAssertTrue(text.contains("gridAccepted=true"))
        XCTAssertTrue(text.contains("stage=completed"))
        XCTAssertTrue(text.contains("failure=none"))
        XCTAssertTrue(text.contains("[Orientations]\nnone"))
        XCTAssertTrue(text.contains("[Anchors]"))
        XCTAssertTrue(text.contains("[AnchorMapping]"))
        XCTAssertFalse(text.contains("Private Person Appointment"))
        XCTAssertFalse(text.contains("Candidate Secret"))
        XCTAssertFalse(text.contains("○秘"))
        let summary = try XCTUnwrap(text.components(separatedBy: "\n\n").first)
        XCTAssertEqual(
            summary.split(separator: "\n").dropFirst().compactMap {
                $0.split(separator: "=", maxSplits: 1).first.map(String.init)
            },
            [
                "manualYearMonth", "resolvedYearMonth", "selectedRotation",
                "orientationEvidencePhase", "ocrObservations", "meaningful",
                "pureNumeric", "dateAnchors", "distinctDays", "duplicateDays",
                "anchorMedianWidth", "anchorMedianHeight", "topQuarterAnchors",
                "bottomThreeQuarterAnchors", "leftHalfAnchors", "rightHalfAnchors",
                "anchorExtent",
                "sundayScore", "mondayScore", "weekStart", "grid", "matched",
                "rejected", "threshold", "gridAccepted", "dayRegions",
                "candidates", "stage", "failure"
            ]
        )
    }

    func testOrientationDiagnosticsRecordsSelectedRotationAndFourCandidates() throws {
        var upright = september2026DateObservations()
        upright.append(observation("Meeting", day: 9, line: 0))
        let candidates = CalendarPhotoRotation.allCases.map { rotation in
            CalendarPhotoOrientationCandidate(
                rotation: rotation,
                observations: rotatedObservations(upright, by: rotation)
            )
        }
        let selection = try XCTUnwrap(CalendarPhotoOrientationSelector().selectBest(
            from: candidates,
            calendar: utcGregorianCalendar()
        ))
        let orientationDiagnostics = CalendarPhotoOrientationDiagnostics(
            selectedRotation: selection.rotation,
            evidencePhase: .accurate,
            candidates: selection.candidateDiagnostics
        )
        var diagnostics: CalendarPhotoImportDiagnostics?

        _ = try CalendarPhotoParser().parse(
            observations: selection.observations,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            orientationDiagnostics: orientationDiagnostics,
            diagnosticsHandler: { diagnostics = $0 }
        )

        let captured = try XCTUnwrap(diagnostics)
        XCTAssertEqual(selection.rotation, .degrees0)
        XCTAssertEqual(captured.orientation?.selectedRotation, .degrees0)
        XCTAssertEqual(captured.orientation?.evidencePhase, .accurate)
        XCTAssertEqual(
            captured.orientation?.candidates.map(\.rotation),
            CalendarPhotoRotation.allCases
        )
        XCTAssertTrue(captured.orientation?.candidates.allSatisfy {
            $0.observationCount == upright.count
                && $0.dateAnchorCount == 35
                && $0.distinctDayCount == 31
        } == true)
        let uprightCandidate = try XCTUnwrap(
            captured.orientation?.candidates.first { $0.rotation == .degrees0 }
        )
        XCTAssertTrue(uprightCandidate.hasInferredYearMonth)
        XCTAssertEqual(uprightCandidate.gridColumnCount, 7)
        XCTAssertEqual(uprightCandidate.gridRowCount, 5)
        XCTAssertEqual(uprightCandidate.matchedDateAnchorCount, 30)
        XCTAssertEqual(uprightCandidate.evidenceScore, selection.evidence.score)
        XCTAssertTrue(captured.plainText.contains("selectedRotation=0"))
        XCTAssertTrue(captured.plainText.contains("rotation=270"))
    }

    func testDuplicateAnchorDiagnosticsPreserveAllAnchorObservations() throws {
        var observations = september2026CurrentMonthDateObservations()
        observations.append(contentsOf: [
            scaledAnchor(observation("1", day: 1, line: -1), scale: 0.2),
            scaledAnchor(observation("2", day: 2, line: -1), scale: 0.2),
            observation("Meeting", day: 12, line: 0)
        ])
        var diagnostics: CalendarPhotoImportDiagnostics?

        let result = try CalendarPhotoParser().parse(
            observations: observations,
            overridingYearMonth: CalendarImportYearMonth(year: 2026, month: 9),
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )

        XCTAssertEqual(result.candidates.map(\.title), ["Meeting"])
        let captured = try XCTUnwrap(diagnostics)
        XCTAssertEqual(captured.dateAnchorCount, 32)
        XCTAssertEqual(captured.distinctDayCount, 30)
        XCTAssertEqual(
            captured.duplicateDays,
            [
                CalendarPhotoDuplicateDayDiagnostics(day: 1, occurrenceCount: 2),
                CalendarPhotoDuplicateDayDiagnostics(day: 2, occurrenceCount: 2)
            ]
        )
        XCTAssertEqual(captured.anchors.filter { $0.day == 1 }.count, 2)
        XCTAssertEqual(captured.anchors.filter { $0.day == 2 }.count, 2)
        XCTAssertTrue(captured.anchors.contains {
            $0.day == 1 && ($0.widthRatio ?? 1) < 0.5 && ($0.heightRatio ?? 1) < 0.5
        })
        XCTAssertTrue(captured.plainText.contains("duplicateDays=1:2,2:2"))
    }

    func testGridMappingDiagnosticsRecordExpectedAndActualCells() throws {
        var observations = september2026CurrentMonthDateObservations()
        observations.append(observation("Meeting", day: 12, line: 0))
        var diagnostics: CalendarPhotoImportDiagnostics?

        _ = try CalendarPhotoParser().parse(
            observations: observations,
            overridingYearMonth: CalendarImportYearMonth(year: 2026, month: 9),
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )

        let captured = try XCTUnwrap(diagnostics)
        let selectedAttempt = try XCTUnwrap(captured.selectedGridAttempt)
        XCTAssertEqual(selectedAttempt.weekStart, .sunday)
        XCTAssertEqual(selectedAttempt.firstColumn, 2)
        XCTAssertEqual(selectedAttempt.xCenters.count, 7)
        XCTAssertEqual(selectedAttempt.yCenters.count, 5)
        XCTAssertEqual(selectedAttempt.anchorMappings.count, 30)
        XCTAssertTrue(selectedAttempt.anchorMappings.allSatisfy(\.matched))
        let dayOne = try XCTUnwrap(
            selectedAttempt.anchorMappings.first { $0.day == 1 }
        )
        XCTAssertEqual(dayOne.expectedColumn, 2)
        XCTAssertEqual(dayOne.expectedRow, 0)
        XCTAssertEqual(dayOne.actualColumn, 2)
        XCTAssertEqual(dayOne.actualRow, 0)
        XCTAssertTrue(dayOne.matched)
        XCTAssertEqual(captured.gridAttempts.map(\.weekStart), [.sunday, .monday])
        XCTAssertTrue(captured.plainText.contains("[XCenters]"))
        XCTAssertTrue(captured.plainText.contains("[YCenters]"))
        XCTAssertTrue(captured.plainText.contains(
            "day=1 x=0.3300 y=0.8125 expected=(2,0) actual=(2,0) matched=true"
        ))
    }

    func testManualYearMonthOverridesConflictingAutomaticInference() throws {
        var observations = september2026DateObservations(includeHeader: false)
        observations.append(contentsOf: [
            CalendarOCRObservation(
                text: "2025/8",
                confidence: 0.99,
                boundingBox: CalendarOCRBoundingBox(x: 0.25, y: 0.93, width: 0.5, height: 0.04)
            ),
            observation("Meeting", day: 12, line: 0)
        ])

        XCTAssertEqual(
            CalendarPhotoParser.inferYearMonth(from: observations),
            CalendarImportYearMonth(year: 2025, month: 8)
        )

        var diagnostics: CalendarPhotoImportDiagnostics?
        let result = try CalendarPhotoParser().parse(
            observations: observations,
            overridingYearMonth: CalendarImportYearMonth(year: 2026, month: 9),
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )

        XCTAssertEqual(result.yearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(result.dayRegions.count, 30)
        XCTAssertEqual(result.candidates.map(\.title), ["Meeting"])
        XCTAssertEqual(
            dateComponents(try XCTUnwrap(result.candidates.first).date),
            DateComponents(year: 2026, month: 9, day: 12)
        )
        XCTAssertEqual(diagnostics?.manualYearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(diagnostics?.resolvedYearMonth, CalendarImportYearMonth(year: 2026, month: 9))
    }

    func testManualYearMonthWithInsufficientAnchorsReportsDateStructureStage() {
        let observations = (1...6).map { day in
            observation("\(day)", column: day - 1, row: 0, line: -1)
        }
        var diagnostics: CalendarPhotoImportDiagnostics?

        XCTAssertThrowsError(try CalendarPhotoParser().parse(
            observations: observations,
            overridingYearMonth: CalendarImportYearMonth(year: 2026, month: 9),
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )) { error in
            XCTAssertEqual(error as? CalendarPhotoImportParseError, .noDateStructure)
        }

        XCTAssertEqual(diagnostics?.manualYearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(diagnostics?.resolvedYearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(diagnostics?.dateAnchorCount, 6)
        XCTAssertEqual(diagnostics?.distinctDayCount, 6)
        XCTAssertEqual(diagnostics?.parseStage, .dateAnchors)
        XCTAssertEqual(diagnostics?.failureReason, .noDateStructure)
        XCTAssertTrue(diagnostics?.shouldDisplay == true)
        XCTAssertNotEqual(diagnostics?.failureReason, .missingYearMonth)
    }

    func testManualYearMonthWithUnusableGridReportsGridStage() {
        let observations = (1...7).map { day in
            observation("\(day)", column: day - 1, row: 0, line: -1)
        }
        var diagnostics: CalendarPhotoImportDiagnostics?

        XCTAssertThrowsError(try CalendarPhotoParser().parse(
            observations: observations,
            overridingYearMonth: CalendarImportYearMonth(year: 2026, month: 9),
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )) { error in
            XCTAssertEqual(error as? CalendarPhotoImportParseError, .noDateStructure)
        }

        XCTAssertEqual(diagnostics?.resolvedYearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(diagnostics?.dateAnchorCount, 7)
        XCTAssertEqual(diagnostics?.parseStage, .grid)
        XCTAssertEqual(diagnostics?.failureReason, .noDateStructure)
        XCTAssertEqual(diagnostics?.gridAccepted, false)
        XCTAssertTrue(diagnostics?.shouldDisplay == true)
        XCTAssertNotEqual(diagnostics?.failureReason, .missingYearMonth)
    }

    func testManualYearMonthWithGridButNoContentReportsCandidateStage() {
        let observations = september2026DateObservations(includeHeader: false)
        var diagnostics: CalendarPhotoImportDiagnostics?

        XCTAssertThrowsError(try CalendarPhotoParser().parse(
            observations: observations,
            overridingYearMonth: CalendarImportYearMonth(year: 2026, month: 9),
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )) { error in
            XCTAssertEqual(error as? CalendarPhotoImportParseError, .noCandidates)
        }

        XCTAssertEqual(diagnostics?.resolvedYearMonth, CalendarImportYearMonth(year: 2026, month: 9))
        XCTAssertEqual(diagnostics?.gridAccepted, true)
        XCTAssertEqual(diagnostics?.dayRegionCount, 30)
        XCTAssertEqual(diagnostics?.candidateCount, 0)
        XCTAssertEqual(diagnostics?.parseStage, .candidates)
        XCTAssertEqual(diagnostics?.failureReason, .noCandidates)
        XCTAssertTrue(diagnostics?.shouldDisplay == true)
    }

    func testExistingAutomaticYearMonthFormatsStillParse() throws {
        for header in ["2026年9月", "2026/9", "2026-9", "2026 + SEPTEMBER"] {
            var observations = september2026DateObservations(includeHeader: false)
            observations.append(contentsOf: [
                CalendarOCRObservation(
                    text: header,
                    confidence: 0.99,
                    boundingBox: CalendarOCRBoundingBox(x: 0.25, y: 0.93, width: 0.5, height: 0.04)
                ),
                observation("Meeting", day: 12, line: 0)
            ])

            let result = try CalendarPhotoParser().parse(
                observations: observations,
                defaultCalendarID: calendarID,
                calendar: utcGregorianCalendar()
            )

            XCTAssertEqual(
                result.yearMonth,
                CalendarImportYearMonth(year: 2026, month: 9),
                "Failed header: \(header)"
            )
            XCTAssertEqual(result.candidates.map(\.title), ["Meeting"])
        }
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

    func testManualYearMonthReevaluatesAllOrientationsWithSpecifiedMonth() throws {
        var weakAutomaticChoice = (1...30).map { day in
            let index = day - 1
            return observation(
                "\(day)",
                column: index % 7,
                row: index / 7,
                line: -1
            )
        }
        weakAutomaticChoice.append(observation(
            "Meeting",
            column: 4,
            row: 1,
            line: 0
        ))

        var correctSeptemberOrientation = september2026CurrentMonthDateObservations()
        correctSeptemberOrientation.append(observation("Meeting", day: 12, line: 0))
        let candidates = CalendarPhotoRotation.allCases.map { rotation in
            let candidateObservations: [CalendarOCRObservation]
            switch rotation {
            case .degrees0:
                candidateObservations = weakAutomaticChoice
            case .degrees90:
                candidateObservations = correctSeptemberOrientation
            case .degrees180, .degrees270:
                candidateObservations = []
            }
            return CalendarPhotoOrientationCandidate(
                rotation: rotation,
                observations: candidateObservations
            )
        }
        let selector = CalendarPhotoOrientationSelector()

        let automaticSelection = try XCTUnwrap(selector.selectBest(
            from: candidates,
            calendar: utcGregorianCalendar()
        ))
        XCTAssertEqual(automaticSelection.rotation, .degrees0)
        XCTAssertNil(automaticSelection.evidence.yearMonth)

        let selectedYearMonth = try XCTUnwrap(
            CalendarImportYearMonth(year: 2026, month: 9)
        )
        let manualSelection = try XCTUnwrap(selector.selectBest(
            from: candidates,
            overridingYearMonth: selectedYearMonth,
            calendar: utcGregorianCalendar()
        ))

        XCTAssertEqual(manualSelection.rotation, .degrees90)
        XCTAssertEqual(manualSelection.evidence.yearMonth, selectedYearMonth)
        XCTAssertTrue(manualSelection.evidence.hasReliableCalendarStructure)
        XCTAssertEqual(manualSelection.evidence.columnCount, 7)
        XCTAssertEqual(manualSelection.evidence.rowCount, 5)
        XCTAssertEqual(manualSelection.evidence.matchedDateAnchorCount, 30)
        XCTAssertEqual(manualSelection.candidateDiagnostics.count, 4)
        XCTAssertTrue(manualSelection.candidateDiagnostics.allSatisfy {
            !$0.hasInferredYearMonth
        })

        let orientationDiagnostics = CalendarPhotoOrientationDiagnostics(
            selectedRotation: manualSelection.rotation,
            evidencePhase: .accurate,
            candidates: manualSelection.candidateDiagnostics
        )
        var diagnostics: CalendarPhotoImportDiagnostics?
        let result = try CalendarPhotoParser().parse(
            observations: manualSelection.observations,
            overridingYearMonth: selectedYearMonth,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            orientationDiagnostics: orientationDiagnostics,
            diagnosticsHandler: { diagnostics = $0 }
        )

        XCTAssertEqual(result.candidates.map(\.title), ["Meeting"])
        XCTAssertEqual(diagnostics?.orientation?.selectedRotation, .degrees90)
        XCTAssertEqual(diagnostics?.gridAccepted, true)
        XCTAssertEqual(diagnostics?.parseStage, .completed)
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

    private func september2026CurrentMonthDateObservations() -> [CalendarOCRObservation] {
        (1...30).map { day in
            observation("\(day)", day: day, line: -1)
        }
    }

    private func scaledAnchor(
        _ observation: CalendarOCRObservation,
        scale: Double
    ) -> CalendarOCRObservation {
        let box = observation.boundingBox
        let width = box.width * scale
        let height = box.height * scale
        return CalendarOCRObservation(
            text: observation.text,
            confidence: observation.confidence - 0.1,
            boundingBox: CalendarOCRBoundingBox(
                x: box.midX - width / 2,
                y: box.midY - height / 2,
                width: width,
                height: height
            )
        )
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

    func testGridFirstMonthCreatesRegionsWithoutDateOCR() throws {
        let yearMonth = try XCTUnwrap(CalendarImportYearMonth(year: 2026, month: 9))
        let grid = CalendarPhotoGridGeometry(
            boundingBox: CalendarOCRBoundingBox(x: 0.05, y: 0.1, width: 0.9, height: 0.75),
            columns: 7,
            rows: 5
        )
        let regions = CalendarPhotoGridFirstParser().dayRegions(
            yearMonth: yearMonth,
            weekStart: .sunday,
            grid: grid,
            calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(regions.count, 30)
        XCTAssertEqual(regions.first?.day, 1)
        XCTAssertEqual(regions.last?.day, 30)
    }

    func testGridFirstMonthMapsCellContentToKnownDate() throws {
        let yearMonth = try XCTUnwrap(CalendarImportYearMonth(year: 2026, month: 9))
        let parser = CalendarPhotoGridFirstParser()
        let grid = CalendarPhotoGridGeometry(
            boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 0.7, height: 0.5),
            columns: 7,
            rows: 5
        )
        let region = try XCTUnwrap(parser.dayRegions(
            yearMonth: yearMonth, weekStart: .sunday, grid: grid,
            calendar: utcGregorianCalendar()
        ).first(where: { $0.day == 12 }))
        let result = try parser.parseMonth(
            observations: [CalendarOCRObservation(
                text: "17:30-20:30 Dentist", confidence: 0.95,
                boundingBox: CalendarOCRBoundingBox(
                    x: region.boundingBox.x + 0.01, y: region.boundingBox.y + 0.02,
                    width: region.boundingBox.width * 0.8, height: 0.02
                )
            )],
            yearMonth: yearMonth, weekStart: .sunday, grid: grid,
            defaultCalendarID: calendarID, calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(dateComponents(result.candidates[0].date), DateComponents(year: 2026, month: 9, day: 12))
        XCTAssertEqual(result.candidates[0].startTimeMinutes, 17 * 60 + 30)
        XCTAssertEqual(result.candidates[0].endTimeMinutes, 20 * 60 + 30)
        XCTAssertEqual(result.candidates[0].title, "Dentist")
    }

    func testMainGridSelectorRejectsSmallerMiniCalendar() throws {
        let selected = try XCTUnwrap(CalendarPhotoGridSelector().selectMainGrid(
            from: [
                CalendarPhotoGridCandidate(
                    boundingBox: CalendarOCRBoundingBox(x: 0.72, y: 0.75, width: 0.2, height: 0.15),
                    structuralConfidence: 0.98
                ),
                CalendarPhotoGridCandidate(
                    boundingBox: CalendarOCRBoundingBox(x: 0.05, y: 0.1, width: 0.9, height: 0.7),
                    structuralConfidence: 0.9
                )
            ], expectedRows: 5
        ))
        XCTAssertEqual(selected.boundingBox.width, 0.9)
    }

    func testSixRowAndMondayFirstMonthMapping() throws {
        let yearMonth = try XCTUnwrap(CalendarImportYearMonth(year: 2026, month: 3))
        let parser = CalendarPhotoGridFirstParser()
        XCTAssertEqual(parser.expectedRows(
            yearMonth: yearMonth, weekStart: .monday,
            calendar: utcGregorianCalendar()
        ), 6)
        let regions = parser.dayRegions(
            yearMonth: yearMonth, weekStart: .monday,
            grid: CalendarPhotoGridGeometry(
                boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 0.7, height: 0.6),
                columns: 7, rows: 6
            ), calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(regions.count, 31)
        XCTAssertEqual(regions[0].boundingBox.x, 0.6, accuracy: 0.0001)
    }

    func testDayScanKeepsSelectedDateAndSingleTimeNeedsReview() throws {
        let selectedDate = try XCTUnwrap(utcGregorianCalendar().date(
            from: DateComponents(year: 2026, month: 9, day: 19)
        ))
        let result = try CalendarPhotoDayParser().parse(
            observations: [
                CalendarOCRObservation(
                    text: "9/20", confidence: 0.9,
                    boundingBox: CalendarOCRBoundingBox(x: 0.1, y: 0.8, width: 0.1, height: 0.03)
                ),
                CalendarOCRObservation(
                    text: "10:00 Meeting", confidence: 0.95,
                    boundingBox: CalendarOCRBoundingBox(x: 0.1, y: 0.6, width: 0.4, height: 0.04)
                )
            ], selectedDate: selectedDate, defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(dateComponents(result.candidates[0].date), DateComponents(year: 2026, month: 9, day: 19))
        XCTAssertEqual(result.candidates[0].startTimeMinutes, 10 * 60)
        XCTAssertNil(result.candidates[0].endTimeMinutes)
        XCTAssertTrue(result.candidates[0].needsReview)
    }

}
