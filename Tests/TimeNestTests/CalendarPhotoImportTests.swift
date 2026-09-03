import XCTest
@testable import TimeNest

final class CalendarPhotoImportTests: XCTestCase {
    private let calendarID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testAppLanguagesResolveToCanonicalVisionOCRLanguages() {
        let cases: [(DisplayLanguage, String)] = [
            (.ja, "ja-JP"),
            (.zhHans, "zh-Hans"),
            (.zhHant, "zh-Hant"),
            (.ko, "ko-KR"),
            (.enUS, "en-US")
        ]

        for (appLanguage, expectedOCRLanguage) in cases {
            let resolved = CalendarOCRLanguage.resolve(appLanguage: appLanguage)
            XCTAssertEqual(resolved.appLanguage, appLanguage)
            XCTAssertEqual(resolved.resolvedAppLanguage, appLanguage)
            XCTAssertEqual(resolved.visionRecognitionLanguageCode, expectedOCRLanguage)
        }
    }

    func testSystemOCRLanguageUsesInjectedLocaleAndNeverPassesSystem() {
        let cases: [(String, DisplayLanguage, String)] = [
            ("ja_JP", .ja, "ja-JP"),
            ("zh_Hans_CN", .zhHans, "zh-Hans"),
            ("zh_Hant_TW", .zhHant, "zh-Hant"),
            ("ko_KR", .ko, "ko-KR"),
            ("en_GB", .enUS, "en-US"),
            ("fr_FR", .enUS, "en-US")
        ]

        for (localeIdentifier, expectedLanguage, expectedOCRLanguage) in cases {
            let resolved = CalendarOCRLanguage.resolve(
                appLanguage: .system,
                systemLocale: Locale(identifier: localeIdentifier)
            )
            XCTAssertEqual(resolved.appLanguage, .system)
            XCTAssertEqual(resolved.resolvedAppLanguage, expectedLanguage)
            XCTAssertEqual(resolved.visionRecognitionLanguageCode, expectedOCRLanguage)
            XCTAssertNotEqual(resolved.visionRecognitionLanguageCode, "system")
        }
    }

    func testResolvedOCRLanguageSelectsOnlyMatchingVisionLanguage() {
        let supported = ["en-US", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR"]
        let cases: [(DisplayLanguage, [String])] = [
            (.ja, ["ja-JP"]),
            (.zhHans, ["zh-Hans"]),
            (.zhHant, ["zh-Hant"]),
            (.ko, ["ko-KR"]),
            (.enUS, ["en-US"])
        ]

        for (appLanguage, expectedLanguages) in cases {
            XCTAssertEqual(
                CalendarOCRLanguage.resolve(appLanguage: appLanguage)
                    .preferredVisionRecognitionLanguages(supported: supported),
                expectedLanguages
            )
        }
    }

    func testMonthObservationMergerUsesVisionTitleAndPPOCRTime() throws {
        let fixture = try gridFirstFixture(day: 12)
        let ppOCR = gridFirstObservation(
            "適性核查对策 17:30-20:30",
            in: fixture.region,
            line: 1,
            confidence: 0.91
        )
        let vision = gridFirstObservation(
            "適性検査対策 17:30-20:30",
            in: fixture.region,
            line: 1,
            confidence: 0.88
        )

        let merged = CalendarMonthOCRObservationMerger().merge(
            ppOCRObservations: [ppOCR],
            visionObservations: [vision],
            regions: [fixture.region],
            visionFallbackRegions: []
        )

        XCTAssertEqual(
            Set(merged.map(\.text)),
            Set(["17:30-20:30", "適性検査対策"])
        )
        XCTAssertFalse(merged.contains { $0.text.contains("核查") })
        XCTAssertEqual(
            try XCTUnwrap(merged.first { $0.text == "17:30-20:30" })
                .selectionReason,
            "ppocrTime"
        )
        XCTAssertEqual(
            try XCTUnwrap(merged.first { $0.text == "適性検査対策" })
                .selectionReason,
            "visionLanguageAwareTitle"
        )
        let parsed = try fixture.parser.parseMonth(
            observations: merged,
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )
        let candidate = try XCTUnwrap(parsed.candidates.first)
        XCTAssertEqual(candidate.title, "適性検査対策")
        XCTAssertEqual(candidate.startTimeMinutes, 17 * 60 + 30)
        XCTAssertEqual(candidate.endTimeMinutes, 20 * 60 + 30)
    }

    func testMonthObservationMergerKeepsVisionForPPOCRTechnicalFallback() {
        let region = CalendarImportDayRegion(
            day: 12,
            boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 1, height: 1)
        )
        let ppOCR = observation("適性核查对策 17:30-20:30", day: 12, line: 0)
        let vision = observation("適性検査対策 17:30-20:30", day: 12, line: 0)

        let merged = CalendarMonthOCRObservationMerger().merge(
            ppOCRObservations: [ppOCR],
            visionObservations: [vision],
            regions: [region],
            visionFallbackRegions: [region]
        )

        XCTAssertEqual(merged, [vision])
    }

    func testMonthObservationMergerDoesNotUseFixedModelTextAsTitleFallback() {
        let region = CalendarImportDayRegion(
            day: 12,
            boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 1, height: 1)
        )
        let ppOCR = CalendarOCRObservation(
            text: "適性核查对策 17:30-20:30",
            confidence: 0.91,
            boundingBox: CalendarOCRBoundingBox(x: 0.1, y: 0.2, width: 0.8, height: 0.15)
        )

        let merged = CalendarMonthOCRObservationMerger().merge(
            ppOCRObservations: [ppOCR],
            visionObservations: [],
            regions: [region],
            visionFallbackRegions: []
        )

