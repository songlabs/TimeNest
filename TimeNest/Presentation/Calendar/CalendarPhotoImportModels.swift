import Foundation

enum CalendarPhotoCellRecognitionSource: String, Equatable, Sendable {
    case ppocrv6
    case visionFallback
}

enum CalendarPhotoRecognitionMode: String, Equatable, Sendable {
    case ppocrv6
}

struct CalendarPhotoPixelSizeDiagnostics: Equatable, Sendable {
    let width: Int
    let height: Int
}

struct CalendarPhotoPixelRectDiagnostics: Equatable, Sendable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

struct CalendarPhotoOCRDetectionDiagnostics: Equatable, Sendable {
    let text: String
    let cellLocalBoundingBox: CalendarOCRBoundingBox
    let distanceToTopPixels: Double
    let distanceToBottomPixels: Double
}

struct CalendarPhotoRecognitionModelComparisonDiagnostics: Equatable, Sendable {
    let boundingBox: CalendarOCRBoundingBox
    let currentText: String
    let currentConfidence: Float
    let currentMilliseconds: Double
    let candidateText: String?
    let candidateConfidence: Float?
    let candidateMilliseconds: Double?
    let candidateError: String?
}

struct CalendarPhotoRecognitionModelPOCDiagnostics: Equatable, Sendable {
    let currentModel: String
    let candidateModel: String
    let currentInitializedThisRun: Bool
    let candidateInitializedThisRun: Bool
    let currentInitializationMilliseconds: Double
    let candidateInitializationMilliseconds: Double
    let candidateInitializationError: String?
    let currentTotalMilliseconds: Double
    let candidateTotalMilliseconds: Double
}

struct CalendarPhotoCellRecognitionDiagnostics: Equatable, Sendable {
    let day: Int
    let recognitionSource: CalendarPhotoCellRecognitionSource
    let cellBounds: CalendarOCRBoundingBox
    let sourceImagePixels: CalendarPhotoPixelSizeDiagnostics
    let cropRect: CalendarPhotoPixelRectDiagnostics?
    let cropImagePixels: CalendarPhotoPixelSizeDiagnostics
    let paddingApplied: Bool
    let detections: [CalendarPhotoOCRDetectionDiagnostics]
    let recognitionModelComparisons: [CalendarPhotoRecognitionModelComparisonDiagnostics]
    let ppOCRText: [String]
    let ppOCRError: String?

    var fallbackUsed: Bool { recognitionSource == .visionFallback }
}

struct CalendarImportYearMonth: Equatable, Sendable {
    let year: Int
    let month: Int

    init?(year: Int, month: Int) {
        guard (1...12).contains(month), (1900...2200).contains(year) else {
            return nil
        }
        self.year = year
        self.month = month
    }

    func date(calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }
}

struct CalendarOCRBoundingBox: Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var minX: Double { x }
    var maxX: Double { x + width }
    var minY: Double { y }
    var maxY: Double { y + height }
    var midX: Double { x + width / 2 }
    var midY: Double { y + height / 2 }
}

struct CalendarOCRObservation: Equatable, Sendable {
    let text: String
    let confidence: Float
    let boundingBox: CalendarOCRBoundingBox
    var candidateDiagnostics: [CalendarOCRCandidate] = []
    var selectionReason: String? = nil
}

struct CalendarOCRCandidate: Equatable, Sendable {
    let text: String
    let confidence: Float
}

struct CalendarOCRCandidateSelector {
    static func select(from candidates: [CalendarOCRCandidate]) -> CalendarOCRCandidate? {
        guard let first = candidates.first else { return nil }
        guard candidates.contains(where: { CalendarImportTimeParser.parseRangeOnly($0.text) != nil }) else {
            return first
        }
        return candidates.max { lhs, rhs in
            score(lhs) < score(rhs)
        }
    }

    private static func score(_ candidate: CalendarOCRCandidate) -> Double {
        guard let range = CalendarImportTimeParser.parseRangeOnly(candidate.text),
              let end = range.endMinutes, end > range.startMinutes else {
            return Double(candidate.confidence)
        }
        // A structurally valid range outweighs the small confidence differences
        // between alternatives from the same Vision observation.
        return 2 + Double(candidate.confidence)
    }
}

enum CalendarPhotoScanMode: String, CaseIterable, Equatable, Sendable {
    case month
    case day
}

struct CalendarPhotoGridGeometry: Equatable, Sendable {
    let boundingBox: CalendarOCRBoundingBox
    let columns: Int
    let rows: Int
    let topLeft: CalendarPhotoGridPoint?
    let topRight: CalendarPhotoGridPoint?
    let bottomLeft: CalendarPhotoGridPoint?
    let bottomRight: CalendarPhotoGridPoint?
    let originalImagePixels: CalendarPhotoPixelSizeDiagnostics?
    let rectifiedGridPixels: CalendarPhotoPixelSizeDiagnostics?

    init(
        boundingBox: CalendarOCRBoundingBox,
        columns: Int,
        rows: Int,
        topLeft: CalendarPhotoGridPoint? = nil,
        topRight: CalendarPhotoGridPoint? = nil,
        bottomLeft: CalendarPhotoGridPoint? = nil,
        bottomRight: CalendarPhotoGridPoint? = nil,
        originalImagePixels: CalendarPhotoPixelSizeDiagnostics? = nil,
        rectifiedGridPixels: CalendarPhotoPixelSizeDiagnostics? = nil
    ) {
        self.boundingBox = boundingBox
        self.columns = columns
        self.rows = rows
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        self.originalImagePixels = originalImagePixels
        self.rectifiedGridPixels = rectifiedGridPixels
    }

    var area: Double { boundingBox.width * boundingBox.height }
}

struct CalendarPhotoGridPoint: Equatable, Sendable {
    let x: Double
    let y: Double
}

struct CalendarPhotoGridCandidate: Equatable, Sendable {
    let boundingBox: CalendarOCRBoundingBox
    let structuralConfidence: Double
    let topLeft: CalendarPhotoGridPoint?
    let topRight: CalendarPhotoGridPoint?
    let bottomLeft: CalendarPhotoGridPoint?
    let bottomRight: CalendarPhotoGridPoint?

    init(
        boundingBox: CalendarOCRBoundingBox,
        structuralConfidence: Double,
        topLeft: CalendarPhotoGridPoint? = nil,
        topRight: CalendarPhotoGridPoint? = nil,
        bottomLeft: CalendarPhotoGridPoint? = nil,
        bottomRight: CalendarPhotoGridPoint? = nil
    ) {
        self.boundingBox = boundingBox
        self.structuralConfidence = structuralConfidence
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
}

struct CalendarPhotoGridSelector {
    func selectMainGrid(
        from candidates: [CalendarPhotoGridCandidate],
        expectedRows: Int
    ) -> CalendarPhotoGridGeometry? {
        guard (4...6).contains(expectedRows) else { return nil }
        guard let selected = candidates
            .filter({ candidate in
                candidate.boundingBox.width > 0
                    && candidate.boundingBox.height > 0
                    && candidate.structuralConfidence >= 0.5
            })
            .max(by: { lhs, rhs in
                score(lhs, expectedRows: expectedRows) < score(rhs, expectedRows: expectedRows)
            }) else { return nil }
        return CalendarPhotoGridGeometry(
            boundingBox: selected.boundingBox,
            columns: 7,
            rows: expectedRows,
            topLeft: selected.topLeft,
            topRight: selected.topRight,
            bottomLeft: selected.bottomLeft,
            bottomRight: selected.bottomRight
        )
    }

    private func score(_ candidate: CalendarPhotoGridCandidate, expectedRows: Int) -> Double {
        let expectedAspect = 7.0 / Double(expectedRows)
        let actualAspect = candidate.boundingBox.width / candidate.boundingBox.height
        let aspectSimilarity = 1 / (1 + abs(log(actualAspect / expectedAspect)))
        return candidate.boundingBox.width * candidate.boundingBox.height
            * candidate.structuralConfidence * aspectSimilarity
    }
}

// Clockwise pixel rotation applied before OCR. The resulting CGImage is always `.up`.
enum CalendarPhotoRotation: Int, CaseIterable, Sendable {
    case degrees0 = 0
    case degrees90 = 90
    case degrees180 = 180
    case degrees270 = 270
}

struct CalendarPhotoOrientationEvidence: Equatable, Sendable {
    let yearMonth: CalendarImportYearMonth?
    let dateAnchorObservationCount: Int
    let dateAnchorCount: Int
    let matchedDateAnchorCount: Int
    let columnCount: Int
    let rowCount: Int
    let reliableTextCount: Int

    var hasReliableCalendarStructure: Bool {
        columnCount == 7
            && (4...6).contains(rowCount)
            && matchedDateAnchorCount >= 7
    }

    var score: Int {
        // Calendar structure deliberately outweighs header or raw OCR quantity.
        (yearMonth == nil ? 0 : 200)
            + (hasReliableCalendarStructure ? 500 : 0)
            + matchedDateAnchorCount * 20
            + min(dateAnchorCount, 31) * 3
            + min(reliableTextCount, 30)
    }
}

struct CalendarPhotoOrientationCandidate: Equatable, Sendable {
    let rotation: CalendarPhotoRotation
    let observations: [CalendarOCRObservation]
}

struct CalendarPhotoOrientationSelection: Equatable, Sendable {
    let rotation: CalendarPhotoRotation
    let observations: [CalendarOCRObservation]
    let evidence: CalendarPhotoOrientationEvidence
    let candidateDiagnostics: [CalendarPhotoOrientationCandidateDiagnostics]
}

struct CalendarPhotoOrientationCandidateDiagnostics: Equatable, Sendable {
    let rotation: CalendarPhotoRotation
    let observationCount: Int
    let dateAnchorCount: Int
    let distinctDayCount: Int
    let hasInferredYearMonth: Bool
    let gridColumnCount: Int
    let gridRowCount: Int
    let matchedDateAnchorCount: Int
    let evidenceScore: Int
}

enum CalendarPhotoOrientationEvidencePhase: String, Equatable, Sendable {
    case fast
    case accurate
}

struct CalendarPhotoOrientationDiagnostics: Equatable, Sendable {
    let selectedRotation: CalendarPhotoRotation
    let evidencePhase: CalendarPhotoOrientationEvidencePhase
    let candidates: [CalendarPhotoOrientationCandidateDiagnostics]
}

struct CalendarPhotoOrientationSelector {
    func selectBest(
        from candidates: [CalendarPhotoOrientationCandidate],
        overridingYearMonth: CalendarImportYearMonth? = nil,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> CalendarPhotoOrientationSelection? {
        let parser = CalendarPhotoParser()
        let selections = candidates.map { candidate in
            let evidence = parser.orientationEvidence(
                observations: candidate.observations,
                overridingYearMonth: overridingYearMonth,
                calendar: calendar
            )
            return CalendarPhotoOrientationSelection(
                rotation: candidate.rotation,
                observations: candidate.observations,
                evidence: evidence,
                candidateDiagnostics: []
            )
        }
        guard let selected = selections.max(by: { lhs, rhs in
            if lhs.evidence.score != rhs.evidence.score {
                return lhs.evidence.score < rhs.evidence.score
            }
            if lhs.evidence.matchedDateAnchorCount
                != rhs.evidence.matchedDateAnchorCount {
                return lhs.evidence.matchedDateAnchorCount
                    < rhs.evidence.matchedDateAnchorCount
            }
            if lhs.evidence.dateAnchorCount != rhs.evidence.dateAnchorCount {
                return lhs.evidence.dateAnchorCount < rhs.evidence.dateAnchorCount
            }
            // Keep an already-upright photo stable when all available evidence ties.
            return lhs.rotation.rawValue > rhs.rotation.rawValue
        }) else { return nil }
        let candidateDiagnostics = zip(candidates, selections).map { candidate, selection in
            CalendarPhotoOrientationCandidateDiagnostics(
                rotation: candidate.rotation,
                observationCount: candidate.observations.count,
                dateAnchorCount: selection.evidence.dateAnchorObservationCount,
                distinctDayCount: selection.evidence.dateAnchorCount,
                hasInferredYearMonth: CalendarPhotoParser.inferYearMonth(
                    from: candidate.observations
                ) != nil,
                gridColumnCount: selection.evidence.columnCount,
                gridRowCount: selection.evidence.rowCount,
                matchedDateAnchorCount: selection.evidence.matchedDateAnchorCount,
                evidenceScore: selection.evidence.score
            )
        }.sorted { $0.rotation.rawValue < $1.rotation.rawValue }
        return CalendarPhotoOrientationSelection(
            rotation: selected.rotation,
            observations: selected.observations,
            evidence: selected.evidence,
            candidateDiagnostics: candidateDiagnostics
        )
    }
}

struct CalendarImportDayRegion: Equatable, Sendable {
    let day: Int
    let boundingBox: CalendarOCRBoundingBox