        XCTAssertEqual(merged.map(\.text), ["17:30-20:30"])
        XCTAssertFalse(merged.contains { $0.text.contains("核查") })
    }

    func testSeptember2026AssignsMonthStartAndEndWithoutAdjacentMonthCells() throws {
        var observations = september2026DateObservations()
        observations.append(contentsOf: [
            observation("Previous 30 note", column: 0, row: 0, line: 0),
            observation("Previous 31 note", column: 1, row: 0, line: 0),
            observation("8:50-16:30 Opening", day: 1, line: 0),
            observation("17:30-20:30 Closing", day: 30, line: 0),
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
            CalendarImportParsedTime(
                startMinutes: 17 * 60 + 30,
                endMinutes: 20 * 60 + 30,
                parseQuality: .normalized
            )
        )
        XCTAssertEqual(
            CalendarImportTimeParser.parse("10:00"),
            CalendarImportParsedTime(startMinutes: 10 * 60, endMinutes: nil)
        )
        XCTAssertEqual(
            CalendarImportTimeParser.parse("17.30-20.30"),
            CalendarImportParsedTime(
                startMinutes: 17 * 60 + 30,
                endMinutes: 20 * 60 + 30,
                parseQuality: .normalized
            )
        )
        XCTAssertEqual(
            CalendarImportTimeParser.parse("17:30-2030"),
            CalendarImportParsedTime(
                startMinutes: 17 * 60 + 30,
                endMinutes: 20 * 60 + 30,
                parseQuality: .recovered
            )
        )
        XCTAssertNil(CalendarImportTimeParser.parse("2030"))
        XCTAssertEqual(
            CalendarImportTimeParser.parse("17時30分"),
            CalendarImportParsedTime(startMinutes: 17 * 60 + 30, endMinutes: nil)
        )
        XCTAssertNil(CalendarImportTimeParser.parse("25:90 Meeting"))
        XCTAssertNil(CalendarImportTimeParser.parse("No time"))
    }

    func testTimeParserSupportsContextBoundOCRSeparatorsWithoutGuessingDigits() {
        XCTAssertEqual(
            CalendarImportTimeParser.parse("17=30-20=30"),
            CalendarImportParsedTime(
                startMinutes: 17 * 60 + 30,
                endMinutes: 20 * 60 + 30,
                parseQuality: .normalized
            )
        )
        XCTAssertEqual(
            CalendarImportTimeParser.parse("17:30-20=30"),
            CalendarImportParsedTime(
                startMinutes: 17 * 60 + 30,
                endMinutes: 20 * 60 + 30,
                parseQuality: .normalized
            )
        )
        XCTAssertEqual(
            CalendarImportTimeParser.parse("20=20—21：40"),
            CalendarImportParsedTime(
                startMinutes: 20 * 60 + 20,
                endMinutes: 21 * 60 + 40,
                parseQuality: .normalized
            )
        )
        XCTAssertNil(CalendarImportTimeParser.parse("status=A.B"))
        XCTAssertNil(CalendarImportTimeParser.parse("key=value"))
        XCTAssertNil(CalendarImportTimeParser.parse("Release 1.23"))
        XCTAssertNil(CalendarImportTimeParser.parse("version=17=30"))
        XCTAssertEqual(
            CalendarImportTimeParser.removingTime(from: "Release 1.23"),
            "Release 1.23"
        )
        XCTAssertNil(CalendarImportTimeParser.parse("24=00-25=00"))
        XCTAssertNil(CalendarImportTimeParser.parse("17=60-20=30"))
        XCTAssertNil(CalendarImportTimeParser.parse("7230-2030"))
        XCTAssertEqual(
            CalendarImportTimeParser.parse("17:30.20.30"),
            CalendarImportParsedTime(startMinutes: 17 * 60 + 30, endMinutes: nil)
        )
        XCTAssertNil(CalendarImportTimeParser.parseRangeOnly("17:30.20.30"))
    }

    func testTimeParserSupportsBoundedCompactRangesAndRejectsAmbiguousDigits() {
        let expected1730 = CalendarImportParsedTime(
            startMinutes: 17 * 60 + 30,
            endMinutes: 20 * 60 + 30,
            parseQuality: .recovered
        )
        let expected0730 = CalendarImportParsedTime(
            startMinutes: 7 * 60 + 30,
            endMinutes: 20 * 60 + 30,
            parseQuality: .recovered
        )
        XCTAssertEqual(CalendarImportTimeParser.parse("1730-20.30"), expected1730)
        XCTAssertEqual(CalendarImportTimeParser.parse("1730-20:30"), expected1730)
        XCTAssertEqual(CalendarImportTimeParser.parse("730-20.30"), expected0730)
        XCTAssertEqual(CalendarImportTimeParser.parse("730-20:30"), expected0730)
        XCTAssertEqual(CalendarImportTimeParser.parse("1730-2030"), expected1730)
        XCTAssertEqual(
            CalendarImportTimeParser.removingTime(from: "Meeting 1730-2030"),
            "Meeting "
        )

        [
            "317302030",
            "17230-2030",
            "2460-2030",
            "1730-2560",
            "Release1730",
            "abc730-2030xyz"
        ].forEach { XCTAssertNil(CalendarImportTimeParser.parse($0), $0) }
    }

    func testMonthTimeParserRecoversStrictCompactDigitRanges() {
        let cases: [(String, Int, Int)] = [
            ("17302030", 17 * 60 + 30, 20 * 60 + 30),
            ("20202140", 20 * 60 + 20, 21 * 60 + 40),
            ("7302030", 7 * 60 + 30, 20 * 60 + 30),
            ("8501630", 8 * 60 + 50, 16 * 60 + 30),
            ("317302030", 17 * 60 + 30, 20 * 60 + 30)
        ]
        for (text, start, end) in cases {
            XCTAssertEqual(
                CalendarImportTimeParser.parseMonth(text),
                CalendarImportParsedTime(
                    startMinutes: start,
                    endMinutes: end,
                    parseQuality: .recovered
                ),
                text
            )
            XCTAssertEqual(
                CalendarImportTimeParser.removingMonthTime(from: text),
                "",
                text
            )
        }
        XCTAssertNil(CalendarImportTimeParser.parse("17302030"))
    }

    func testMonthTimeParserRejectsDamagedAmbiguousAndUnboundedDigits() {
        [
            "52020.21",
            "09012345678",
            "123456789012",
            "24:80",
            "29:40",
            "2500-2700",
            "25302030",
            "17602030",
            "0500600",
            "ID 17302030",
            "4",
            "40",
            "20002",
            "13",
            "16",
            "20",
            "27",
            "30"
        ].forEach { XCTAssertNil(CalendarImportTimeParser.parseMonth($0), $0) }
    }

    func testTimeParserReportsExactNormalizedAndRecoveredQuality() {
        XCTAssertEqual(CalendarImportTimeParser.parse("17:30-20:30")?.parseQuality, .exact)
        XCTAssertEqual(CalendarImportTimeParser.parse("17=30-20=30")?.parseQuality, .normalized)
        XCTAssertEqual(CalendarImportTimeParser.parse("17:30-20.30")?.parseQuality, .normalized)
        XCTAssertEqual(CalendarImportTimeParser.parse("20=20—21：40")?.parseQuality, .normalized)
        XCTAssertEqual(CalendarImportTimeParser.parse("1730-20.30")?.parseQuality, .recovered)
        XCTAssertEqual(CalendarImportTimeParser.parse("730-20:30")?.parseQuality, .recovered)
        XCTAssertEqual(CalendarImportTimeParser.parse("1730-2030")?.parseQuality, .recovered)
    }

    func testOCRCandidateSelectorPrefersValidRangeButLeavesTitlesUntouched() throws {
        let selected = try XCTUnwrap(CalendarOCRCandidateSelector.select(from: [
            CalendarOCRCandidate(text: "17:3020:30", confidence: 0.96),
            CalendarOCRCandidate(text: "17:30-20:30", confidence: 0.82)
        ]))
        XCTAssertEqual(selected.text, "17:30-20:30")

        let title = try XCTUnwrap(CalendarOCRCandidateSelector.select(from: [
            CalendarOCRCandidate(text: "適性検査対策", confidence: 0.91),
            CalendarOCRCandidate(text: "適正検査対策", confidence: 0.89)
        ]))
        XCTAssertEqual(title.text, "適性検査対策")
    }

    func testPPOCRTimeRecoverySelectionUsesSemanticPriority() {
        let validCurrent = PPOCRRecognitionAlternative(
            text: "17:30-20:30",
            confidence: 0.70
        )
        let validEnhanced = PPOCRRecognitionAlternative(
            text: "20:20-21:40",
            confidence: 0.99
        )
        var selected = PPOCRTimeRecoveryPolicy.select(
            current: validCurrent,
            enhanced: validEnhanced,
            candidate: nil,
            vision: nil
        )
        XCTAssertEqual(selected.source, .currentPPocr)
        XCTAssertEqual(selected.alternative, validCurrent)

        let broken = PPOCRRecognitionAlternative(text: "52020.21", confidence: 0.90)
        selected = PPOCRTimeRecoveryPolicy.select(
            current: broken,
            enhanced: validEnhanced,
            candidate: nil,
            vision: nil
        )
        XCTAssertEqual(selected.source, .enhancedPPocr)
        XCTAssertTrue(selected.isRecovered)

        let candidate = PPOCRRecognitionAlternative(text: "17:30-20:30", confidence: 0.62)
        selected = PPOCRTimeRecoveryPolicy.select(
            current: broken,
            enhanced: PPOCRRecognitionAlternative(text: "still broken", confidence: 0.99),
            candidate: candidate,
            vision: nil
        )
        XCTAssertEqual(selected.source, .candidatePPocr)
        XCTAssertEqual(selected.alternative, candidate)

        let vision = PPOCRRecognitionAlternative(text: "08:50-16:30", confidence: 0.58)
        selected = PPOCRTimeRecoveryPolicy.select(
            current: broken,
            enhanced: PPOCRRecognitionAlternative(text: "still broken", confidence: 0.99),
            candidate: PPOCRRecognitionAlternative(text: "also broken", confidence: 0.99),
            vision: vision
        )
        XCTAssertEqual(selected.source, .visionSecondary)
        XCTAssertEqual(selected.alternative, vision)

        selected = PPOCRTimeRecoveryPolicy.select(
            current: broken,
            enhanced: PPOCRRecognitionAlternative(text: "24:80", confidence: 0.99),
            candidate: PPOCRRecognitionAlternative(text: "29:40", confidence: 0.99),
            vision: PPOCRRecognitionAlternative(text: "2500-2700", confidence: 0.99)
        )
        XCTAssertEqual(selected.source, .currentPPocr)
        XCTAssertEqual(selected.alternative, broken)
        XCTAssertEqual(selected.selectionReason, "noValidSecondaryResult")
    }

    func testPPOCRTimeRecoveryTriggerUsesConfidenceAndTimeSemantics() {
        XCTAssertEqual(
            PPOCRTimeRecoveryPolicy.reason(text: "anct-0.0", confidence: 0.55),
            .lowConfidence
        )
        XCTAssertEqual(
            PPOCRTimeRecoveryPolicy.reason(text: "52020.21", confidence: 0.90),
            .timeLikeButUnparsed
        )
        XCTAssertEqual(
            PPOCRTimeRecoveryPolicy.reason(text: "317302030", confidence: 0.90),
            nil
        )
        XCTAssertNil(PPOCRTimeRecoveryPolicy.reason(text: "4", confidence: 0.20))
        XCTAssertNil(PPOCRTimeRecoveryPolicy.reason(text: "20002", confidence: 0.90))
        XCTAssertNil(PPOCRTimeRecoveryPolicy.reason(text: "20002", confidence: 0.20))
        XCTAssertNil(PPOCRTimeRecoveryPolicy.reason(
            text: "17:30-20:30",
            confidence: 0.20
        ))
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

    func testCellAssignmentUsesHalfOpenHorizontalAndVerticalBoundaries() {
        let lowerLeft = CalendarImportDayRegion(
            day: 1,
            boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 0.5, height: 0.5)
        )
        let upperRight = CalendarImportDayRegion(
            day: 2,
            boundingBox: CalendarOCRBoundingBox(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        )
        let boundary = CalendarOCRObservation(
            text: "2", confidence: 0.9,
            boundingBox: CalendarOCRBoundingBox(x: 0.5, y: 0.5, width: 0.02, height: 0.02)
        )
        XCTAssertFalse(lowerLeft.contains(boundary))
        XCTAssertTrue(upperRight.contains(boundary))
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

        XCTAssertEqual(result.candidates.count, 2)
        let dayEight = result.candidates.filter {
            dateComponents($0.date).day == 8
        }
        XCTAssertEqual(dayEight.count, 2)
        XCTAssertEqual(Set(dayEight.compactMap(\.personToken)), Set(["○ち", "○と"]))
        XCTAssertTrue(dayEight.allSatisfy(\.includesPersonTokenInTitle))
        XCTAssertTrue(result.candidates.allSatisfy(\.needsReview))
        XCTAssertNil(result.candidates.first { $0.personToken == "○う" })
    }

    func testMissingYearMonthRequiresExplicitSelectionBeforeCandidates() throws {
        var observations = september2026DateObservations(includeHeader: false)
        observations.append(observation("10:00 Meeting", day: 1, line: 0))
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

        var resolvedDiagnostics = try XCTUnwrap(diagnostics)
        resolvedDiagnostics.appLanguage = .ja
        resolvedDiagnostics.ocrLanguage = "ja-JP"
        resolvedDiagnostics.timeRecognitionEngine = "ppocrv6"
        resolvedDiagnostics.textRecognitionEngine = "vision"
        resolvedDiagnostics.textRecognitionLanguage = "ja-JP"
        let text = resolvedDiagnostics.plainText
        XCTAssertTrue(text.hasPrefix("CalendarImportDiagnostics\n"))
        XCTAssertTrue(text.contains("appLanguage=ja"))
        XCTAssertTrue(text.contains("ocrLanguage=ja-JP"))
        XCTAssertTrue(text.contains("timeRecognitionEngine=ppocrv6"))
        XCTAssertTrue(text.contains("textRecognitionEngine=vision"))
        XCTAssertTrue(text.contains("textRecognitionLanguage=ja-JP"))
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
                "scanMode", "selectedDate", "appLanguage", "ocrLanguage",
                "timeRecognitionEngine", "textRecognitionEngine",
                "textRecognitionLanguage", "gridDetection",
                "recognitionMode", "ppocrSuccessCells", "visionFallbackCells",
                "candidateInput",
                "manualYearMonth", "resolvedYearMonth", "selectedRotation",
                "orientationEvidencePhase", "ocrObservations", "meaningful",
                "pureNumeric", "dateAnchors", "distinctDays", "duplicateDays",
                "anchorMedianWidth", "anchorMedianHeight", "topQuarterAnchors",
                "bottomThreeQuarterAnchors", "leftHalfAnchors", "rightHalfAnchors",
                "anchorExtent",
                "sundayScore", "mondayScore", "weekStart", "grid", "gridGeometry", "matched",
                "rejected", "threshold", "gridAccepted", "dayRegions",
                "candidates", "stage", "failure"
            ]
        )
    }

    func testOrientationDiagnosticsRecordsSelectedRotationAndFourCandidates() throws {
        var upright = september2026DateObservations()
        upright.append(observation("10:00 Meeting", day: 9, line: 0))
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
            observation("10:00 Meeting", day: 12, line: 0)
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
        observations.append(observation("10:00 Meeting", day: 12, line: 0))
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
            observation("10:00 Meeting", day: 12, line: 0)
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
                observation("10:00 Meeting", day: 12, line: 0)
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
            observation("10:00 Meeting", day: 9, line: 0)
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
        upright.append(observation("10:00 Meeting", day: 9, line: 0))
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
        upright.append(observation("10:00 Meeting", day: 12, line: 0))
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
            "10:00 Meeting",
            column: 4,
            row: 1,
            line: 0
        ))

        var correctSeptemberOrientation = september2026CurrentMonthDateObservations()
        correctSeptemberOrientation.append(observation("10:00 Meeting", day: 12, line: 0))
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

    func testGridFirstMonthCombinesSymbolTitleWithFollowingTimeLine() throws {
        let fixture = try gridFirstFixture(day: 24)
        var diagnostics: CalendarPhotoImportDiagnostics?
        let result = try fixture.parser.parseMonth(
            observations: [
                CalendarOCRObservation(
                    text: "SEPTEMBER 2026",
                    confidence: 0.98,
                    boundingBox: CalendarOCRBoundingBox(
                        x: 0.1,
                        y: 0.8,
                        width: 0.3,
                        height: 0.04
                    )
                ),
                gridFirstObservation("24", in: fixture.region, line: 0),
                gridFirstObservation("⑤", in: fixture.region, line: 1, confidence: 0.5),
                gridFirstObservation("20:20–21:40", in: fixture.region, line: 2)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(dateComponents(candidate.date), DateComponents(year: 2026, month: 9, day: 24))
        XCTAssertEqual(candidate.startTimeMinutes, 20 * 60 + 20)
        XCTAssertEqual(candidate.endTimeMinutes, 21 * 60 + 40)
        XCTAssertEqual(candidate.title, "⑤")
        XCTAssertTrue(candidate.needsReview)

        let captured = try XCTUnwrap(diagnostics)
        XCTAssertEqual(captured.scanMode, .month)
        XCTAssertEqual(captured.cellDiagnostics.count, 30)
        XCTAssertEqual(captured.unassignedRawTexts, ["SEPTEMBER 2026"])
        XCTAssertEqual(captured.unassignedNormalizedTexts, ["SEPTEMBER 2026"])
        let day = try XCTUnwrap(captured.cellDiagnostics.first { $0.day == 24 })
        XCTAssertEqual(day.observationCount, 3)
        XCTAssertEqual(day.printedDayObservationCount, 1)
        XCTAssertEqual(day.rawTexts, ["⑤", "20:20–21:40"])
        XCTAssertEqual(day.normalizedTexts, ["⑤", "20:20–21:40"])
        XCTAssertTrue(day.candidateCreated)
        XCTAssertNil(day.rejectedReason)
        XCTAssertEqual(day.candidates.first?.parsedStartMinutes, 20 * 60 + 20)
        XCTAssertEqual(day.candidates.first?.parsedEndMinutes, 21 * 60 + 40)
        XCTAssertEqual(day.candidates.first?.remainingTitle, "⑤")
        XCTAssertTrue(captured.plainText.contains(
            #"rawTexts=["⑤","20:20–21:40"]"#
        ))
        XCTAssertTrue(captured.plainText.contains(
            #"parsedStart=20:20 parsedEnd=21:40 remainingTitle="⑤" ocrConfidence=0.7250 quality=standard timeParseQuality=normalized holidayMatch=false needsReview=true defaultSelected=true candidateCreated=true"#
        ))
    }

    func testGridFirstMonthKeepsTimeOnlyCellAsWarningCandidate() throws {
        let fixture = try gridFirstFixture(day: 12)
        let result = try fixture.parser.parseMonth(
            observations: [
                gridFirstObservation("17:30–20:30", in: fixture.region, line: 0)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.startTimeMinutes, 17 * 60 + 30)
        XCTAssertEqual(candidate.endTimeMinutes, 20 * 60 + 30)
        XCTAssertEqual(candidate.title, "")
        XCTAssertEqual(candidate.quality, .standard)
        XCTAssertTrue(candidate.isSelected)
        XCTAssertTrue(candidate.needsReview)
        XCTAssertFalse(candidate.isValidForSaving)
    }

    func testGridFirstMonthRejectsContentWithoutParsedTime() throws {
        for text in ["Meeting", "4", "40", "20002"] {
            let fixture = try gridFirstFixture(day: 12)
            var diagnostics: CalendarPhotoImportDiagnostics?

            XCTAssertThrowsError(try fixture.parser.parseMonth(
                observations: [
                    gridFirstObservation(
                        text,
                        in: fixture.region,
                        line: 0,
                        confidence: 0.42
                    )
                ],
                yearMonth: fixture.yearMonth,
                weekStart: .sunday,
                grid: fixture.grid,
                defaultCalendarID: calendarID,
                calendar: utcGregorianCalendar(),
                diagnosticsHandler: { diagnostics = $0 }
            )) { error in
                XCTAssertEqual(error as? CalendarPhotoImportParseError, .noCandidates, text)
            }

            let cell = try XCTUnwrap(
                diagnostics?.cellDiagnostics.first(where: { $0.day == 12 })
            )
            XCTAssertEqual(cell.rawTexts, [text])
            XCTAssertEqual(cell.timeLinesDetected, 0)
            XCTAssertTrue(cell.candidates.isEmpty)
            XCTAssertFalse(cell.candidateCreated)
            XCTAssertEqual(cell.rejectedReason, .noParsedTime)
            let plainText = try XCTUnwrap(diagnostics).plainText
            XCTAssertTrue(plainText.contains("parsedStart=none"), text)
            XCTAssertTrue(plainText.contains(
                "timeLinesDetected=0 candidates=0 rejectedReason=noParsedTime"
            ), text)
            XCTAssertTrue(plainText.contains("candidateCreated=false"))
        }
    }

    func testCandidateQualityClassificationInfrastructureRemainsAvailable() {
        for title in [
            "Meeting",
            "1on1",
            "会議 2",
            "Meeting 2",
            "Room 3",
            "A班",
            "説明会",
            "適性検査対策"
        ] {
            XCTAssertEqual(
                CalendarImportCandidateQualityEvaluator.quality(
                    title: title,
                    parsedTime: nil
                ),
                .standard,
                title
            )
        }
        XCTAssertEqual(
            CalendarImportCandidateQualityEvaluator.quality(
                title: "317302030",
                parsedTime: nil
            ),
            .lowInformation
        )
    }

    func testGridFirstMonthDoesNotFallbackUnparseableContentToAllDay() throws {
        let fixture = try gridFirstFixture(day: 12)
        var diagnostics: CalendarPhotoImportDiagnostics?

        XCTAssertThrowsError(try fixture.parser.parseMonth(
            observations: [
                gridFirstObservation("⑤", in: fixture.region, line: 0),
                gridFirstObservation("17720", in: fixture.region, line: 1)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )) { error in
            XCTAssertEqual(error as? CalendarPhotoImportParseError, .noCandidates)
        }

        let cell = try XCTUnwrap(diagnostics?.cellDiagnostics.first { $0.day == 12 })
        XCTAssertEqual(cell.timeLinesDetected, 0)
        XCTAssertTrue(cell.candidates.isEmpty)
        XCTAssertFalse(cell.candidateCreated)
        XCTAssertEqual(cell.rejectedReason, .noParsedTime)
    }

    func testGridFirstMonthCombinesJapaneseTitleWithFollowingTimeLine() throws {
        let fixture = try gridFirstFixture(day: 6)
        let result = try fixture.parser.parseMonth(
            observations: [
                gridFirstObservation("適性検査対策", in: fixture.region, line: 0),
                gridFirstObservation("8:50-16:30", in: fixture.region, line: 1)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.title, "適性検査対策")
        XCTAssertEqual(candidate.startTimeMinutes, 8 * 60 + 50)
        XCTAssertEqual(candidate.endTimeMinutes, 16 * 60 + 30)
        XCTAssertFalse(candidate.needsReview)
    }

    func testGridFirstMonthTimeParseQualityForcesReviewWithoutChangingSelection() throws {
        let cases: [(String, CalendarImportTimeParseQuality, Bool)] = [
            ("Meeting 17:30-20:30", .exact, false),
            ("Meeting 17=30-20=30", .normalized, true),
            ("Meeting 1730-20.30", .recovered, true),
            ("Meeting 2029-21=40", .recovered, true)
        ]

        for (text, expectedQuality, expectedNeedsReview) in cases {
            let fixture = try gridFirstFixture(day: 11)
            var diagnostics: CalendarPhotoImportDiagnostics?
            let result = try fixture.parser.parseMonth(
                observations: [gridFirstObservation(text, in: fixture.region, line: 0)],
                yearMonth: fixture.yearMonth,
                weekStart: .sunday,
                grid: fixture.grid,
                defaultCalendarID: calendarID,
                calendar: utcGregorianCalendar(),
                diagnosticsHandler: { diagnostics = $0 }
            )

            let candidate = try XCTUnwrap(result.candidates.first)
            XCTAssertEqual(candidate.title, "Meeting", text)
            XCTAssertEqual(candidate.needsReview, expectedNeedsReview, text)
            XCTAssertTrue(candidate.isSelected, text)
            let day = try XCTUnwrap(diagnostics?.cellDiagnostics.first { $0.day == 11 })
            let candidateDiagnostics = try XCTUnwrap(day.candidates.first)
            XCTAssertEqual(candidateDiagnostics.timeParseQuality, expectedQuality, text)
            XCTAssertFalse(candidateDiagnostics.holidayMatch, text)
            XCTAssertEqual(candidateDiagnostics.needsReview, expectedNeedsReview, text)
            XCTAssertTrue(candidateDiagnostics.defaultSelected, text)
        }
    }

    func testGridFirstMonthHolidayWithoutTimeDoesNotCreateCandidate() throws {
        let fixture = try gridFirstFixture(day: 21)
        let holidayDate = DateOnly(year: 2026, month: 9, day: 21)
        var diagnostics: CalendarPhotoImportDiagnostics?

        XCTAssertThrowsError(try fixture.parser.parseMonth(
            observations: [
                gridFirstObservation("敬老の日", in: fixture.region, line: 0)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            holidayNamesByDate: [holidayDate: Set(["敬老の日"])],
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )) { error in
            XCTAssertEqual(error as? CalendarPhotoImportParseError, .noCandidates)
        }

        let day = try XCTUnwrap(diagnostics?.cellDiagnostics.first { $0.day == 21 })
        XCTAssertEqual(day.timeLinesDetected, 0)
        XCTAssertTrue(day.candidates.isEmpty)
        XCTAssertFalse(day.candidateCreated)
        XCTAssertEqual(day.rejectedReason, .noParsedTime)
    }

    func testGridFirstMonthHolidayMatchingIsTrimmedWidthInsensitiveAndNotFuzzy() throws {
        let holidayNames = Set(["敬老の日"])
        XCTAssertTrue(CalendarImportHolidayMatcher.isExactMatch(
            title: "　敬老の日　",
            holidayNames: holidayNames
        ))
        XCTAssertFalse(CalendarImportHolidayMatcher.isExactMatch(
            title: "敬老日",
            holidayNames: holidayNames
        ))
        XCTAssertFalse(CalendarImportHolidayMatcher.isExactMatch(
            title: "敬老の日 Meeting",
            holidayNames: holidayNames
        ))
    }

    func testGridFirstMonthKeepsTwoTimedLinesAsIndependentCandidates() throws {
        let fixture = try gridFirstFixture(day: 26)
        var diagnostics: CalendarPhotoImportDiagnostics?
        let result = try fixture.parser.parseMonth(
            observations: [
                gridFirstObservation("17:30–20:30", in: fixture.region, line: 0),
                gridFirstObservation("20:20–21:40", in: fixture.region, line: 1)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )

        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertEqual(result.candidates.map(\.title), ["", ""])
        XCTAssertEqual(result.candidates.map(\.startTimeMinutes), [17 * 60 + 30, 20 * 60 + 20])
        XCTAssertEqual(result.candidates.map(\.endTimeMinutes), [20 * 60 + 30, 21 * 60 + 40])
        let day = try XCTUnwrap(diagnostics?.cellDiagnostics.first { $0.day == 26 })
        XCTAssertEqual(day.timeLinesDetected, 2)
        XCTAssertEqual(day.candidates.count, 2)
        XCTAssertTrue(try XCTUnwrap(diagnostics).plainText.contains(
            "timeLinesDetected=2 candidates=2 rejectedReason=none"
        ))
    }

    func testGridFirstMonthKeepsTwoRecoveredTimedLinesAsIndependentCandidates() throws {
        let fixture = try gridFirstFixture(day: 4)
        var diagnostics: CalendarPhotoImportDiagnostics?
        let result = try fixture.parser.parseMonth(
            observations: [
                gridFirstObservation("17302030", in: fixture.region, line: 0),
                gridFirstObservation("20202140", in: fixture.region, line: 1)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )

        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertEqual(result.candidates.map(\.startTimeMinutes), [17 * 60 + 30, 20 * 60 + 20])
        XCTAssertEqual(result.candidates.map(\.endTimeMinutes), [20 * 60 + 30, 21 * 60 + 40])
        XCTAssertTrue(result.candidates.allSatisfy(\.needsReview))
        let day = try XCTUnwrap(diagnostics?.cellDiagnostics.first { $0.day == 4 })
        XCTAssertEqual(day.timeLinesDetected, 2)
        XCTAssertEqual(day.candidates.count, 2)
        XCTAssertTrue(day.candidates.allSatisfy { $0.timeParseQuality == .recovered })
    }

    func testGridFirstMonthSecondaryOCRResultAlwaysRequiresReview() throws {
        let fixture = try gridFirstFixture(day: 7)
        var recovered = gridFirstObservation(
            "17:30-20:30 Meeting",
            in: fixture.region,
            line: 0
        )
        recovered.timeParseQualityOverride = .recovered
        let result = try fixture.parser.parseMonth(
            observations: [recovered],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.startTimeMinutes, 17 * 60 + 30)
        XCTAssertEqual(candidate.endTimeMinutes, 20 * 60 + 30)
        XCTAssertTrue(candidate.needsReview)
    }

    func testGridFirstMonthTitleAndTwoTimedLinesCreateTwoCandidates() throws {
        let fixture = try gridFirstFixture(day: 26)
        let result = try fixture.parser.parseMonth(
            observations: [
                gridFirstObservation("適性検査対策", in: fixture.region, line: 0),
                gridFirstObservation("17:30–20:30", in: fixture.region, line: 1),
                gridFirstObservation("20:20–21:40", in: fixture.region, line: 2)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertEqual(result.candidates.map(\.title), ["適性検査対策", ""])
        XCTAssertEqual(result.candidates.map(\.startTimeMinutes), [17 * 60 + 30, 20 * 60 + 20])
        XCTAssertEqual(result.candidates.map(\.endTimeMinutes), [20 * 60 + 30, 21 * 60 + 40])
        XCTAssertFalse(result.candidates[0].originalText.contains("20:20"))
    }

    func testGridFirstMonthRejectsTrailingUntimedLineWithoutRemovingTimedCandidate() throws {
        let fixture = try gridFirstFixture(day: 12)
        var diagnostics: CalendarPhotoImportDiagnostics?
        let result = try fixture.parser.parseMonth(
            observations: [
                gridFirstObservation("20:30-21:30", in: fixture.region, line: 0),
                gridFirstObservation("52020.21", in: fixture.region, line: 1)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )

        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(result.candidates[0].startTimeMinutes, 20 * 60 + 30)
        XCTAssertFalse(result.candidates[0].originalText.contains("52020.21"))
        let cell = try XCTUnwrap(diagnostics?.cellDiagnostics.first { $0.day == 12 })
        XCTAssertEqual(cell.timeLinesDetected, 1)
        XCTAssertEqual(cell.candidates.count, 1)
        XCTAssertEqual(cell.rejectedNoParsedTimeLineCount, 1)
        XCTAssertEqual(cell.rejectedReason, .noParsedTime)
        XCTAssertTrue(try XCTUnwrap(diagnostics).plainText.contains(
            "timeLinesDetected=1 candidates=1 rejectedReason=noParsedTime "
                + "rejectedNoParsedTimeLines=1"
        ))
    }

    func testGridFirstMonthRecoveredTimeCreatesCandidate() throws {
        let fixture = try gridFirstFixture(day: 11)
        let result = try fixture.parser.parseMonth(
            observations: [
                gridFirstObservation("1730-20.30", in: fixture.region, line: 0)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(result.candidates[0].startTimeMinutes, 17 * 60 + 30)
        XCTAssertEqual(result.candidates[0].endTimeMinutes, 20 * 60 + 30)
        XCTAssertTrue(result.candidates[0].needsReview)
    }

    func testGridFirstMonthEmptyCellsDoNotCreateCandidates() throws {
        let fixture = try gridFirstFixture(day: 5)
        var diagnostics: CalendarPhotoImportDiagnostics?

        XCTAssertThrowsError(try fixture.parser.parseMonth(
            observations: [],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )) { error in
            XCTAssertEqual(error as? CalendarPhotoImportParseError, .noCandidates)
        }

        let day = try XCTUnwrap(diagnostics?.cellDiagnostics.first { $0.day == 5 })
        XCTAssertFalse(day.candidateCreated)
        XCTAssertEqual(day.rejectedReason, .noObservations)
    }

    func testGridFirstMonthPrintedDayOnlyDoesNotCreateCandidate() throws {
        let fixture = try gridFirstFixture(day: 24)
        var diagnostics: CalendarPhotoImportDiagnostics?

        XCTAssertThrowsError(try fixture.parser.parseMonth(
            observations: [
                gridFirstObservation("２４", in: fixture.region, line: 0)
            ],
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            diagnosticsHandler: { diagnostics = $0 }
        )) { error in
            XCTAssertEqual(error as? CalendarPhotoImportParseError, .noCandidates)
        }

        let day = try XCTUnwrap(diagnostics?.cellDiagnostics.first { $0.day == 24 })
        XCTAssertEqual(day.observationCount, 1)
        XCTAssertEqual(day.printedDayObservationCount, 1)
        XCTAssertTrue(day.rawTexts.isEmpty)
        XCTAssertFalse(day.candidateCreated)
        XCTAssertEqual(day.rejectedReason, .printedDayOnly)
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

    func testPerspectiveGridPreservesTrapezoidCornersAndCreatesUniformCells() throws {
        let corners = (
            topLeft: CalendarPhotoGridPoint(x: 0.18, y: 0.90),
            topRight: CalendarPhotoGridPoint(x: 0.82, y: 0.86),
            bottomLeft: CalendarPhotoGridPoint(x: 0.06, y: 0.08),
            bottomRight: CalendarPhotoGridPoint(x: 0.94, y: 0.12)
        )
        let selected = try XCTUnwrap(CalendarPhotoGridSelector().selectMainGrid(
            from: [CalendarPhotoGridCandidate(
                boundingBox: CalendarOCRBoundingBox(x: 0.06, y: 0.08, width: 0.88, height: 0.82),
                structuralConfidence: 0.95,
                topLeft: corners.topLeft,
                topRight: corners.topRight,
                bottomLeft: corners.bottomLeft,
                bottomRight: corners.bottomRight
            )],
            expectedRows: 5
        ))
        let rectified = CalendarPhotoGridGeometry(
            boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 1, height: 1),
            columns: selected.columns,
            rows: selected.rows,
            topLeft: selected.topLeft,
            topRight: selected.topRight,
            bottomLeft: selected.bottomLeft,
            bottomRight: selected.bottomRight,
            originalImagePixels: CalendarPhotoPixelSizeDiagnostics(width: 1200, height: 900),
            rectifiedGridPixels: CalendarPhotoPixelSizeDiagnostics(width: 980, height: 720)
        )
        let regions = CalendarPhotoGridFirstParser().dayRegions(
            yearMonth: CalendarImportYearMonth(year: 2026, month: 9)!,
            weekStart: .sunday,
            grid: rectified,
            calendar: utcGregorianCalendar()
        )

        XCTAssertEqual(selected.topLeft, corners.topLeft)
        XCTAssertEqual(Set(regions.map { $0.boundingBox.width }), [1.0 / 7.0])
        XCTAssertEqual(Set(regions.map { $0.boundingBox.height }), [1.0 / 5.0])
    }

    func testPerspectiveCorrectionProducesRectifiedImage() throws {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 1_200,
            height: 900,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1_200, height: 900))
        let image = try XCTUnwrap(context.makeImage())
        let grid = CalendarPhotoGridGeometry(
            boundingBox: CalendarOCRBoundingBox(x: 0.06, y: 0.08, width: 0.88, height: 0.82),
            columns: 7,
            rows: 5,
            topLeft: CalendarPhotoGridPoint(x: 0.18, y: 0.90),
            topRight: CalendarPhotoGridPoint(x: 0.82, y: 0.86),
            bottomLeft: CalendarPhotoGridPoint(x: 0.06, y: 0.08),
            bottomRight: CalendarPhotoGridPoint(x: 0.94, y: 0.12)
        )

        let result = try CalendarPhotoGridRectifier.correct(image: image, grid: grid)

        XCTAssertGreaterThan(result.image.width, 0)
        XCTAssertGreaterThan(result.image.height, 0)
        XCTAssertEqual(result.geometry.boundingBox, CalendarOCRBoundingBox(
            x: 0, y: 0, width: 1, height: 1
        ))
        XCTAssertEqual(result.geometry.rectifiedGridPixels?.width, result.image.width)
        XCTAssertEqual(result.geometry.rectifiedGridPixels?.height, result.image.height)
    }

    func testRectifiedAdjacentRowsDoNotOverlapAndMarkerBelongsOnlyToNextRow() throws {
        let grid = CalendarPhotoGridGeometry(
            boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 1, height: 1),
            columns: 7,
            rows: 5
        )
        let regions = CalendarPhotoGridFirstParser().dayRegions(
            yearMonth: CalendarImportYearMonth(year: 2026, month: 9)!,
            weekStart: .sunday,
            grid: grid,
            calendar: utcGregorianCalendar()
        )
        let daySix = try XCTUnwrap(regions.first { $0.day == 6 })
        let dayThirteen = try XCTUnwrap(regions.first { $0.day == 13 })
        XCTAssertEqual(dayThirteen.boundingBox.maxY, daySix.boundingBox.minY, accuracy: 0.000_001)

        let nextRowTopMarker = CalendarOCRObservation(
            text: "13",
            confidence: 1,
            boundingBox: CalendarOCRBoundingBox(
                x: dayThirteen.boundingBox.minX + 0.01,
                y: dayThirteen.boundingBox.maxY - 0.02,
                width: 0.02,
                height: 0.015
            )
        )
        XCTAssertFalse(daySix.contains(nextRowTopMarker))
        XCTAssertTrue(dayThirteen.contains(nextRowTopMarker))
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

    func testDayScanRejectsContentWithoutParsedTime() throws {
        let selectedDate = try XCTUnwrap(utcGregorianCalendar().date(
            from: DateComponents(year: 2026, month: 9, day: 19)
        ))

        for text in ["Meeting", "317302030", "敬老の日"] {
            XCTAssertThrowsError(try CalendarPhotoDayParser().parse(
                observations: [CalendarOCRObservation(
                    text: text,
                    confidence: 0.95,
                    boundingBox: CalendarOCRBoundingBox(
                        x: 0.1,
                        y: 0.6,
                        width: 0.4,
                        height: 0.04
                    )
                )],
                selectedDate: selectedDate,
                defaultCalendarID: calendarID,
                calendar: utcGregorianCalendar()
            )) { error in
                XCTAssertEqual(error as? CalendarPhotoImportParseError, .noCandidates, text)
            }
        }
    }

    func testDayScanCreatesOneCandidatePerTimedLineOnSelectedDate() throws {
        let selectedDate = try XCTUnwrap(utcGregorianCalendar().date(
            from: DateComponents(year: 2026, month: 9, day: 19)
        ))
        let result = try CalendarPhotoDayParser().parse(
            observations: [
                CalendarOCRObservation(
                    text: "17:30-20:30 First",
                    confidence: 0.95,
                    boundingBox: CalendarOCRBoundingBox(
                        x: 0.1, y: 0.7, width: 0.4, height: 0.04
                    )
                ),
                CalendarOCRObservation(
                    text: "20:20-21:40 Second",
                    confidence: 0.95,
                    boundingBox: CalendarOCRBoundingBox(
                        x: 0.1, y: 0.5, width: 0.4, height: 0.04
                    )
                )
            ],
            selectedDate: selectedDate,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar()
        )

        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertEqual(result.candidates.map(\.title), ["First", "Second"])
        XCTAssertEqual(result.candidates.map(\.startTimeMinutes), [17 * 60 + 30, 20 * 60 + 20])
        XCTAssertEqual(result.candidates.map(\.endTimeMinutes), [20 * 60 + 30, 21 * 60 + 40])
        XCTAssertTrue(result.candidates.allSatisfy {
            dateComponents($0.date) == DateComponents(year: 2026, month: 9, day: 19)
        })
    }

    private func gridFirstFixture(
        day: Int
    ) throws -> (
        parser: CalendarPhotoGridFirstParser,
        yearMonth: CalendarImportYearMonth,
        grid: CalendarPhotoGridGeometry,
        region: CalendarImportDayRegion
    ) {
        let parser = CalendarPhotoGridFirstParser()
        let yearMonth = try XCTUnwrap(CalendarImportYearMonth(year: 2026, month: 9))
        let grid = CalendarPhotoGridGeometry(
            boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 0.7, height: 0.5),
            columns: 7,
            rows: 5
        )
        let region = try XCTUnwrap(parser.dayRegions(
            yearMonth: yearMonth,
            weekStart: .sunday,
            grid: grid,
            calendar: utcGregorianCalendar()
        ).first { $0.day == day })
        return (parser, yearMonth, grid, region)
    }

    private func gridFirstObservation(
        _ text: String,
        in region: CalendarImportDayRegion,
        line: Int,
        confidence: Float = 0.95
    ) -> CalendarOCRObservation {
        let height = region.boundingBox.height * 0.14
        let y = region.boundingBox.maxY
            - region.boundingBox.height * (0.12 + Double(line) * 0.22)
            - height
        return CalendarOCRObservation(
            text: text,
            confidence: confidence,
            boundingBox: CalendarOCRBoundingBox(
                x: region.boundingBox.minX + region.boundingBox.width * 0.08,
                y: y,
                width: region.boundingBox.width * 0.8,
                height: height
            )
        )
    }

    func testPPOCRTensorResizeAndNormalizationAreDeterministic() throws {
        XCTAssertEqual(
            try PPOCRPreprocessor.detectionInputSize(
                for: PPOCRImageSize(width: 234, height: 123)
            ),
            PPOCRImageSize(width: 1_824, height: 960)
        )
        let image = try PPOCRBGRImage(
            width: 1,
            height: 1,
            pixels: [0, 127, 255]
        )
        let first = try PPOCRPreprocessor.classificationTensor(from: image)
        let second = try PPOCRPreprocessor.classificationTensor(from: image)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.shape, [1, 3, 48, 192])
        let channelStride = 48 * 192
        XCTAssertEqual(first.values[0], -1, accuracy: 0.000_001)
        XCTAssertEqual(first.values[channelStride], -0.003_921_57, accuracy: 0.000_001)
        XCTAssertEqual(first.values[channelStride * 2], 1, accuracy: 0.000_001)
        XCTAssertEqual(first.values[48], 0, accuracy: 0.000_001)
    }

    func testPPOCRTimeRecoveryPreprocessingIsBoundedAndDeterministic() throws {
        let image = try PPOCRBGRImage(
            width: 2,
            height: 2,
            pixels: [
                0, 0, 0, 255, 255, 255,
                0, 127, 255, 255, 127, 0
            ]
        )
        let first = try image.timeRecoveryEnhanced()
        let second = try image.timeRecoveryEnhanced()
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.size, PPOCRImageSize(width: 6, height: 6))
        for index in stride(from: 0, to: first.pixels.count, by: 3) {
            XCTAssertEqual(first.pixels[index], first.pixels[index + 1])
            XCTAssertEqual(first.pixels[index + 1], first.pixels[index + 2])
        }

        let expanded = PPOCRDetectionCropper.expandedPoints(
            [
                PPOCRPoint(x: 10, y: 10),
                PPOCRPoint(x: 90, y: 10),
                PPOCRPoint(x: 90, y: 30),
                PPOCRPoint(x: 10, y: 30)
            ],
            imageSize: PPOCRImageSize(width: 100, height: 40)
        )
        XCTAssertTrue(expanded.allSatisfy { (0..<100).contains(Int($0.x)) })
        XCTAssertTrue(expanded.allSatisfy { (0..<40).contains(Int($0.y)) })
        XCTAssertLessThan(expanded[0].x, 10)
        XCTAssertGreaterThan(expanded[2].x, 90)
    }

    func testPPOCRCTCDecoderCollapsesAdjacentDuplicateTokens() throws {
        let decoded = try PPOCRCTCDecoder.decode(
            tokenIndices: [1, 1, 2, 2],
            probabilities: [0.8, 0.9, 0.7, 0.6],
            characters: ["blank", "A", "B", " "]
        )
        XCTAssertEqual(decoded.text, "AB")
    }

    func testPPOCRCTCDecoderRemovesBlankTokens() throws {
        let decoded = try PPOCRCTCDecoder.decode(
            tokenIndices: [0, 1, 0, 2, 0],
            probabilities: [0.99, 0.8, 0.99, 0.7, 0.99],
            characters: ["blank", "A", "B", " "]
        )
        XCTAssertEqual(decoded.text, "AB")
    }

    func testPPOCRCTCDecoderAveragesOnlyAcceptedTokenConfidence() throws {
        let decoded = try PPOCRCTCDecoder.decode(
            tokenIndices: [1, 1, 0, 2],
            probabilities: [0.8, 0.9, 0.99, 0.6],
            characters: ["blank", "A", "B", " "]
        )
        XCTAssertEqual(decoded.confidence, 0.7, accuracy: 0.000_001)
    }

    func testPPOCRBoxCoordinateConversionScalesAndClips() {
        let converted = PPOCRBoxCoordinateConverter.convert(
            points: [
                PPOCRPoint(x: 10, y: 20),
                PPOCRPoint(x: 110, y: -10)
            ],
            mapSize: PPOCRImageSize(width: 100, height: 200),
            destinationSize: PPOCRImageSize(width: 1_000, height: 500)
        )
        XCTAssertEqual(converted, [
            PPOCRPoint(x: 100, y: 50),
            PPOCRPoint(x: 999, y: 0)
        ])
    }

    func testPPOCRAdjacentRowCellCropsNeverOverlap() throws {
        let parser = CalendarPhotoGridFirstParser()
        let yearMonth = try XCTUnwrap(CalendarImportYearMonth(year: 2026, month: 9))
        let regions = parser.dayRegions(
            yearMonth: yearMonth,
            weekStart: .sunday,
            grid: CalendarPhotoGridGeometry(
                boundingBox: CalendarOCRBoundingBox(
                    x: 0.037, y: 0.083, width: 0.921, height: 0.769
                ),
                columns: 7,
                rows: 5
            ),
            calendar: utcGregorianCalendar()
        )
        let imageSize = PPOCRImageSize(width: 4_031, height: 3_023)

        for day in 1...23 {
            guard let current = regions.first(where: { $0.day == day }),
                  let nextRow = regions.first(where: { $0.day == day + 7 }),
                  let currentRect = PPOCRCellPixelRectConverter.pixelRect(
                    for: current.boundingBox,
                    imageSize: imageSize
                  ),
                  let nextRowRect = PPOCRCellPixelRectConverter.pixelRect(
                    for: nextRow.boundingBox,
                    imageSize: imageSize
                  ) else {
                return XCTFail("Missing same-column cell geometry for day \(day)")
            }
            XCTAssertLessThanOrEqual(
                currentRect.y + currentRect.height,
                nextRowRect.y,
                "day \(day) crop entered day \(day + 7)"
            )
        }
    }

    func testPPOCRPixelRectConversionClipsFractionalImageBoundariesInward() throws {
        let rect = try XCTUnwrap(PPOCRCellPixelRectConverter.pixelRect(
            for: CalendarOCRBoundingBox(
                x: -0.001, y: 0.0001, width: 1.002, height: 0.9998
            ),
            imageSize: PPOCRImageSize(width: 101, height: 99)
        ))

        XCTAssertGreaterThanOrEqual(rect.x, 0)
        XCTAssertGreaterThanOrEqual(rect.y, 0)
        XCTAssertLessThanOrEqual(rect.x + rect.width, 101)
        XCTAssertLessThanOrEqual(rect.y + rect.height, 99)
    }

    func testPPOCRDetectionBoxSortingUsesLinesThenHorizontalPosition() {
        func box(x: Double, y: Double) -> PPOCRDetectedBox {
            PPOCRDetectedBox(
                points: [
                    PPOCRPoint(x: x, y: y),
                    PPOCRPoint(x: x + 5, y: y),
                    PPOCRPoint(x: x + 5, y: y + 5),
                    PPOCRPoint(x: x, y: y + 5)
                ],
                score: 0.9
            )
        }
        let sorted = PPOCRBoxSorter.sorted([
            box(x: 100, y: 20),
            box(x: 50, y: 5),
            box(x: 10, y: 20)
        ])
        XCTAssertEqual(sorted.compactMap { $0.points.first?.x }, [50, 10, 100])
    }

    func testPPOCRInvalidModelFileReturnsExplicitError() {
        XCTAssertThrowsError(try PPOCRModelFileValidator.validate(
            fileName: "broken.onnx",
            actualByteCount: 12,
            expectedByteCount: 1_024
        )) { error in
            XCTAssertEqual(error as? PPOCRError, .invalidModelFile("broken.onnx"))
        }
    }

    func testPPOCRCellFailureDoesNotDiscardOtherCellResults() throws {
        let results = try PPOCRCellFailureIsolator.run(
            items: [18, 19, 24],
            day: { $0 }
        ) { day in
            if day == 19 { throw PPOCRError.runtimeFailure("recognition") }
            return "day-\(day)"
        }

        guard case .success(let firstDay, let firstValue) = results[0],
              case .failure(let failedDay, let errorCode) = results[1],
              case .success(let lastDay, let lastValue) = results[2] else {
            return XCTFail("Unexpected isolated cell results")
        }
        XCTAssertEqual(firstDay, 18)
        XCTAssertEqual(firstValue, "day-18")
        XCTAssertEqual(failedDay, 19)
        XCTAssertEqual(errorCode, "runtimeFailure:recognition")
        XCTAssertEqual(lastDay, 24)
        XCTAssertEqual(lastValue, "day-24")
    }

    func testPPOCRTextBecomesMonthCandidateInput() throws {
        let fixture = try gridFirstFixture(day: 26)
        let run = ppOCRRun(cells: [ppOCRCell(
            day: 26,
            text: "Meeting 17:30–20:30",
            candidateText: "ミーティング 17:30–20:30"
        )])
        let plan = PPOCRMonthRecognitionRouter().makePlan(
            run: run,
            regions: [fixture.region]
        )
        var diagnostics: CalendarPhotoImportDiagnostics?
        let parsed = try fixture.parser.parseMonth(
            observations: plan.candidateInputObservations,
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            recognitionCellDiagnostics: plan.cellDiagnostics,
            recognitionModelPOC: plan.recognitionModelPOC,
            diagnosticsHandler: { diagnostics = $0 }
        )

        XCTAssertTrue(plan.visionFallbackRegions.isEmpty)
        let observation = try XCTUnwrap(plan.candidateInputObservations.first)
        XCTAssertEqual(observation.text, "Meeting 17:30–20:30")
        XCTAssertTrue(fixture.region.contains(observation))
        XCTAssertEqual(
            observation.boundingBox.x,
            fixture.region.boundingBox.minX + fixture.region.boundingBox.width * 0.08,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            observation.boundingBox.y,
            fixture.region.boundingBox.minY + fixture.region.boundingBox.height * 0.2,
            accuracy: 0.000_001
        )
        XCTAssertEqual(parsed.candidates.map(\.title), ["Meeting"])
        XCTAssertEqual(parsed.candidates.first?.startTimeMinutes, 1_050)
        XCTAssertEqual(parsed.candidates.first?.endTimeMinutes, 1_230)
        let text = try XCTUnwrap(diagnostics).plainText
        XCTAssertTrue(text.contains("recognitionMode=ppocrv6"))
        XCTAssertTrue(text.contains("ppocrSuccessCells=1"))
        XCTAssertTrue(text.contains("visionFallbackCells=0"))
        XCTAssertTrue(text.contains("candidateInput=true"))
        XCTAssertTrue(text.contains("[RecognitionModelPOC]"))
        XCTAssertTrue(text.contains("primaryModel=currentModel"))
        XCTAssertTrue(text.contains("candidateInput=semanticRecoverySelection"))
        XCTAssertTrue(text.contains("recoveryAttempted=false"))
        XCTAssertTrue(text.contains("originalText=\"Meeting 17:30–20:30\""))
        XCTAssertTrue(text.contains("originalParseResult=17:30-20:30"))
        XCTAssertTrue(text.contains("candidateModelText=\"ミーティング 17:30–20:30\""))
        XCTAssertTrue(text.contains("selectedSource=currentPPocr"))
        XCTAssertTrue(text.contains("day=26 recognitionSource=ppocrv6 cellBounds="))
        XCTAssertTrue(text.contains("sourcePixels=3000x2000"))
        XCTAssertTrue(text.contains("cropRect=(x=100,y=200,w=461,h=345)"))
        XCTAssertTrue(text.contains("cropPixels=461x345"))
        XCTAssertTrue(text.contains("padding=false"))
        XCTAssertTrue(text.contains("ppocrText=[\"Meeting 17:30–20:30\"]"))
        XCTAssertTrue(text.contains("[PPOCRDetections]"))
        XCTAssertTrue(text.contains(
            "day=26 detection=1 bbox=(x=0.0800,y=0.2000,w=0.8000,h=0.1500)"
        ))
        XCTAssertTrue(text.contains("topPx=224.2500 bottomPx=69.0000"))
        XCTAssertTrue(text.contains("candidateCreated=true"))
        XCTAssertTrue(text.contains("parsedStart=17:30"))
        XCTAssertTrue(text.contains("parsedEnd=20:30"))
        XCTAssertTrue(text.contains("remainingTitle=\"Meeting\""))
    }

    func testPPOCRSecondaryRecoveryReachesCandidateAndPreservesRawDiagnostics() throws {
        let fixture = try gridFirstFixture(day: 7)
        let run = ppOCRRun(cells: [ppOCRCell(
            day: 7,
            text: "52020.21",
            enhancedText: "20:20-21:40",
            selectedText: "20:20-21:40",
            selectedSource: .enhancedPPocr,
            recoveryReason: .timeLikeButUnparsed
        )])
        let plan = PPOCRMonthRecognitionRouter().makePlan(
            run: run,
            regions: [fixture.region]
        )
        var diagnostics: CalendarPhotoImportDiagnostics?
        let parsed = try fixture.parser.parseMonth(
            observations: plan.candidateInputObservations,
            yearMonth: fixture.yearMonth,
            weekStart: .sunday,
            grid: fixture.grid,
            defaultCalendarID: calendarID,
            calendar: utcGregorianCalendar(),
            recognitionCellDiagnostics: plan.cellDiagnostics,
            recognitionModelPOC: plan.recognitionModelPOC,
            diagnosticsHandler: { diagnostics = $0 }
        )

        let candidate = try XCTUnwrap(parsed.candidates.first)
        XCTAssertEqual(candidate.startTimeMinutes, 20 * 60 + 20)
        XCTAssertEqual(candidate.endTimeMinutes, 21 * 60 + 40)
        XCTAssertTrue(candidate.needsReview)
        let text = try XCTUnwrap(diagnostics).plainText
        XCTAssertTrue(text.contains(#"ppocrText=["52020.21"]"#))
        XCTAssertTrue(text.contains("recoveryAttempted=true"))
        XCTAssertTrue(text.contains("recoveryReason=timeLikeButUnparsed"))
        XCTAssertTrue(text.contains(#"originalText="52020.21""#))
        XCTAssertTrue(text.contains("originalParseResult=none"))
        XCTAssertTrue(text.contains(#"enhancedText="20:20-21:40""#))
        XCTAssertTrue(text.contains("enhancedParseResult=20:20-21:40"))
        XCTAssertTrue(text.contains("selectedSource=enhancedPPocr"))
        XCTAssertTrue(text.contains("selectionReason=validTimeBeatsUnparsed"))
        XCTAssertTrue(text.contains("timeParseQuality=recovered"))
    }

    func testPPOCRSuccessfulEmptyCellDoesNotUseVisionFallback() {
        let region = CalendarImportDayRegion(
            day: 22,
            boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 1, height: 1)
        )
        let plan = PPOCRMonthRecognitionRouter().makePlan(
            run: ppOCRRun(cells: [ppOCRCell(day: 22)]),
            regions: [region]
        )

        XCTAssertTrue(plan.candidateInputObservations.isEmpty)
        XCTAssertTrue(plan.visionFallbackRegions.isEmpty)
        XCTAssertEqual(plan.cellDiagnostics.first?.recognitionSource, .ppocrv6)
        XCTAssertNil(plan.cellDiagnostics.first?.ppOCRError)
    }

    func testPPOCRTechnicalFailureAloneRequestsVisionFallback() {
        let successful = CalendarImportDayRegion(
            day: 1,
            boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 0.5, height: 1)
        )
        let failed = CalendarImportDayRegion(
            day: 2,
            boundingBox: CalendarOCRBoundingBox(x: 0.5, y: 0, width: 0.5, height: 1)
        )
        let plan = PPOCRMonthRecognitionRouter().makePlan(
            run: ppOCRRun(cells: [
                ppOCRCell(day: 1, text: "09:00 Meeting"),
                ppOCRCell(day: 2, error: "runtimeFailure:recognition")
            ]),
            regions: [successful, failed]
        )

        XCTAssertEqual(plan.candidateInputObservations.map(\.text), ["09:00 Meeting"])
        XCTAssertEqual(plan.visionFallbackRegions.map(\.day), [2])
        XCTAssertEqual(plan.cellDiagnostics.map(\.recognitionSource), [
            .ppocrv6, .visionFallback
        ])
        XCTAssertEqual(plan.cellDiagnostics.last?.ppOCRError, "runtimeFailure:recognition")
    }
    private func ppOCRRun(cells: [PPOCRCellRecognitionResult]) -> PPOCRRecognitionRun {
        PPOCRRecognitionRun(
            runtimeVersion: PPOCRModelManifest.onnxRuntimeVersion,
            modelInitializedThisRun: true,
            modelInitializationMilliseconds: 10,
            totalMilliseconds: 20,
            recognitionModelPOC: PPOCRRecognitionModelPOC(
                currentModel: PPOCRModelManifest.recognizer.displayName,
                candidateModel: PPOCRModelManifest.candidateRecognizer.displayName,
                currentInitializedThisRun: true,
                candidateInitializedThisRun: true,
                currentInitializationMilliseconds: 8,
                candidateInitializationMilliseconds: 6,
                candidateInitializationError: nil,
                currentTotalMilliseconds: 5,
                candidateTotalMilliseconds: 7
            ),
            cells: cells
        )
    }

    private func ppOCRCell(
        day: Int,
        text: String? = nil,
        candidateText: String? = nil,
        enhancedText: String? = nil,
        selectedText: String? = nil,
        selectedSource: PPOCRTimeRecognitionSource = .currentPPocr,
        recoveryReason: PPOCRTimeRecoveryReason? = nil,
        error: String? = nil
    ) -> PPOCRCellRecognitionResult {
        let outputText = selectedText ?? text
        return PPOCRCellRecognitionResult(
            day: day,
            sourcePixels: PPOCRImageSize(width: 3_000, height: 2_000),
            cropRect: PPOCRPixelRect(x: 100, y: 200, width: 461, height: 345),
            paddingApplied: false,
            cellPixels: PPOCRImageSize(width: 461, height: 345),
            detectorInputPixels: PPOCRImageSize(width: 1_280, height: 960),
            results: outputText.map {
                [PPOCRTextResult(
                    text: $0,
                    confidence: 0.9,
                    boundingBox: CalendarOCRBoundingBox(
                        x: 0.08, y: 0.2, width: 0.8, height: 0.15
                    ),
                    timeParseQualityOverride: selectedSource == .currentPPocr
                        ? nil
                        : .recovered
                )]
            } ?? [],
            recognitionModelComparisons: text.map { currentText in
                [PPOCRRecognitionModelComparison(
                    boundingBox: CalendarOCRBoundingBox(
                        x: 0.08, y: 0.2, width: 0.8, height: 0.15
                    ),
                    currentText: currentText,
                    currentConfidence: 0.9,
                    currentMilliseconds: 5,
                    recoveryAttempted: recoveryReason != nil,
                    recoveryReason: recoveryReason,
                    enhancedText: enhancedText,
                    enhancedConfidence: enhancedText == nil ? nil : 0.8,
                    enhancedMilliseconds: enhancedText == nil ? nil : 4,
                    candidateText: candidateText ?? currentText,
                    candidateConfidence: 0.88,
                    candidateMilliseconds: 7,
                    candidateError: nil,
                    selectedText: outputText,
                    selectedSource: selectedSource,
                    selectionReason: selectedSource == .currentPPocr
                        ? "recoveryNotTriggered"
                        : "validTimeBeatsUnparsed"
                )]
            } ?? [],
            detectionCount: text == nil ? 0 : 1,
            timing: PPOCRCellTiming(
                preprocessMilliseconds: 1,
                detectionMilliseconds: 2,
                detectionPostprocessMilliseconds: 3,
                classificationMilliseconds: 4,
                recognitionMilliseconds: 5,
                totalMilliseconds: 15
            ),
            error: error
        )
    }
}