    func contains(_ observation: CalendarOCRObservation) -> Bool {
        // OCR lines normally begin near the same leading edge as the date number.
        // Using the leading quarter instead of the center keeps long titles in their cell.
        let horizontalProbe = observation.boundingBox.minX
            + min(observation.boundingBox.width * 0.25, 0.02)
        let verticalProbe = observation.boundingBox.midY
        return horizontalProbe >= boundingBox.minX
            && horizontalProbe < boundingBox.maxX
            && verticalProbe >= boundingBox.minY
            && verticalProbe < boundingBox.maxY
    }
}

enum CalendarImportTimeParseQuality: String, Equatable, Sendable {
    case exact
    case normalized
    case recovered
}

struct CalendarImportParsedTime: Equatable, Sendable {
    let startMinutes: Int
    let endMinutes: Int?
    let parseQuality: CalendarImportTimeParseQuality

    init(
        startMinutes: Int,
        endMinutes: Int?,
        parseQuality: CalendarImportTimeParseQuality = .exact
    ) {
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.parseQuality = parseQuality
    }
}

enum CalendarImportCandidateQuality: String, Equatable, Sendable {
    case standard
    case lowInformation
}

struct CalendarImportCandidateQualityEvaluator {
    static func quality(
        title: String,
        parsedTime: CalendarImportParsedTime?
    ) -> CalendarImportCandidateQuality {
        guard parsedTime == nil else { return .standard }
        let normalized = title
            .folding(
                options: .widthInsensitive,
                locale: Locale(identifier: "en_US_POSIX")
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              normalized.range(
                of: #"^[\p{N}\p{P}\p{S}\s]+$"#,
                options: .regularExpression
              ) != nil else {
            return .standard
        }
        return .lowInformation
    }
}

struct CalendarImportHolidayMatcher {
    static func isExactMatch(title: String, holidayNames: Set<String>) -> Bool {
        let normalizedTitle = normalized(title)
        guard !normalizedTitle.isEmpty else { return false }
        return holidayNames.contains { normalized($0) == normalizedTitle }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(
                options: .widthInsensitive,
                locale: Locale(identifier: "en_US_POSIX")
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CalendarImportCandidate: Identifiable, Equatable {
    let id: UUID
    var date: Date
    var startTimeMinutes: Int?
    var endTimeMinutes: Int?
    var title: String
    let originalText: String
    let personToken: String?
    let confidence: Float
    let quality: CalendarImportCandidateQuality
    var isSelected: Bool
    var needsReview: Bool
    var targetCalendarID: UUID
    var includesPersonTokenInTitle: Bool

    var effectiveTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard includesPersonTokenInTitle, let personToken else { return trimmedTitle }
        guard !trimmedTitle.hasPrefix(personToken) else { return trimmedTitle }
        return [personToken, trimmedTitle]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var hasCompleteTimeRange: Bool {
        switch (startTimeMinutes, endTimeMinutes) {
        case (nil, nil):
            return true
        case let (start?, end?):
            return (0..<(24 * 60)).contains(start)
                && (0..<(24 * 60)).contains(end)
                && end > start
        default:
            return false
        }
    }

    var isValidForSaving: Bool {
        !effectiveTitle.isEmpty && hasCompleteTimeRange
    }
}

struct CalendarPhotoImportParseResult: Equatable {
    let yearMonth: CalendarImportYearMonth?
    let candidates: [CalendarImportCandidate]
    let dayRegions: [CalendarImportDayRegion]

    var requiresYearMonthSelection: Bool { yearMonth == nil }
}

enum CalendarPhotoImportParseStage: String, Equatable, Sendable {
    case text
    case yearMonth
    case dateAnchors
    case grid
    case dayRegions
    case candidates
    case completed
}

enum CalendarPhotoImportWeekStart: String, Equatable, Sendable {
    case sunday
    case monday
}

enum CalendarPhotoImportParseError: String, Error, Equatable, Sendable {
    case missingYearMonth
    case noText
    case noDateStructure
    case noCandidates
}

struct CalendarPhotoAnchorDiagnostics: Equatable, Sendable {
    let day: Int
    let midX: Double
    let midY: Double
    let width: Double
    let height: Double
    let confidence: Float
    let widthRatio: Double?
    let heightRatio: Double?
}

struct CalendarPhotoDuplicateDayDiagnostics: Equatable, Sendable {
    let day: Int
    let occurrenceCount: Int
}

struct CalendarPhotoAnchorExtentDiagnostics: Equatable, Sendable {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
}

struct CalendarPhotoAnchorSpatialDiagnostics: Equatable, Sendable {
    let topQuarterAnchorCount: Int
    let bottomThreeQuarterAnchorCount: Int
    let leftHalfAnchorCount: Int
    let rightHalfAnchorCount: Int
    let extent: CalendarPhotoAnchorExtentDiagnostics?
}

struct CalendarPhotoAnchorMappingDiagnostics: Equatable, Sendable {
    let day: Int
    let midX: Double
    let midY: Double
    let expectedColumn: Int?
    let expectedRow: Int?
    let actualColumn: Int
    let actualRow: Int
    let matched: Bool
}

struct CalendarPhotoGridAttemptDiagnostics: Equatable, Sendable {
    let weekStart: CalendarPhotoImportWeekStart
    let firstColumn: Int
    let matchedDateAnchorCount: Int
    let xCenters: [Double]
    let yCenters: [Double]
    let anchorMappings: [CalendarPhotoAnchorMappingDiagnostics]
}

enum CalendarPhotoCellRejectionReason: String, Equatable, Sendable {
    case noObservations
    case printedDayOnly
    case emptyText
    case invalidDate
}

struct CalendarPhotoCellCandidateDiagnostics: Equatable, Sendable {
    let parsedStartMinutes: Int?
    let parsedEndMinutes: Int?
    let remainingTitle: String
    let ocrConfidence: Float
    let quality: CalendarImportCandidateQuality
    let timeParseQuality: CalendarImportTimeParseQuality?
    let holidayMatch: Bool
    let needsReview: Bool
    let defaultSelected: Bool
    let candidateCreated: Bool
    let rejectedReason: CalendarPhotoCellRejectionReason?
}

struct CalendarPhotoCellDiagnostics: Equatable, Sendable {
    let day: Int
    let cellBounds: CalendarOCRBoundingBox
    let observationCount: Int
    let printedDayObservationCount: Int
    let rawTexts: [String]
    let normalizedTexts: [String]
    let candidates: [CalendarPhotoCellCandidateDiagnostics]
    let rejectedReason: CalendarPhotoCellRejectionReason?

    var contentObservationCount: Int { rawTexts.count }
    var candidateCreated: Bool { candidates.contains(where: \.candidateCreated) }
}

struct CalendarPhotoImportDiagnostics: Equatable, Sendable {
    var scanMode: CalendarPhotoScanMode? = nil
    var selectedDate: Date? = nil
    var gridDetection: String = "legacy"
    var recognitionMode: CalendarPhotoRecognitionMode? = nil
    var recognitionCellDiagnostics: [CalendarPhotoCellRecognitionDiagnostics] = []
    var recognitionModelPOC: CalendarPhotoRecognitionModelPOCDiagnostics? = nil
    var cellDiagnostics: [CalendarPhotoCellDiagnostics] = []
    var unassignedRawTexts: [String] = []
    var unassignedNormalizedTexts: [String] = []
    var gridGeometry: CalendarPhotoGridGeometry? = nil
    let orientation: CalendarPhotoOrientationDiagnostics?
    let manualYearMonth: CalendarImportYearMonth?
    let resolvedYearMonth: CalendarImportYearMonth?
    let observationCount: Int
    let meaningfulObservationCount: Int
    let pureNumericObservationCount: Int
    let dateAnchorCount: Int
    let distinctDayCount: Int
    let sundayStartScore: Int
    let mondayStartScore: Int
    let selectedWeekStart: CalendarPhotoImportWeekStart?
    let gridColumnCount: Int
    let gridRowCount: Int
    let gridMatchedAnchorCount: Int
    let gridRejectedAnchorCount: Int
    let gridAcceptanceThreshold: Int
    let gridAccepted: Bool
    let anchorMedianWidth: Double?
    let anchorMedianHeight: Double?
    let duplicateDays: [CalendarPhotoDuplicateDayDiagnostics]
    let anchorSpatialDistribution: CalendarPhotoAnchorSpatialDiagnostics
    let anchors: [CalendarPhotoAnchorDiagnostics]
    let selectedGridAttempt: CalendarPhotoGridAttemptDiagnostics?
    let gridAttempts: [CalendarPhotoGridAttemptDiagnostics]
    let dayRegionCount: Int
    let candidateCount: Int
    let parseStage: CalendarPhotoImportParseStage
    let failureReason: CalendarPhotoImportParseError?

    var shouldDisplay: Bool {
        failureReason != nil
            || candidateCount == 0
            || recognitionMode != nil
            || !cellDiagnostics.isEmpty
    }

    var ppOCRSuccessCellCount: Int {
        recognitionCellDiagnostics.filter {
            $0.recognitionSource == .ppocrv6
        }.count
    }

    var visionFallbackCellCount: Int {
        recognitionCellDiagnostics.filter(\.fallbackUsed).count
    }

    var displayFields: [(label: String, value: String)] {
        [
            ("Scan Mode", scanMode?.rawValue ?? "legacy"),
            ("Selected Date", Self.dateText(selectedDate)),
            ("Grid Detection", gridDetection),
            ("Recognition", recognitionMode?.rawValue ?? "legacy"),
            ("PP-OCR Success Cells", "\(ppOCRSuccessCellCount)"),
            ("Vision Fallback Cells", "\(visionFallbackCellCount)"),
            ("Manual YM", Self.yearMonthText(manualYearMonth)),
            ("Resolved YM", Self.yearMonthText(resolvedYearMonth)),
            ("Selected Rotation", orientation.map { "\($0.selectedRotation.rawValue)" } ?? "none"),
            ("OCR", "\(observationCount)"),
            ("Meaningful", "\(meaningfulObservationCount)"),
            ("Pure Numeric", "\(pureNumericObservationCount)"),
            ("Date Anchors", "\(dateAnchorCount)"),
            ("Distinct Days", "\(distinctDayCount)"),
            ("Duplicate Days", "\(duplicateDays.count)"),
            ("Sunday Score", "\(sundayStartScore)"),
            ("Monday Score", "\(mondayStartScore)"),
            ("Week Start", selectedWeekStart?.rawValue ?? "none"),
            ("Grid", "\(gridColumnCount) × \(gridRowCount)"),
            ("Matched", "\(gridMatchedAnchorCount)"),
            ("Rejected", "\(gridRejectedAnchorCount)"),
            ("Threshold", "\(gridAcceptanceThreshold)"),
            ("Accepted", "\(gridAccepted)"),
            ("Day Regions", "\(dayRegionCount)"),
            ("Cell Diagnostics", "\(cellDiagnostics.count)"),
            ("Content Cells", "\(cellDiagnostics.filter { $0.contentObservationCount > 0 }.count)"),
            ("Rejected Cells", "\(cellDiagnostics.filter { !$0.candidateCreated }.count)"),
            ("Unassigned OCR", "\(unassignedRawTexts.count)"),
            ("Candidates", "\(candidateCount)"),
            ("Stage", parseStage.rawValue),
            ("Failure", failureReason?.rawValue ?? "none")
        ]
    }

    var plainText: String {
        let summary = [
            "CalendarImportDiagnostics",
            "scanMode=\(scanMode?.rawValue ?? "legacy")",
            "selectedDate=\(Self.dateText(selectedDate))",
            "gridDetection=\(gridDetection)",
            "recognitionMode=\(recognitionMode?.rawValue ?? "legacy")",
            "ppocrSuccessCells=\(ppOCRSuccessCellCount)",
            "visionFallbackCells=\(visionFallbackCellCount)",
            "candidateInput=\(recognitionMode == .ppocrv6)",
            "manualYearMonth=\(Self.yearMonthText(manualYearMonth))",
            "resolvedYearMonth=\(Self.yearMonthText(resolvedYearMonth))",
            "selectedRotation=\(orientation.map { String($0.selectedRotation.rawValue) } ?? "none")",
            "orientationEvidencePhase=\(orientation?.evidencePhase.rawValue ?? "none")",
            "ocrObservations=\(observationCount)",
            "meaningful=\(meaningfulObservationCount)",
            "pureNumeric=\(pureNumericObservationCount)",
            "dateAnchors=\(dateAnchorCount)",
            "distinctDays=\(distinctDayCount)",
            "duplicateDays=\(Self.duplicateDaysText(duplicateDays))",
            "anchorMedianWidth=\(Self.decimalText(anchorMedianWidth))",
            "anchorMedianHeight=\(Self.decimalText(anchorMedianHeight))",
            "topQuarterAnchors=\(anchorSpatialDistribution.topQuarterAnchorCount)",
            "bottomThreeQuarterAnchors=\(anchorSpatialDistribution.bottomThreeQuarterAnchorCount)",
            "leftHalfAnchors=\(anchorSpatialDistribution.leftHalfAnchorCount)",
            "rightHalfAnchors=\(anchorSpatialDistribution.rightHalfAnchorCount)",
            "anchorExtent=\(Self.extentText(anchorSpatialDistribution.extent))",
            "sundayScore=\(sundayStartScore)",
            "mondayScore=\(mondayStartScore)",
            "weekStart=\(selectedWeekStart?.rawValue ?? "none")",
            "grid=\(gridColumnCount)x\(gridRowCount)",
            "gridGeometry=\(gridGeometry?.rectifiedGridPixels == nil ? "legacy" : "perspectiveCorrected")",
            "matched=\(gridMatchedAnchorCount)",
            "rejected=\(gridRejectedAnchorCount)",
            "threshold=\(gridAcceptanceThreshold)",
            "gridAccepted=\(gridAccepted)",
            "dayRegions=\(dayRegionCount)",
            "candidates=\(candidateCount)",
            "stage=\(parseStage.rawValue)",
            "failure=\(failureReason?.rawValue ?? "none")"
        ].joined(separator: "\n")

        let orientationLines = orientation?.candidates.map { candidate in
            [
                "rotation=\(candidate.rotation.rawValue)",
                "ocr=\(candidate.observationCount)",
                "dateAnchors=\(candidate.dateAnchorCount)",
                "distinctDays=\(candidate.distinctDayCount)",
                "yearMonth=\(candidate.hasInferredYearMonth)",
                "grid=\(candidate.gridColumnCount)x\(candidate.gridRowCount)",
                "matched=\(candidate.matchedDateAnchorCount)",
                "score=\(candidate.evidenceScore)"
            ].joined(separator: " ")
        } ?? []
        let recognitionLines = Self.recognitionLines(recognitionCellDiagnostics)
        let recognitionModelPOCLines: [String] = recognitionModelPOC.map { poc in
            let summary = [
                "currentModel=\(Self.quotedText(poc.currentModel))",
                "candidateModel=\(Self.quotedText(poc.candidateModel))",
                "currentInitializedThisRun=\(poc.currentInitializedThisRun)",
                "candidateInitializedThisRun=\(poc.candidateInitializedThisRun)",
                "currentInitializationMs=\(Self.decimalText(poc.currentInitializationMilliseconds))",
                "candidateInitializationMs=\(Self.decimalText(poc.candidateInitializationMilliseconds))",
                "candidateInitializationError=\(poc.candidateInitializationError ?? "none")",
                "currentTotalMs=\(Self.decimalText(poc.currentTotalMilliseconds))",
                "candidateTotalMs=\(Self.decimalText(poc.candidateTotalMilliseconds))",
                "candidateInput=currentModel"
            ].joined(separator: " ")
            let comparisons = recognitionCellDiagnostics
                .sorted(by: { $0.day < $1.day })
                .flatMap { cell in
                    cell.recognitionModelComparisons.enumerated().map { index, comparison in
                        let bounds = comparison.boundingBox
                        return [
                            "day=\(cell.day)",
                            "detection=\(index + 1)",
                            "bbox=(x=\(Self.decimalText(bounds.x)),y=\(Self.decimalText(bounds.y)),w=\(Self.decimalText(bounds.width)),h=\(Self.decimalText(bounds.height)))",
                            "currentText=\(Self.quotedText(comparison.currentText))",
                            "currentConfidence=\(Self.decimalText(Double(comparison.currentConfidence)))",
                            "candidateText=\(comparison.candidateText.map(Self.quotedText) ?? "none")",
                            "candidateConfidence=\(Self.decimalText(comparison.candidateConfidence.map(Double.init)))",
                            "currentRecognitionMs=\(Self.decimalText(comparison.currentMilliseconds))",
                            "candidateRecognitionMs=\(Self.decimalText(comparison.candidateMilliseconds))",
                            "candidateError=\(comparison.candidateError ?? "none")"
                        ].joined(separator: " ")
                    }
                }
            return [summary] + comparisons
        } ?? []
        let geometryLines: [String] = gridGeometry.map { grid in
            let rows = (0...grid.rows).map { boundary in
                guard let pixels = grid.rectifiedGridPixels else { return 0 }
                return Int((Double(boundary) * Double(pixels.height) / Double(grid.rows)).rounded())
            }
            let columns = (0...grid.columns).map { boundary in
                guard let pixels = grid.rectifiedGridPixels else { return 0 }
                return Int((Double(boundary) * Double(pixels.width) / Double(grid.columns)).rounded())
            }
            return [
                "gridGeometry=\(grid.rectifiedGridPixels == nil ? "legacy" : "perspectiveCorrected")",
                "topLeft=\(Self.pointText(grid.topLeft)) topRight=\(Self.pointText(grid.topRight)) bottomLeft=\(Self.pointText(grid.bottomLeft)) bottomRight=\(Self.pointText(grid.bottomRight))",
                "originalImagePixels=\(Self.optionalPixelSizeText(grid.originalImagePixels)) rectifiedGridPixels=\(Self.optionalPixelSizeText(grid.rectifiedGridPixels))",
                "gridRows=\(grid.rows) gridColumns=\(grid.columns)",
                "rowBoundariesPx=\(rows) columnBoundariesPx=\(columns)"
            ]
        } ?? []

        let gridAttemptLines = gridAttempts.map { attempt in
            [
                "weekStart=\(attempt.weekStart.rawValue)",
                "firstColumn=\(attempt.firstColumn)",
                "rowCount=\(attempt.yCenters.count)",
                "matched=\(attempt.matchedDateAnchorCount)"
            ].joined(separator: " ")
        }
        let xCenterLines = Self.centerLines(
            selected: selectedGridAttempt,
            attempts: gridAttempts,
            keyPath: \.xCenters
        )
        let yCenterLines = Self.centerLines(
            selected: selectedGridAttempt,
            attempts: gridAttempts,
            keyPath: \.yCenters
        )
        let anchorLines = anchors.map { anchor in
            [
                "day=\(anchor.day)",
                "x=\(Self.decimalText(anchor.midX))",
                "y=\(Self.decimalText(anchor.midY))",
                "w=\(Self.decimalText(anchor.width))",
                "h=\(Self.decimalText(anchor.height))",
                "conf=\(Self.decimalText(Double(anchor.confidence)))",
                "widthRatio=\(Self.decimalText(anchor.widthRatio))",
                "heightRatio=\(Self.decimalText(anchor.heightRatio))"
            ].joined(separator: " ")
        }
        let mappingLines = gridAttempts.flatMap { attempt -> [String] in
            let header = [
                "weekStart=\(attempt.weekStart.rawValue)",
                "firstColumn=\(attempt.firstColumn)",
                "rowCount=\(attempt.yCenters.count)",
                "matched=\(attempt.matchedDateAnchorCount)"
            ].joined(separator: " ")
            return [header] + attempt.anchorMappings.map { mapping in
                [
                    "day=\(mapping.day)",
                    "x=\(Self.decimalText(mapping.midX))",
                    "y=\(Self.decimalText(mapping.midY))",
                    "expected=(\(Self.integerText(mapping.expectedColumn)),\(Self.integerText(mapping.expectedRow)))",
                    "actual=(\(mapping.actualColumn),\(mapping.actualRow))",
                    "matched=\(mapping.matched)"
                ].joined(separator: " ")
            }
        }
        let recognitionByDay = Dictionary(
            uniqueKeysWithValues: recognitionCellDiagnostics.map { ($0.day, $0) }
        )
        let cellLines = cellDiagnostics.flatMap { cell -> [String] in
            let bounds = cell.cellBounds
            let recognition = recognitionByDay[cell.day]
            let firstCandidate = cell.candidates.first
            let header = [
                "day=\(cell.day)",
                "recognitionSource=\(recognition?.recognitionSource.rawValue ?? "unknown")",
                "ppocrText=\(Self.textList(recognition?.ppOCRText ?? []))",
                "ppocrError=\(recognition?.ppOCRError ?? "none")",
                "candidateCreated=\(cell.candidateCreated)",
                "parsedStart=\(Self.timeText(firstCandidate?.parsedStartMinutes))",
                "parsedEnd=\(Self.timeText(firstCandidate?.parsedEndMinutes))",
                "remainingTitle=\(Self.quotedText(firstCandidate?.remainingTitle ?? ""))",
                "ocrConfidence=\(Self.decimalText(firstCandidate.map { Double($0.ocrConfidence) }))",
                "quality=\(firstCandidate?.quality.rawValue ?? "none")",
                "timeParseQuality=\(firstCandidate?.timeParseQuality?.rawValue ?? "none")",
                "holidayMatch=\(firstCandidate?.holidayMatch.description ?? "none")",
                "needsReview=\(firstCandidate?.needsReview.description ?? "none")",
                "defaultSelected=\(firstCandidate?.defaultSelected.description ?? "none")",
                "cellBounds=(x=\(Self.decimalText(bounds.x)),y=\(Self.decimalText(bounds.y)),w=\(Self.decimalText(bounds.width)),h=\(Self.decimalText(bounds.height)))",
                "observations=\(cell.observationCount)",
                "printedDay=\(cell.printedDayObservationCount)",
                "content=\(cell.contentObservationCount)",
                "rawTexts=\(Self.textList(cell.rawTexts))",
                "normalizedTexts=\(Self.textList(cell.normalizedTexts))",
                "candidates=\(cell.candidates.count)",
                "rejectedReason=\(cell.rejectedReason?.rawValue ?? "none")"
            ].joined(separator: " ")
            let candidateLines = cell.candidates.enumerated().map { index, candidate in
                [
                    "day=\(cell.day)",
                    "candidate=\(index + 1)",
                    "parsedStart=\(Self.timeText(candidate.parsedStartMinutes))",
                    "parsedEnd=\(Self.timeText(candidate.parsedEndMinutes))",
                    "remainingTitle=\(Self.quotedText(candidate.remainingTitle))",
                    "ocrConfidence=\(Self.decimalText(Double(candidate.ocrConfidence)))",
                    "quality=\(candidate.quality.rawValue)",
                    "timeParseQuality=\(candidate.timeParseQuality?.rawValue ?? "none")",
                    "holidayMatch=\(candidate.holidayMatch)",
                    "needsReview=\(candidate.needsReview)",
                    "defaultSelected=\(candidate.defaultSelected)",
                    "candidateCreated=\(candidate.candidateCreated)",
                    "rejectedReason=\(candidate.rejectedReason?.rawValue ?? "none")"
                ].joined(separator: " ")
            }
            return [header] + candidateLines
        }
        let unassignedLines = unassignedRawTexts.isEmpty
            ? []
            : [[
                "observations=\(unassignedRawTexts.count)",
                "rawTexts=\(Self.textList(unassignedRawTexts))",
                "normalizedTexts=\(Self.textList(unassignedNormalizedTexts))"
            ].joined(separator: " ")]
        let ppOCRDetectionLines = recognitionCellDiagnostics
            .sorted(by: { $0.day < $1.day })
            .flatMap { cell in
                cell.detections.enumerated().map { index, detection in
                    let bounds = detection.cellLocalBoundingBox
                    return [
                        "day=\(cell.day)",
                        "detection=\(index + 1)",
                        "bbox=(x=\(Self.decimalText(bounds.x)),y=\(Self.decimalText(bounds.y)),w=\(Self.decimalText(bounds.width)),h=\(Self.decimalText(bounds.height)))",
                        "topPx=\(Self.decimalText(detection.distanceToTopPixels))",
                        "bottomPx=\(Self.decimalText(detection.distanceToBottomPixels))",
                        "text=\(Self.quotedText(detection.text))"
                    ].joined(separator: " ")
                }
            }

        return [
            summary,
            Self.section(title: "RecognitionCells", lines: recognitionLines),
            Self.section(title: "RecognitionModelPOC", lines: recognitionModelPOCLines),
            Self.section(title: "PPOCRDetections", lines: ppOCRDetectionLines),
            Self.section(title: "GridGeometry", lines: geometryLines),
            Self.section(title: "Orientations", lines: orientationLines),
            Self.section(title: "GridAttempts", lines: gridAttemptLines),
            Self.section(title: "XCenters", lines: xCenterLines),
            Self.section(title: "YCenters", lines: yCenterLines),
            Self.section(title: "Anchors", lines: anchorLines),
            Self.section(title: "AnchorMapping", lines: mappingLines),
            Self.section(title: "Cells", lines: cellLines),
            Self.section(title: "Unassigned", lines: unassignedLines)
        ].joined(separator: "\n\n")
    }

    private static func recognitionLines(
        _ cells: [CalendarPhotoCellRecognitionDiagnostics]
    ) -> [String] {
        cells.sorted(by: { $0.day < $1.day }).map { cell in
            let bounds = cell.cellBounds
            return [
                "day=\(cell.day)",
                "recognitionSource=\(cell.recognitionSource.rawValue)",
                "cellBounds=(x=\(decimalText(bounds.x)),y=\(decimalText(bounds.y)),w=\(decimalText(bounds.width)),h=\(decimalText(bounds.height)))",
                "sourcePixels=\(pixelSizeText(cell.sourceImagePixels))",
                "cropRect=\(pixelRectText(cell.cropRect))",
                "cropPixels=\(pixelSizeText(cell.cropImagePixels))",
                "padding=\(cell.paddingApplied)",
                "ppocrText=\(textList(cell.ppOCRText))",
                "ppocrError=\(cell.ppOCRError ?? "none")",
                "fallbackUsed=\(cell.fallbackUsed)"
            ].joined(separator: " ")
        }
    }

    private static func pixelSizeText(_ size: CalendarPhotoPixelSizeDiagnostics) -> String {
        "\(size.width)x\(size.height)"
    }

    private static func optionalPixelSizeText(_ size: CalendarPhotoPixelSizeDiagnostics?) -> String {
        guard let size else { return "none" }
        return pixelSizeText(size)
    }

    private static func pointText(_ point: CalendarPhotoGridPoint?) -> String {
        guard let point else { return "none" }
        return "(x=\(decimalText(point.x)),y=\(decimalText(point.y)))"
    }

    private static func pixelRectText(_ rect: CalendarPhotoPixelRectDiagnostics?) -> String {
        guard let rect else { return "none" }
        return "(x=\(rect.x),y=\(rect.y),w=\(rect.width),h=\(rect.height))"
    }

    private static func dayRangesText(_ days: [Int]) -> String {
        let sortedDays = Array(Set(days)).sorted()
        guard let first = sortedDays.first else { return "none" }
        var ranges: [String] = []
        var start = first
        var previous = first
        for day in sortedDays.dropFirst() {
            if day == previous + 1 {
                previous = day
                continue
            }
            ranges.append(start == previous ? "\(start)" : "\(start)-\(previous)")
            start = day
            previous = day
        }
        ranges.append(start == previous ? "\(start)" : "\(start)-\(previous)")
        return ranges.joined(separator: ",")
    }

    private static func yearMonthText(_ yearMonth: CalendarImportYearMonth?) -> String {
        guard let yearMonth else { return "none" }
        return String(format: "%04d-%02d", yearMonth.year, yearMonth.month)
    }

    private static func dateText(_ date: Date?) -> String {
        guard let date else { return "none" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func duplicateDaysText(
        _ duplicateDays: [CalendarPhotoDuplicateDayDiagnostics]
    ) -> String {
        guard !duplicateDays.isEmpty else { return "none" }
        return duplicateDays.map { "\($0.day):\($0.occurrenceCount)" }
            .joined(separator: ",")
    }

    private static func extentText(_ extent: CalendarPhotoAnchorExtentDiagnostics?) -> String {
        guard let extent else { return "none" }
        return [
            "minX=\(decimalText(extent.minX))",
            "maxX=\(decimalText(extent.maxX))",
            "minY=\(decimalText(extent.minY))",
            "maxY=\(decimalText(extent.maxY))"
        ].joined(separator: ",")
    }

    private static func centerLines(
        selected: CalendarPhotoGridAttemptDiagnostics?,
        attempts: [CalendarPhotoGridAttemptDiagnostics],
        keyPath: KeyPath<CalendarPhotoGridAttemptDiagnostics, [Double]>
    ) -> [String] {
        var lines: [String] = []
        if let selected {
            lines.append("selected=\(centerText(selected[keyPath: keyPath]))")
        }
        lines.append(contentsOf: attempts.map {
            "\($0.weekStart.rawValue)=\(centerText($0[keyPath: keyPath]))"
        })
        return lines
    }

    private static func centerText(_ centers: [Double]) -> String {
        centers.map(decimalText).joined(separator: ",")
    }

    private static func decimalText(_ value: Double?) -> String {
        guard let value else { return "none" }
        return String(
            format: "%.4f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }

    private static func integerText(_ value: Int?) -> String {
        value.map(String.init) ?? "none"
    }

    private static func timeText(_ minutes: Int?) -> String {
        guard let minutes else { return "none" }
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private static func textList(_ values: [String]) -> String {
        "[" + values.map(quotedText).joined(separator: ",") + "]"
    }

    private static func quotedText(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    private static func section(title: String, lines: [String]) -> String {
        (["[\(title)]"] + (lines.isEmpty ? ["none"] : lines))
            .joined(separator: "\n")
    }
}

struct CalendarImportTimeParser {
    private struct MatchResult {
        let time: CalendarImportParsedTime
        let range: NSRange
    }

    static func parse(_ text: String) -> CalendarImportParsedTime? {
        match(in: text)?.time
    }

    static func parseRangeOnly(_ text: String) -> CalendarImportParsedTime? {
        guard let parsed = parse(text), parsed.endMinutes != nil else { return nil }
        return parsed
    }

    static func removingTime(from text: String) -> String {
        guard let match = match(in: text),
              let range = Range(match.range, in: text) else {
            return text
        }
        var result = text
        result.removeSubrange(range)
        return result
    }

    private static func match(in text: String) -> MatchResult? {
        // A compact end time (for example 2030) is accepted only after an
        // explicit range separator; unrelated four-digit text is never guessed.
        // PP-OCR can confuse the hour/minute punctuation with `=` or `.`.
        // Accept those weaker separators only inside a complete time range so
        // ordinary version numbers or key/value text are not treated as time.
        // Compact HMM/HHMM is accepted only as one complete, bounded range
        // endpoint. This deliberately rejects five-digit or embedded OCR noise.
        let compactToDelimitedRangePattern = #"(?<![\p{L}\p{N}])(\d{1,2})(\d{2})\s*[-–—〜～~]\s*(\d{1,2})\s*[:：.=]\s*(\d{2})(?![\p{L}\p{N}])"#
        if let match = firstMatch(pattern: compactToDelimitedRangePattern, text: text),
           let parsed = parsedTime(match: match, text: text, parseQuality: .recovered) {
            return MatchResult(time: parsed, range: match.range)
        }

        let compactRangePattern = #"(?<![\p{L}\p{N}])(\d{1,2})(\d{2})\s*[-–—〜～~]\s*(\d{1,2})(\d{2})(?![\p{L}\p{N}])"#
        if let match = firstMatch(pattern: compactRangePattern, text: text),
           let parsed = parsedTime(match: match, text: text, parseQuality: .recovered) {
            return MatchResult(time: parsed, range: match.range)
        }

        let ocrRangePattern = #"(?<!\d)(\d{1,2})\s*[.=]\s*(\d{2})\s*[-–—〜～~]\s*(\d{1,2})\s*[:：.=]?\s*(\d{2})(?!\d)"#
        if let match = firstMatch(pattern: ocrRangePattern, text: text),
           let parsed = parsedTime(
               match: match,
               text: text,
               parseQuality: hasCompactEnd(match: match, text: text)
                   ? .recovered
                   : .normalized
           ) {
            return MatchResult(time: parsed, range: match.range)
        }

        let clockPattern = #"(?<!\d)(\d{1,2})\s*[:：]\s*(\d{2})(?:\s*[-–—〜～~]\s*(\d{1,2})\s*[:：.=]?\s*(\d{2}))?(?!\d)"#
        if let match = firstMatch(pattern: clockPattern, text: text),
           let parsed = parsedTime(
               match: match,
               text: text,
               parseQuality: clockParseQuality(match: match, text: text)
           ) {
            return MatchResult(time: parsed, range: match.range)
        }

        let japanesePattern = #"(?<!\d)(\d{1,2})\s*時\s*(\d{1,2})\s*分(?:\s*[-–—〜～~]\s*(\d{1,2})\s*時\s*(\d{1,2})\s*分)?(?!\d)"#
        if let match = firstMatch(pattern: japanesePattern, text: text),
           let parsed = parsedTime(
               match: match,
               text: text,
               parseQuality: containsNormalizedRangeSeparator(match: match, text: text)
                   ? .normalized
                   : .exact
           ) {
            return MatchResult(time: parsed, range: match.range)
        }
        return nil
    }

    private static func clockParseQuality(
        match: NSTextCheckingResult,
        text: String
    ) -> CalendarImportTimeParseQuality {
        if hasCompactEnd(match: match, text: text) {
            return .recovered
        }
        guard let matchedText = matchedText(match: match, text: text) else {
            return .exact
        }
        return matchedText.range(
            of: #"[：.=–—〜～~]"#,
            options: .regularExpression
        ) == nil ? .exact : .normalized
    }

    private static func hasCompactEnd(
        match: NSTextCheckingResult,
        text: String
    ) -> Bool {
        guard match.numberOfRanges > 4 else { return false }
        let hourRange = match.range(at: 3)
        let minuteRange = match.range(at: 4)
        guard hourRange.location != NSNotFound,
              minuteRange.location != NSNotFound,
              minuteRange.location >= NSMaxRange(hourRange) else {
            return false
        }
        let betweenRange = NSRange(
            location: NSMaxRange(hourRange),
            length: minuteRange.location - NSMaxRange(hourRange)
        )
        guard let range = Range(betweenRange, in: text) else { return false }
        return text[range].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func containsNormalizedRangeSeparator(
        match: NSTextCheckingResult,
        text: String
    ) -> Bool {
        matchedText(match: match, text: text)?.range(
            of: #"[–—〜～~]"#,
            options: .regularExpression
        ) != nil
    }

    private static func matchedText(
        match: NSTextCheckingResult,
        text: String
    ) -> String? {
        guard let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }

    private static func firstMatch(pattern: String, text: String) -> NSTextCheckingResult? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range)
    }

    private static func parsedTime(
        match: NSTextCheckingResult,
        text: String,
        parseQuality: CalendarImportTimeParseQuality
    ) -> CalendarImportParsedTime? {
        guard let startHour = integer(at: 1, match: match, text: text),
              let startMinute = integer(at: 2, match: match, text: text),
              isValid(hour: startHour, minute: startMinute) else {
            return nil
        }

        let endHour = integer(at: 3, match: match, text: text)
        let endMinute = integer(at: 4, match: match, text: text)
        let end: Int?
        if let endHour, let endMinute, isValid(hour: endHour, minute: endMinute) {
            end = endHour * 60 + endMinute
        } else if endHour == nil, endMinute == nil {
            end = nil
        } else {
            return nil
        }
        return CalendarImportParsedTime(
            startMinutes: startHour * 60 + startMinute,
            endMinutes: end,
            parseQuality: parseQuality
        )
    }

    private static func integer(
        at index: Int,
        match: NSTextCheckingResult,
        text: String
    ) -> Int? {
        guard index < match.numberOfRanges,
              match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: text) else {
            return nil
        }
        return Int(text[range])
    }

    private static func isValid(hour: Int, minute: Int) -> Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
    }
}

struct CalendarPhotoGridFirstParser {
    func expectedRows(
        yearMonth: CalendarImportYearMonth,
        weekStart: CalendarPhotoImportWeekStart,
        calendar inputCalendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int? {
        guard let values = monthValues(
            yearMonth: yearMonth,
            weekStart: weekStart,
            calendar: inputCalendar
        ) else { return nil }
        return Int(ceil(Double(values.firstColumn + values.dayCount) / 7.0))
    }

    func dayRegions(
        yearMonth: CalendarImportYearMonth,
        weekStart: CalendarPhotoImportWeekStart,
        grid: CalendarPhotoGridGeometry,
        calendar inputCalendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [CalendarImportDayRegion] {
        guard grid.columns == 7,
              let values = monthValues(
                yearMonth: yearMonth,
                weekStart: weekStart,
                calendar: inputCalendar
              ),
              grid.rows == Int(ceil(Double(values.firstColumn + values.dayCount) / 7.0)) else {
            return []
        }
        let cellWidth = grid.boundingBox.width / 7
        let cellHeight = grid.boundingBox.height / Double(grid.rows)
        return (1...values.dayCount).map { day in
            let index = values.firstColumn + day - 1
            let column = index % 7
            let row = index / 7
            return CalendarImportDayRegion(
                day: day,
                boundingBox: CalendarOCRBoundingBox(
                    x: grid.boundingBox.minX + Double(column) * cellWidth,
                    y: grid.boundingBox.maxY - Double(row + 1) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
            )
        }
    }

    func parseMonth(
        observations: [CalendarOCRObservation],
        yearMonth: CalendarImportYearMonth,
        weekStart: CalendarPhotoImportWeekStart,
        grid: CalendarPhotoGridGeometry,
        defaultCalendarID: UUID,
        holidayNamesByDate: [DateOnly: Set<String>] = [:],
        calendar inputCalendar: Calendar = Calendar(identifier: .gregorian),
        orientationDiagnostics: CalendarPhotoOrientationDiagnostics? = nil,
        recognitionCellDiagnostics: [CalendarPhotoCellRecognitionDiagnostics] = [],
        recognitionModelPOC: CalendarPhotoRecognitionModelPOCDiagnostics? = nil,
        diagnosticsHandler: ((CalendarPhotoImportDiagnostics) -> Void)? = nil
    ) throws -> CalendarPhotoImportParseResult {
        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        guard let monthStart = yearMonth.date(calendar: calendar) else {
            throw CalendarPhotoImportParseError.noDateStructure
        }
        let regions = dayRegions(
            yearMonth: yearMonth,
            weekStart: weekStart,
            grid: grid,
            calendar: calendar
        )
        guard !regions.isEmpty else {
            diagnosticsHandler?(makeDiagnostics(
                observations: observations,
                yearMonth: yearMonth,
                weekStart: weekStart,
                grid: grid,
                regions: [],
                buildResult: CalendarPhotoMonthCandidateBuildResult(
                    candidates: [],
                    cellDiagnostics: []
                ),
                candidateCount: 0,
                recognitionCellDiagnostics: recognitionCellDiagnostics,
                recognitionModelPOC: recognitionModelPOC,
                orientationDiagnostics: orientationDiagnostics,
                stage: .dayRegions,
                failureReason: .noDateStructure
            ))
            throw CalendarPhotoImportParseError.noDateStructure
        }
        let buildResult = CalendarImportCandidateBuilder().makeMonthCandidates(
            observations: observations,
            regions: regions,
            monthStart: monthStart,
            calendarID: defaultCalendarID,
            holidayNamesByDate: holidayNamesByDate,
            calendar: calendar
        )
        let candidates = Self.stablyOrderedByDate(buildResult.candidates)
        let failureReason: CalendarPhotoImportParseError? = candidates.isEmpty
            ? .noCandidates
            : nil
        diagnosticsHandler?(makeDiagnostics(
            observations: observations,
            yearMonth: yearMonth,
            weekStart: weekStart,
            grid: grid,
            regions: regions,
            buildResult: buildResult,
            candidateCount: candidates.count,
            recognitionCellDiagnostics: recognitionCellDiagnostics,
            recognitionModelPOC: recognitionModelPOC,
            orientationDiagnostics: orientationDiagnostics,
            stage: candidates.isEmpty ? .candidates : .completed,
            failureReason: failureReason
        ))
        guard !candidates.isEmpty else { throw CalendarPhotoImportParseError.noCandidates }
        return CalendarPhotoImportParseResult(
            yearMonth: yearMonth,
            candidates: candidates,
            dayRegions: regions
        )
    }

    private func monthValues(
        yearMonth: CalendarImportYearMonth,
        weekStart: CalendarPhotoImportWeekStart,
        calendar inputCalendar: Calendar
    ) -> (firstColumn: Int, dayCount: Int)? {
        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        guard let monthStart = yearMonth.date(calendar: calendar),
              let days = calendar.range(of: .day, in: .month, for: monthStart) else {
            return nil
        }
        let weekday = calendar.component(.weekday, from: monthStart)
        let firstColumn = weekStart == .monday ? (weekday + 5) % 7 : weekday - 1
        return (firstColumn, days.count)
    }

    private func makeDiagnostics(
        observations: [CalendarOCRObservation],
        yearMonth: CalendarImportYearMonth,
        weekStart: CalendarPhotoImportWeekStart,
        grid: CalendarPhotoGridGeometry,
        regions: [CalendarImportDayRegion],
        buildResult: CalendarPhotoMonthCandidateBuildResult,
        candidateCount: Int,
        recognitionCellDiagnostics: [CalendarPhotoCellRecognitionDiagnostics],
        recognitionModelPOC: CalendarPhotoRecognitionModelPOCDiagnostics?,
        orientationDiagnostics: CalendarPhotoOrientationDiagnostics?,
        stage: CalendarPhotoImportParseStage,
        failureReason: CalendarPhotoImportParseError?
    ) -> CalendarPhotoImportDiagnostics {
        let meaningful = observations.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let pureNumericCount = meaningful.filter { observation in
            let normalized = observation.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(
                    options: .widthInsensitive,
                    locale: Locale(identifier: "en_US_POSIX")
                )
            return normalized.range(
                of: #"^\d+$"#,
                options: .regularExpression
            ) != nil
        }.count
        return CalendarPhotoImportDiagnostics(
            scanMode: .month,
            selectedDate: nil,
            gridDetection: "visionRectangle",
            recognitionMode: Self.recognitionMode(for: recognitionCellDiagnostics),
            recognitionCellDiagnostics: recognitionCellDiagnostics,
            recognitionModelPOC: recognitionModelPOC,
            cellDiagnostics: buildResult.cellDiagnostics,
            unassignedRawTexts: buildResult.unassignedRawTexts,
            unassignedNormalizedTexts: buildResult.unassignedNormalizedTexts,
            gridGeometry: grid,
            orientation: orientationDiagnostics,
            manualYearMonth: yearMonth,
            resolvedYearMonth: yearMonth,
            observationCount: observations.count,
            meaningfulObservationCount: meaningful.count,
            pureNumericObservationCount: pureNumericCount,
            dateAnchorCount: 0,
            distinctDayCount: 0,
            sundayStartScore: 0,
            mondayStartScore: 0,
            selectedWeekStart: weekStart,
            gridColumnCount: grid.columns,
            gridRowCount: grid.rows,
            gridMatchedAnchorCount: 0,
            gridRejectedAnchorCount: 0,
            gridAcceptanceThreshold: 0,
            gridAccepted: !regions.isEmpty,
            anchorMedianWidth: nil,
            anchorMedianHeight: nil,
            duplicateDays: [],
            anchorSpatialDistribution: CalendarPhotoAnchorSpatialDiagnostics(
                topQuarterAnchorCount: 0,
                bottomThreeQuarterAnchorCount: 0,
                leftHalfAnchorCount: 0,
                rightHalfAnchorCount: 0,
                extent: nil
            ),
            anchors: [],
            selectedGridAttempt: nil,
            gridAttempts: [],
            dayRegionCount: regions.count,
            candidateCount: candidateCount,
            parseStage: stage,
            failureReason: failureReason
        )
    }

    private static func recognitionMode(
        for cells: [CalendarPhotoCellRecognitionDiagnostics]
    ) -> CalendarPhotoRecognitionMode? {
        cells.isEmpty ? nil : .ppocrv6
    }

    private static func stablyOrderedByDate(
        _ candidates: [CalendarImportCandidate]
    ) -> [CalendarImportCandidate] {
        candidates.enumerated().sorted { lhs, rhs in
            if lhs.element.date != rhs.element.date {
                return lhs.element.date < rhs.element.date
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}

struct CalendarPhotoDayParser {
    func parse(
        observations: [CalendarOCRObservation],
        selectedDate: Date,
        defaultCalendarID: UUID,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) throws -> CalendarPhotoImportParseResult {
        let meaningful = observations.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !meaningful.isEmpty else { throw CalendarPhotoImportParseError.noText }
        let candidates = CalendarImportCandidateBuilder().makeDayCandidates(
            observations: meaningful,
            selectedDate: selectedDate,
            calendarID: defaultCalendarID,
            calendar: calendar
        )
        guard !candidates.isEmpty else { throw CalendarPhotoImportParseError.noCandidates }
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        return CalendarPhotoImportParseResult(
            yearMonth: components.year.flatMap { year in
                components.month.flatMap { CalendarImportYearMonth(year: year, month: $0) }
            },
            candidates: candidates,
            dayRegions: []
        )
    }
}

private struct CalendarPhotoMonthCandidateBuildResult {
    let candidates: [CalendarImportCandidate]
    let cellDiagnostics: [CalendarPhotoCellDiagnostics]
    var unassignedRawTexts: [String] = []
    var unassignedNormalizedTexts: [String] = []
}

private struct CalendarImportCandidateBuilder {
    private struct Line { var observations: [CalendarOCRObservation] }

    private struct ParsedLine {
        let observations: [CalendarOCRObservation]
        let rawText: String
        let normalizedText: String
        let time: CalendarImportParsedTime?
    }

    func makeMonthCandidates(
        observations: [CalendarOCRObservation],
        regions: [CalendarImportDayRegion],
        monthStart: Date,
        calendarID: UUID,
        holidayNamesByDate: [DateOnly: Set<String>],
        calendar: Calendar
    ) -> CalendarPhotoMonthCandidateBuildResult {
        var candidates: [CalendarImportCandidate] = []
        var diagnostics: [CalendarPhotoCellDiagnostics] = []

        for region in regions.sorted(by: { $0.day < $1.day }) {
            let assigned = observations.filter(region.contains)
            let printedDayCount = assigned.filter {
                isPrintedDay($0, in: region)
            }.count
            let content = assigned
                .filter { !isPrintedDay($0, in: region) }
                .sorted(by: observationOrder)
            let meaningful = content.filter {
                !normalizedText($0.text).isEmpty
            }
            let date = calendar.date(
                byAdding: .day,
                value: region.day - 1,
                to: monthStart
            )
            let cellCandidates: [CalendarImportCandidate]
            let candidateDiagnostics: [CalendarPhotoCellCandidateDiagnostics]
            if let date {
                let holidayNames = DateOnly(from: date, in: calendar.timeZone)
                    .map { holidayNamesByDate[$0] ?? [] } ?? []
                (cellCandidates, candidateDiagnostics) = makeMonthCellCandidates(
                    observations: meaningful,
                    date: date,
                    calendarID: calendarID,
                    holidayNames: holidayNames
                )
            } else {
                cellCandidates = []
                candidateDiagnostics = []
            }
            candidates.append(contentsOf: cellCandidates)

            let rejectedReason: CalendarPhotoCellRejectionReason?
            if !cellCandidates.isEmpty {
                rejectedReason = nil
            } else if date == nil {
                rejectedReason = .invalidDate
            } else if assigned.isEmpty {
                rejectedReason = .noObservations
            } else if content.isEmpty {
                rejectedReason = .printedDayOnly
            } else {
                rejectedReason = .emptyText
            }
            diagnostics.append(CalendarPhotoCellDiagnostics(
                day: region.day,
                cellBounds: region.boundingBox,
                observationCount: assigned.count,
                printedDayObservationCount: printedDayCount,
                rawTexts: content.map(\.text),
                normalizedTexts: content.map { normalizedText($0.text) },
                candidates: candidateDiagnostics,
                rejectedReason: rejectedReason
            ))
        }
        let unassigned = observations
            .filter { observation in
                !regions.contains { $0.contains(observation) }
            }
            .sorted(by: observationOrder)
        return CalendarPhotoMonthCandidateBuildResult(
            candidates: candidates,
            cellDiagnostics: diagnostics,
            unassignedRawTexts: unassigned.map(\.text),
            unassignedNormalizedTexts: unassigned.map { normalizedText($0.text) }
        )
    }

    func makeDayCandidates(
        observations: [CalendarOCRObservation],
        selectedDate: Date,
        calendarID: UUID,
        calendar: Calendar
    ) -> [CalendarImportCandidate] {
        let fixedDate = calendar.startOfDay(for: selectedDate)
        return make(
            observations: observations.filter { !isStandaloneDate($0.text) },
            date: fixedDate,
            calendarID: calendarID
        )
    }

    private func make(
        observations: [CalendarOCRObservation],
        date: Date,
        calendarID: UUID
    ) -> [CalendarImportCandidate] {
        group(observations).compactMap { line in
            let sorted = line.observations.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            let original = sorted.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !original.isEmpty, let time = CalendarImportTimeParser.parse(original) else {
                return nil
            }
            let token = personToken(in: original)
            var title = CalendarImportTimeParser.removingTime(from: original)
            if let token, let range = title.range(of: token) { title.removeSubrange(range) }
            title = title.trimmingCharacters(
                in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—〜～~:：・"))
            )
            let confidence = sorted.map(\.confidence).reduce(0, +) / Float(max(sorted.count, 1))
            return CalendarImportCandidate(
                id: UUID(), date: date, startTimeMinutes: time.startMinutes,
                endTimeMinutes: time.endMinutes, title: title, originalText: original,
                personToken: token, confidence: confidence, quality: .standard,
                isSelected: true,
                needsReview: confidence < 0.75 || time.endMinutes == nil || title.isEmpty || token != nil,
                targetCalendarID: calendarID, includesPersonTokenInTitle: token != nil
            )
        }
    }

    private func makeMonthCellCandidates(
        observations: [CalendarOCRObservation],
        date: Date,
        calendarID: UUID,
        holidayNames: Set<String>
    ) -> ([CalendarImportCandidate], [CalendarPhotoCellCandidateDiagnostics]) {
        let parsedLines = group(observations).compactMap { line -> ParsedLine? in
            let sorted = line.observations.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            let rawText = sorted.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizedText(rawText)
            guard !normalized.isEmpty else { return nil }
            return ParsedLine(
                observations: sorted,
                rawText: rawText,
                normalizedText: normalized,
                time: CalendarImportTimeParser.parse(normalized)
            )
        }

        var candidates: [CalendarImportCandidate] = []
        var diagnostics: [CalendarPhotoCellCandidateDiagnostics] = []
        var pendingTitleLines: [ParsedLine] = []

        func appendCandidate(from sourceLines: [ParsedLine]) {
            guard !sourceLines.isEmpty else { return }
            let originalText = sourceLines.map(\.rawText).joined(separator: " ")
            let normalized = sourceLines.map(\.normalizedText).joined(separator: " ")
            let time = sourceLines.compactMap(\.time).first
            let personToken = personToken(in: normalized)
            var title = CalendarImportTimeParser.removingTime(from: normalized)
            if let personToken, let range = title.range(of: personToken) {
                title.removeSubrange(range)
            }
            title = cleanedTitle(title)
            let candidateObservations = sourceLines.flatMap(\.observations)
            let confidence = candidateObservations.map(\.confidence).reduce(0, +)
                / Float(max(candidateObservations.count, 1))
            let quality = CalendarImportCandidateQualityEvaluator.quality(
                title: title,
                parsedTime: time
            )
            let holidayMatch = time == nil
                && CalendarImportHolidayMatcher.isExactMatch(
                    title: title,
                    holidayNames: holidayNames
                )
            let defaultSelected = quality != .lowInformation && !holidayMatch
            let incompleteTime: Bool
            if let time {
                if let endMinutes = time.endMinutes {
                    incompleteTime = endMinutes <= time.startMinutes
                } else {
                    incompleteTime = true
                }
            } else {
                incompleteTime = true
            }
            let needsReview = quality == .lowInformation
                || holidayMatch
                || time.map { $0.parseQuality != .exact } == true
                || confidence < 0.75
                || incompleteTime
                || title.isEmpty
                || personToken != nil
            candidates.append(CalendarImportCandidate(
                id: UUID(),
                date: date,
                startTimeMinutes: time?.startMinutes,
                endTimeMinutes: time?.endMinutes,
                title: title,
                originalText: originalText,
                personToken: personToken,
                confidence: confidence,
                quality: quality,
                isSelected: defaultSelected,
                needsReview: needsReview,
                targetCalendarID: calendarID,
                includesPersonTokenInTitle: personToken != nil
            ))
            diagnostics.append(CalendarPhotoCellCandidateDiagnostics(
                parsedStartMinutes: time?.startMinutes,
                parsedEndMinutes: time?.endMinutes,
                remainingTitle: title,
                ocrConfidence: confidence,
                quality: quality,
                timeParseQuality: time?.parseQuality,
                holidayMatch: holidayMatch,
                needsReview: needsReview,
                defaultSelected: defaultSelected,
                candidateCreated: true,
                rejectedReason: nil
            ))
        }

        for line in parsedLines {
            if line.time == nil {
                pendingTitleLines.append(line)
                continue
            }
            appendCandidate(from: pendingTitleLines + [line])
            pendingTitleLines.removeAll(keepingCapacity: true)
        }
        appendCandidate(from: pendingTitleLines)
        return (candidates, diagnostics)
    }

    private func group(_ observations: [CalendarOCRObservation]) -> [Line] {
        var lines: [Line] = []
        for observation in observations.sorted(by: observationOrder) {
            if let index = lines.indices.min(by: {
                abs(centerY(lines[$0]) - observation.boundingBox.midY)
                    < abs(centerY(lines[$1]) - observation.boundingBox.midY)
            }), abs(centerY(lines[index]) - observation.boundingBox.midY)
                <= max(averageHeight(lines[index]), observation.boundingBox.height) * 0.7 {
                lines[index].observations.append(observation)
            } else {
                lines.append(Line(observations: [observation]))
            }
        }
        return lines
    }

    private func centerY(_ line: Line) -> Double {
        line.observations.map(\.boundingBox.midY).reduce(0, +) / Double(line.observations.count)
    }

    private func averageHeight(_ line: Line) -> Double {
        line.observations.map(\.boundingBox.height).reduce(0, +) / Double(line.observations.count)
    }

    private func isPrintedDay(
        _ observation: CalendarOCRObservation,
        in region: CalendarImportDayRegion
    ) -> Bool {
        normalizedText(observation.text) == String(region.day)
            && observation.boundingBox.midY
                >= region.boundingBox.minY + region.boundingBox.height * 0.65
    }

    private func normalizedText(_ text: String) -> String {
        text.folding(
            options: .widthInsensitive,
            locale: Locale(identifier: "en_US_POSIX")
        )
        .replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanedTitle(_ text: String) -> String {
        text.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(
                CharacterSet(charactersIn: "-–—〜～~:：・")
            )
        )
    }

    private func observationOrder(
        _ lhs: CalendarOCRObservation,
        _ rhs: CalendarOCRObservation
    ) -> Bool {
        abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.005
            ? lhs.boundingBox.midY > rhs.boundingBox.midY
            : lhs.boundingBox.minX < rhs.boundingBox.minX
    }

    private func isStandaloneDate(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.range(of: #"^(?:\d{1,2}|\d{1,2}[./-]\d{1,2})$"#, options: .regularExpression) != nil
    }

    private func personToken(in text: String) -> String? {
        let pattern = #"^[\s]*([○〇◯◎●]\s*[\p{L}\p{N}]{1,3})"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text)
              ), match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range]).replacingOccurrences(of: " ", with: "")
    }
}

struct CalendarPhotoParser {
    private struct DateAnchor {
        let day: Int
        let observation: CalendarOCRObservation
    }

    private struct GridFit {
        let score: Int
        let firstColumn: Int
        let xCenters: [Double]
        let yCenters: [Double]
        let anchorsByDay: [Int: DateAnchor]
    }

    private struct GridEvaluation {
        let fit: GridFit?
        let bestAttempt: GridFit?
        let sundayAttempt: GridFit?
        let mondayAttempt: GridFit?
        let sundayStartScore: Int
        let mondayStartScore: Int
        let selectedWeekStart: CalendarPhotoImportWeekStart?
        let dayCount: Int
    }

    private struct LineGroup {
        var observations: [CalendarOCRObservation]

        var centerY: Double {
            observations.map(\.boundingBox.midY).reduce(0, +)
                / Double(max(observations.count, 1))
        }

        var averageHeight: Double {
            observations.map(\.boundingBox.height).reduce(0, +)
                / Double(max(observations.count, 1))
        }
    }

    private static let monthNames: [String: Int] = [
        "january": 1, "jan": 1,
        "february": 2, "feb": 2,
        "march": 3, "mar": 3,
        "april": 4, "apr": 4,
        "may": 5,
        "june": 6, "jun": 6,
        "july": 7, "jul": 7,
        "august": 8, "aug": 8,
        "september": 9, "sept": 9, "sep": 9,
        "october": 10, "oct": 10,
        "november": 11, "nov": 11,
        "december": 12, "dec": 12
    ]

    private static let minimumGridMatchedAnchorCount = 7

    func parse(
        observations: [CalendarOCRObservation],
        overridingYearMonth: CalendarImportYearMonth? = nil,
        defaultCalendarID: UUID,
        calendar inputCalendar: Calendar = Calendar(identifier: .gregorian),
        orientationDiagnostics: CalendarPhotoOrientationDiagnostics? = nil,
        diagnosticsHandler: ((CalendarPhotoImportDiagnostics) -> Void)? = nil
    ) throws -> CalendarPhotoImportParseResult {
        let meaningful = observations.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let pureNumericObservationCount = meaningful.filter(Self.isPureNumeric).count

        func report(
            yearMonth: CalendarImportYearMonth?,
            anchors: [DateAnchor] = [],
            gridEvaluation: GridEvaluation? = nil,
            dayRegionCount: Int = 0,
            candidateCount: Int = 0,
            stage: CalendarPhotoImportParseStage,
            failureReason: CalendarPhotoImportParseError? = nil
        ) {
            let selectedGrid = gridEvaluation?.fit ?? gridEvaluation?.bestAttempt
            let matchedAnchorCount = selectedGrid?.score ?? 0
            let anchorDiagnostics = Self.anchorDiagnostics(anchors)
            let gridAttempts = Self.gridAttemptDiagnostics(
                evaluation: gridEvaluation,
                anchors: anchors
            )
            let selectedGridAttempt = Self.selectedGridAttemptDiagnostics(
                evaluation: gridEvaluation,
                anchors: anchors
            )
            diagnosticsHandler?(CalendarPhotoImportDiagnostics(
                orientation: orientationDiagnostics,
                manualYearMonth: overridingYearMonth,
                resolvedYearMonth: yearMonth,
                observationCount: observations.count,
                meaningfulObservationCount: meaningful.count,
                pureNumericObservationCount: pureNumericObservationCount,
                dateAnchorCount: anchors.count,
                distinctDayCount: Set(anchors.map(\.day)).count,
                sundayStartScore: gridEvaluation?.sundayStartScore ?? 0,
                mondayStartScore: gridEvaluation?.mondayStartScore ?? 0,
                selectedWeekStart: gridEvaluation?.selectedWeekStart,
                gridColumnCount: selectedGrid?.xCenters.count ?? 0,
                gridRowCount: selectedGrid?.yCenters.count ?? 0,
                gridMatchedAnchorCount: matchedAnchorCount,
                gridRejectedAnchorCount: max(0, anchors.count - matchedAnchorCount),
                gridAcceptanceThreshold: Self.minimumGridMatchedAnchorCount,
                gridAccepted: gridEvaluation?.fit != nil,
                anchorMedianWidth: anchorDiagnostics.medianWidth,
                anchorMedianHeight: anchorDiagnostics.medianHeight,
                duplicateDays: anchorDiagnostics.duplicateDays,
                anchorSpatialDistribution: anchorDiagnostics.spatialDistribution,
                anchors: anchorDiagnostics.anchors,
                selectedGridAttempt: selectedGridAttempt,
                gridAttempts: gridAttempts,
                dayRegionCount: dayRegionCount,
                candidateCount: candidateCount,
                parseStage: stage,
                failureReason: failureReason
            ))
        }

        guard !meaningful.isEmpty else {
            report(
                yearMonth: overridingYearMonth,
                stage: .text,
                failureReason: .noText
            )
            throw CalendarPhotoImportParseError.noText
        }

        // A user-selected value is authoritative. Resolve it before any date-grid
        // failure so later stages cannot be mistaken for another OCR month failure.
        let yearMonth = overridingYearMonth ?? Self.inferYearMonth(from: meaningful)

        let numericAnchors = meaningful.compactMap(Self.dateAnchor)
        guard Set(numericAnchors.map(\.day)).count >= 7 else {
            report(
                yearMonth: yearMonth,
                anchors: numericAnchors,
                stage: .dateAnchors,
                failureReason: .noDateStructure
            )
            throw CalendarPhotoImportParseError.noDateStructure
        }

        guard let yearMonth else {
            report(
                yearMonth: nil,
                anchors: numericAnchors,
                stage: .yearMonth,
                failureReason: .missingYearMonth
            )
            return CalendarPhotoImportParseResult(
                yearMonth: nil,
                candidates: [],
                dayRegions: []
            )
        }

        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        guard let monthStart = yearMonth.date(calendar: calendar),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            report(
                yearMonth: yearMonth,
                anchors: numericAnchors,
                stage: .grid,
                failureReason: .noDateStructure
            )
            throw CalendarPhotoImportParseError.noDateStructure
        }

        let gridEvaluation = evaluateGrid(
            anchors: numericAnchors,
            monthStart: monthStart,
            dayCount: dayRange.count,
            calendar: calendar
        )
        guard let fit = gridEvaluation.fit else {
            report(
                yearMonth: yearMonth,
                anchors: numericAnchors,
                gridEvaluation: gridEvaluation,
                stage: .grid,
                failureReason: .noDateStructure
            )
            throw CalendarPhotoImportParseError.noDateStructure
        }

        let regions = makeDayRegions(
            fit: fit,
            dayCount: dayRange.count
        )
        guard regions.count == dayRange.count else {
            report(
                yearMonth: yearMonth,
                anchors: numericAnchors,
                gridEvaluation: gridEvaluation,
                dayRegionCount: regions.count,
                stage: .dayRegions,
                failureReason: .noDateStructure
            )
            throw CalendarPhotoImportParseError.noDateStructure
        }
        let anchorObservations = Set(
            fit.anchorsByDay.values.map { Self.observationIdentity($0.observation) }
        )
        let candidates = makeCandidates(
            observations: meaningful,
            excluding: anchorObservations,
            regions: regions,
            monthStart: monthStart,
            calendarID: defaultCalendarID,
            calendar: calendar
        )
        guard !candidates.isEmpty else {
            report(
                yearMonth: yearMonth,
                anchors: numericAnchors,
                gridEvaluation: gridEvaluation,
                dayRegionCount: regions.count,
                stage: .candidates,
                failureReason: .noCandidates
            )
            throw CalendarPhotoImportParseError.noCandidates
        }
        report(
            yearMonth: yearMonth,
            anchors: numericAnchors,
            gridEvaluation: gridEvaluation,
            dayRegionCount: regions.count,
            candidateCount: candidates.count,
            stage: .completed
        )
        return CalendarPhotoImportParseResult(
            yearMonth: yearMonth,
            candidates: candidates,
            dayRegions: regions
        )
    }

    static func day(
        for observation: CalendarOCRObservation,
        in regions: [CalendarImportDayRegion]
    ) -> Int? {
        regions.first(where: { $0.contains(observation) })?.day
    }

    static func inferYearMonth(
        from observations: [CalendarOCRObservation]
    ) -> CalendarImportYearMonth? {
        let reliableObservations = observations.filter { $0.confidence >= 0.4 }
        let reliableText = reliableObservations
            .map(\.text)
            .joined(separator: " ")
        let normalized = reliableText.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        ).lowercased()

        var matches = Set<String>()
        let numericPattern = #"(?<!\d)((?:19|20)\d{2})\s*(?:年|년|[./-])\s*(1[0-2]|0?[1-9])\s*(?:月|월)?(?!\d)"#
        if let expression = try? NSRegularExpression(pattern: numericPattern) {
            let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            for match in expression.matches(in: normalized, range: range) {
                guard let year = integer(at: 1, match: match, text: normalized),
                      let month = integer(at: 2, match: match, text: normalized),
                      let value = CalendarImportYearMonth(year: year, month: month) else {
                    continue
                }
                matches.insert("\(value.year)-\(value.month)")
            }
        }

        let years = integerMatches(pattern: #"(?<!\d)((?:19|20)\d{2})(?!\d)"#, text: normalized)
        let englishMonths = Set(monthNames.compactMap { name, month in
            normalized.range(
                of: #"\b\#(NSRegularExpression.escapedPattern(for: name))\b"#,
                options: .regularExpression
            ) == nil ? nil : month
        })
        if years.count == 1, englishMonths.count == 1,
           let year = years.first, let month = englishMonths.first,
           let value = CalendarImportYearMonth(year: year, month: month) {
            matches.insert("\(value.year)-\(value.month)")
        }

        // Some paper calendars print the month as a much larger standalone number.
        // Only accept it when its size clearly separates it from the date grid.
        let dateNumberHeights = reliableObservations.compactMap { observation -> Double? in
            dateAnchor(observation) == nil ? nil : observation.boundingBox.height
        }.sorted()
        if years.count == 1, dateNumberHeights.count >= 7,
           let year = years.first {
            let medianDateHeight = dateNumberHeights[dateNumberHeights.count / 2]
            let largeStandaloneMonths = Set(reliableObservations.compactMap { observation -> Int? in
                guard let anchor = dateAnchor(observation),
                      anchor.day <= 12,
                      observation.boundingBox.height >= medianDateHeight * 1.8 else {
                    return nil
                }
                return anchor.day
            })
            if largeStandaloneMonths.count == 1,
               let month = largeStandaloneMonths.first,
               let value = CalendarImportYearMonth(year: year, month: month) {
                matches.insert("\(value.year)-\(value.month)")
            }
        }

        guard matches.count == 1,
              let value = matches.first else { return nil }
        let components = value.split(separator: "-").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        return CalendarImportYearMonth(year: components[0], month: components[1])
    }

    func orientationEvidence(
        observations: [CalendarOCRObservation],
        overridingYearMonth: CalendarImportYearMonth? = nil,
        calendar inputCalendar: Calendar = Calendar(identifier: .gregorian)
    ) -> CalendarPhotoOrientationEvidence {
        let meaningful = observations.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let reliableTextCount = meaningful.filter { $0.confidence >= 0.4 }.count
        let numericAnchors = meaningful.compactMap(Self.dateAnchor)
        let dateAnchorCount = Set(numericAnchors.map(\.day)).count
        let yearMonth = overridingYearMonth ?? Self.inferYearMonth(from: meaningful)

        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let fit: GridFit?
        if let yearMonth,
           let monthStart = yearMonth.date(calendar: calendar),
           let dayRange = calendar.range(of: .day, in: .month, for: monthStart) {
            fit = fitGrid(
                anchors: numericAnchors,
                monthStart: monthStart,
                dayCount: dayRange.count,
                calendar: calendar
            )
        } else {
            fit = fitGridWithoutYearMonth(anchors: numericAnchors)
        }

        return CalendarPhotoOrientationEvidence(
            yearMonth: yearMonth,
            dateAnchorObservationCount: numericAnchors.count,
            dateAnchorCount: dateAnchorCount,
            matchedDateAnchorCount: fit?.score ?? 0,
            columnCount: fit?.xCenters.count ?? 0,
            rowCount: fit?.yCenters.count ?? 0,
            reliableTextCount: reliableTextCount
        )
    }

    private static func dateAnchor(
        _ observation: CalendarOCRObservation
    ) -> DateAnchor? {
        let normalized = observation.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .widthInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        guard normalized.range(of: #"^\d{1,2}$"#, options: .regularExpression) != nil,
              let day = Int(normalized),
              (1...31).contains(day) else {
            return nil
        }
        return DateAnchor(day: day, observation: observation)
    }

    private static func isPureNumeric(
        _ observation: CalendarOCRObservation
    ) -> Bool {
        let normalized = observation.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .widthInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        return normalized.range(of: #"^\d+$"#, options: .regularExpression) != nil
    }

    private func fitGrid(
        anchors: [DateAnchor],
        monthStart: Date,
        dayCount: Int,
        calendar: Calendar
    ) -> GridFit? {
        evaluateGrid(
            anchors: anchors,
            monthStart: monthStart,
            dayCount: dayCount,
            calendar: calendar
        ).fit
    }

    private func evaluateGrid(
        anchors: [DateAnchor],
        monthStart: Date,
        dayCount: Int,
        calendar: Calendar
    ) -> GridEvaluation {
        let sundayFirstColumn = Self.column(
            for: monthStart,
            weekStartsOnMonday: false,
            calendar: calendar
        )
        let mondayFirstColumn = Self.column(
            for: monthStart,
            weekStartsOnMonday: true,
            calendar: calendar
        )
        let fit = fitGrid(
            anchors: anchors,
            dayCount: dayCount,
            firstColumns: [sundayFirstColumn, mondayFirstColumn]
        )
        let sundayAttempt = fitGrid(
            anchors: anchors,
            dayCount: dayCount,
            firstColumns: [sundayFirstColumn],
            requiresReliableStructure: false
        )
        let mondayAttempt = fitGrid(
            anchors: anchors,
            dayCount: dayCount,
            firstColumns: [mondayFirstColumn],
            requiresReliableStructure: false
        )
        let bestAttempt = [
            (CalendarPhotoImportWeekStart.sunday, sundayAttempt),
            (CalendarPhotoImportWeekStart.monday, mondayAttempt)
        ].compactMap { weekStart, fit -> (CalendarPhotoImportWeekStart, GridFit)? in
            guard let fit else { return nil }
            return (weekStart, fit)
        }.max {
            Self.isWeakerFit($0.1, $1.1)
        }
        return GridEvaluation(
            fit: fit,
            bestAttempt: bestAttempt?.1,
            sundayAttempt: sundayAttempt,
            mondayAttempt: mondayAttempt,
            sundayStartScore: sundayAttempt?.score ?? 0,
            mondayStartScore: mondayAttempt?.score ?? 0,
            selectedWeekStart: fit.map {
                $0.firstColumn == sundayFirstColumn ? .sunday : .monday
            } ?? bestAttempt?.0,
            dayCount: dayCount
        )
    }

    private static func anchorDiagnostics(
        _ anchors: [DateAnchor]
    ) -> (
        medianWidth: Double?,
        medianHeight: Double?,
        duplicateDays: [CalendarPhotoDuplicateDayDiagnostics],
        spatialDistribution: CalendarPhotoAnchorSpatialDiagnostics,
        anchors: [CalendarPhotoAnchorDiagnostics]
    ) {
        let medianWidth = diagnosticMedian(
            anchors.map { $0.observation.boundingBox.width }
        )
        let medianHeight = diagnosticMedian(
            anchors.map { $0.observation.boundingBox.height }
        )
        let duplicateDays = Dictionary(grouping: anchors, by: \.day)
            .compactMap { day, values -> CalendarPhotoDuplicateDayDiagnostics? in
                guard values.count > 1 else { return nil }
                return CalendarPhotoDuplicateDayDiagnostics(
                    day: day,
                    occurrenceCount: values.count
                )
            }
            .sorted { $0.day < $1.day }
        let anchorValues = anchors.map { anchor -> CalendarPhotoAnchorDiagnostics in
            let box = anchor.observation.boundingBox
            return CalendarPhotoAnchorDiagnostics(
                day: anchor.day,
                midX: box.midX,
                midY: box.midY,
                width: box.width,
                height: box.height,
                confidence: anchor.observation.confidence,
                widthRatio: medianWidth.flatMap { $0 > 0 ? box.width / $0 : nil },
                heightRatio: medianHeight.flatMap { $0 > 0 ? box.height / $0 : nil }
            )
        }.sorted(by: anchorDiagnosticOrder)
        let extent: CalendarPhotoAnchorExtentDiagnostics? = anchors.isEmpty ? nil
            : CalendarPhotoAnchorExtentDiagnostics(
                minX: anchors.map { $0.observation.boundingBox.minX }.min() ?? 0,
                maxX: anchors.map { $0.observation.boundingBox.maxX }.max() ?? 0,
                minY: anchors.map { $0.observation.boundingBox.minY }.min() ?? 0,
                maxY: anchors.map { $0.observation.boundingBox.maxY }.max() ?? 0
            )
        let spatialDistribution = CalendarPhotoAnchorSpatialDiagnostics(
            topQuarterAnchorCount: anchors.filter {
                $0.observation.boundingBox.midY >= 0.75
            }.count,
            bottomThreeQuarterAnchorCount: anchors.filter {
                $0.observation.boundingBox.midY < 0.75
            }.count,
            leftHalfAnchorCount: anchors.filter {
                $0.observation.boundingBox.midX < 0.5
            }.count,
            rightHalfAnchorCount: anchors.filter {
                $0.observation.boundingBox.midX >= 0.5
            }.count,
            extent: extent
        )
        return (
            medianWidth,
            medianHeight,
            duplicateDays,
            spatialDistribution,
            anchorValues
        )
    }

    private static func gridAttemptDiagnostics(
        evaluation: GridEvaluation?,
        anchors: [DateAnchor]
    ) -> [CalendarPhotoGridAttemptDiagnostics] {
        guard let evaluation else { return [] }
        return [
            (CalendarPhotoImportWeekStart.sunday, evaluation.sundayAttempt),
            (CalendarPhotoImportWeekStart.monday, evaluation.mondayAttempt)
        ].compactMap { weekStart, fit in
            guard let fit else { return nil }
            return gridAttemptDiagnostics(
                fit: fit,
                weekStart: weekStart,
                anchors: anchors,
                dayCount: evaluation.dayCount
            )
        }
    }

    private static func selectedGridAttemptDiagnostics(
        evaluation: GridEvaluation?,
        anchors: [DateAnchor]
    ) -> CalendarPhotoGridAttemptDiagnostics? {
        guard let evaluation,
              let fit = evaluation.fit ?? evaluation.bestAttempt,
              let weekStart = evaluation.selectedWeekStart else {
            return nil
        }
        return gridAttemptDiagnostics(
            fit: fit,
            weekStart: weekStart,
            anchors: anchors,
            dayCount: evaluation.dayCount
        )
    }

    private static func gridAttemptDiagnostics(
        fit: GridFit,
        weekStart: CalendarPhotoImportWeekStart,
        anchors: [DateAnchor],
        dayCount: Int
    ) -> CalendarPhotoGridAttemptDiagnostics {
        let mappings = anchors.map { anchor -> CalendarPhotoAnchorMappingDiagnostics in
            let box = anchor.observation.boundingBox
            let expectedIndex = anchor.day <= dayCount
                ? fit.firstColumn + anchor.day - 1
                : nil
            let expectedColumn = expectedIndex.map { $0 % 7 }
            let expectedRow = expectedIndex.map { $0 / 7 }
            let actualColumn = closestIndex(to: box.midX, centers: fit.xCenters)
            let actualRow = closestIndex(to: box.midY, centers: fit.yCenters)
            return CalendarPhotoAnchorMappingDiagnostics(
                day: anchor.day,
                midX: box.midX,
                midY: box.midY,
                expectedColumn: expectedColumn,
                expectedRow: expectedRow,
                actualColumn: actualColumn,
                actualRow: actualRow,
                matched: expectedColumn == actualColumn && expectedRow == actualRow
            )
        }.sorted(by: mappingDiagnosticOrder)
        return CalendarPhotoGridAttemptDiagnostics(
            weekStart: weekStart,
            firstColumn: fit.firstColumn,
            matchedDateAnchorCount: fit.score,
            xCenters: fit.xCenters,
            yCenters: fit.yCenters,
            anchorMappings: mappings
        )
    }

    private static func anchorDiagnosticOrder(
        _ lhs: CalendarPhotoAnchorDiagnostics,
        _ rhs: CalendarPhotoAnchorDiagnostics
    ) -> Bool {
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        if lhs.midY != rhs.midY { return lhs.midY > rhs.midY }
        return lhs.midX < rhs.midX
    }

    private static func mappingDiagnosticOrder(
        _ lhs: CalendarPhotoAnchorMappingDiagnostics,
        _ rhs: CalendarPhotoAnchorMappingDiagnostics
    ) -> Bool {
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        if lhs.midY != rhs.midY { return lhs.midY > rhs.midY }
        return lhs.midX < rhs.midX
    }

    private static func diagnosticMedian(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private func fitGridWithoutYearMonth(
        anchors: [DateAnchor]
    ) -> GridFit? {
        var fits: [GridFit] = []
        for dayCount in 28...31 {
            if let fit = fitGrid(
                anchors: anchors,
                dayCount: dayCount,
                firstColumns: Array(0...6)
            ) {
                fits.append(fit)
            }
        }
        return fits.max(by: Self.isWeakerFit)
    }

    private func fitGrid(
        anchors: [DateAnchor],
        dayCount: Int,
        firstColumns: [Int],
        requiresReliableStructure: Bool = true
    ) -> GridFit? {
        guard let xCenters = Self.clusterCenters(
            anchors.map { $0.observation.boundingBox.midX },
            count: 7,
            descending: false
        ) else { return nil }

        var fits: [GridFit] = []
        for firstColumn in Set(firstColumns).sorted() {
            let expectedRowCount = Int(ceil(Double(firstColumn + dayCount) / 7.0))
            for rowCount in expectedRowCount...6 {
                guard let yCenters = Self.clusterCenters(
                    anchors.map { $0.observation.boundingBox.midY },
                    count: rowCount,
                    descending: true
                ) else { continue }

                var matched: [Int: DateAnchor] = [:]
                for anchor in anchors where anchor.day <= dayCount {
                    let expectedIndex = firstColumn + anchor.day - 1
                    let expectedColumn = expectedIndex % 7
                    let expectedRow = expectedIndex / 7
                    let actualColumn = Self.closestIndex(
                        to: anchor.observation.boundingBox.midX,
                        centers: xCenters
                    )
                    let actualRow = Self.closestIndex(
                        to: anchor.observation.boundingBox.midY,
                        centers: yCenters
                    )
                    guard actualColumn == expectedColumn, actualRow == expectedRow else {
                        continue
                    }
                    if let current = matched[anchor.day],
                       current.observation.confidence >= anchor.observation.confidence {
                        continue
                    }
                    matched[anchor.day] = anchor
                }

                let distinctRows = Set(matched.keys.map { (firstColumn + $0 - 1) / 7 })
                let distinctColumns = Set(matched.keys.map { (firstColumn + $0 - 1) % 7 })
                if requiresReliableStructure {
                    guard matched.count >= Self.minimumGridMatchedAnchorCount,
                          distinctRows.count >= 2,
                          distinctColumns.count >= 4 else {
                        continue
                    }
                }
                fits.append(GridFit(
                    score: matched.count,
                    firstColumn: firstColumn,
                    xCenters: xCenters,
                    yCenters: yCenters,
                    anchorsByDay: matched
                ))
            }
        }

        return fits.max(by: Self.isWeakerFit)
    }

    private func makeDayRegions(
        fit: GridFit,
        dayCount: Int
    ) -> [CalendarImportDayRegion] {
        let firstColumn = fit.firstColumn
        let xSpacing = Self.medianSpacing(fit.xCenters) ?? (1.0 / 7.0)
        let ySpacing = Self.medianSpacing(fit.yCenters) ?? 0.14

        return (1...dayCount).compactMap { day in
            let index = firstColumn + day - 1
            let column = index % 7
            let row = index / 7
            guard row < fit.yCenters.count else { return nil }
            let xCenter = fit.xCenters[column]
            let yCenter = fit.yCenters[row]
            let minX = column == 0
                ? max(0, xCenter - xSpacing * 0.5)
                : (fit.xCenters[column - 1] + xCenter) / 2
            let maxX = column == 6
                ? min(1, xCenter + xSpacing * 0.5)
                : (xCenter + fit.xCenters[column + 1]) / 2
            let maxY = min(1, yCenter + ySpacing * 0.25)
            let minY: Double
            if row + 1 < fit.yCenters.count {
                minY = max(0, fit.yCenters[row + 1] + ySpacing * 0.25)
            } else {
                minY = max(0, yCenter - ySpacing * 0.75)
            }
            return CalendarImportDayRegion(
                day: day,
                boundingBox: CalendarOCRBoundingBox(
                    x: minX,
                    y: minY,
                    width: maxX - minX,
                    height: maxY - minY
                )
            )
        }
    }

    private func makeCandidates(
        observations: [CalendarOCRObservation],
        excluding anchorIdentities: Set<String>,
        regions: [CalendarImportDayRegion],
        monthStart: Date,
        calendarID: UUID,
        calendar: Calendar
    ) -> [CalendarImportCandidate] {
        var observationsByDay: [Int: [CalendarOCRObservation]] = [:]
        for observation in observations {
            guard !anchorIdentities.contains(Self.observationIdentity(observation)),
                  Self.dateAnchor(observation) == nil,
                  let day = Self.day(for: observation, in: regions) else {
                continue
            }
            observationsByDay[day, default: []].append(observation)
        }

        var result: [CalendarImportCandidate] = []
        for day in observationsByDay.keys.sorted() {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart),
                  let dayObservations = observationsByDay[day] else {
                continue
            }
            for group in Self.groupIntoLines(dayObservations) {
                let sorted = group.observations.sorted {
                    $0.boundingBox.minX < $1.boundingBox.minX
                }
                let originalText = sorted.map(\.text)
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !originalText.isEmpty else { continue }

                let time = CalendarImportTimeParser.parse(originalText)
                let personToken = Self.personToken(in: originalText)
                var title = CalendarImportTimeParser.removingTime(from: originalText)
                if let personToken, let range = title.range(of: personToken) {
                    title.removeSubrange(range)
                }
                title = Self.cleanedTitle(title)
                let confidence = sorted.map(\.confidence).reduce(0, +)
                    / Float(max(sorted.count, 1))
                let quality = CalendarImportCandidateQualityEvaluator.quality(
                    title: title,
                    parsedTime: time
                )
                let needsReview = quality == .lowInformation
                    || confidence < 0.75
                    || (time != nil && time?.endMinutes == nil)
                    || time.map { $0.parseQuality != .exact } == true
                    || title.isEmpty
                    || personToken != nil
                result.append(CalendarImportCandidate(
                    id: UUID(),
                    date: date,
                    startTimeMinutes: time?.startMinutes,
                    endTimeMinutes: time?.endMinutes,
                    title: title,
                    originalText: originalText,
                    personToken: personToken,
                    confidence: confidence,
                    quality: quality,
                    isSelected: quality != .lowInformation,
                    needsReview: needsReview,
                    targetCalendarID: calendarID,
                    includesPersonTokenInTitle: personToken != nil
                ))
            }
        }
        return result
    }

    private static func groupIntoLines(
        _ observations: [CalendarOCRObservation]
    ) -> [LineGroup] {
        let sorted = observations.sorted {
            if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.005 {
                return $0.boundingBox.midY > $1.boundingBox.midY
            }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }
        var groups: [LineGroup] = []
        for observation in sorted {
            if let index = groups.indices.min(by: {
                abs(groups[$0].centerY - observation.boundingBox.midY)
                    < abs(groups[$1].centerY - observation.boundingBox.midY)
            }) {
                let tolerance = max(
                    groups[index].averageHeight,
                    observation.boundingBox.height
                ) * 0.7
                if abs(groups[index].centerY - observation.boundingBox.midY) <= tolerance {
                    groups[index].observations.append(observation)
                    continue
                }
            }
            groups.append(LineGroup(observations: [observation]))
        }
        return groups.sorted { $0.centerY > $1.centerY }
    }

    private static func personToken(in text: String) -> String? {
        let pattern = #"^[\s]*([○〇◯◎●]\s*[\p{L}\p{N}]{1,3})"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range]).replacingOccurrences(of: " ", with: "")
    }

    private static func cleanedTitle(_ text: String) -> String {
        text.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(
                CharacterSet(charactersIn: "-–—〜～~:：・")
            )
        )
    }

    private static func clusterCenters(
        _ values: [Double],
        count: Int,
        descending: Bool
    ) -> [Double]? {
        guard values.count >= count, count > 0 else { return nil }
        let sorted = values.sorted()
        var centers = (0..<count).map { index -> Double in
            let position = Double(index) * Double(sorted.count - 1) / Double(max(count - 1, 1))
            return sorted[Int(position.rounded())]
        }
        for _ in 0..<30 {
            var buckets = Array(repeating: [Double](), count: count)
            for value in values {
                let index = closestIndex(to: value, centers: centers)
                buckets[index].append(value)
            }
            guard buckets.allSatisfy({ !$0.isEmpty }) else { return nil }
            let next = buckets.map { $0.reduce(0, +) / Double($0.count) }
            if zip(centers, next).allSatisfy({ abs($0 - $1) < 0.000_001 }) {
                centers = next
                break
            }
            centers = next
        }
        centers.sort()
        if descending { centers.reverse() }
        guard let spacing = medianSpacing(centers), spacing >= 0.02 else { return nil }
        return centers
    }

    private static func closestIndex(to value: Double, centers: [Double]) -> Int {
        centers.indices.min {
            abs(centers[$0] - value) < abs(centers[$1] - value)
        } ?? 0
    }

    private static func medianSpacing(_ centers: [Double]) -> Double? {
        guard centers.count > 1 else { return nil }
        let differences = zip(centers, centers.dropFirst())
            .map { abs($1 - $0) }
            .sorted()
        return differences[differences.count / 2]
    }

    private static func isWeakerFit(_ lhs: GridFit, _ rhs: GridFit) -> Bool {
        if lhs.score != rhs.score { return lhs.score < rhs.score }
        return lhs.yCenters.count > rhs.yCenters.count
    }

    private static func column(
        for date: Date,
        weekStartsOnMonday: Bool,
        calendar: Calendar
    ) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekStartsOnMonday ? (weekday + 5) % 7 : weekday - 1
    }

    private static func observationIdentity(_ observation: CalendarOCRObservation) -> String {
        [
            observation.text,
            String(format: "%.5f", observation.boundingBox.x),
            String(format: "%.5f", observation.boundingBox.y),
            String(format: "%.5f", observation.boundingBox.width),
            String(format: "%.5f", observation.boundingBox.height)
        ].joined(separator: "|")
    }

    private static func integerMatches(pattern: String, text: String) -> Set<Int> {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return Set(expression.matches(in: text, range: range).compactMap {
            integer(at: 1, match: $0, text: text)
        })
    }

    private static func integer(
        at index: Int,
        match: NSTextCheckingResult,
        text: String
    ) -> Int? {
        guard index < match.numberOfRanges,
              match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: text) else {
            return nil
        }
        return Int(text[range])
    }
}
