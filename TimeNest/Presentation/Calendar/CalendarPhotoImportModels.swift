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

struct CalendarPhotoCellUpscaleDetectionDiagnostics: Equatable, Sendable {
    let boundingBox: CalendarOCRBoundingBox
    let currentText: String
    let selectedText: String
    let selectedSource: String
}

struct CalendarPhotoCellUpscaleAttemptDiagnostics: Equatable, Sendable {
    let scaleFactor: Int
    let cellPixels: CalendarPhotoPixelSizeDiagnostics
    let detectorInputPixels: CalendarPhotoPixelSizeDiagnostics?
    let detectionCount: Int
    let detections: [CalendarPhotoCellUpscaleDetectionDiagnostics]
    let timeCandidates: [String]
    let selectedTexts: [String]
    let selectionReason: String
    let totalMilliseconds: Double
    let error: String?
}

struct CalendarPhotoRecognitionModelComparisonDiagnostics: Equatable, Sendable {
    let boundingBox: CalendarOCRBoundingBox
    let currentText: String
    let currentConfidence: Float
    let currentMilliseconds: Double
    let recoveryAttempted: Bool
    let recoveryReason: String?
    let enhancedText: String?
    let enhancedConfidence: Float?
    let enhancedMilliseconds: Double?
    let enhancedError: String?
    let candidateText: String?
    let candidateConfidence: Float?
    let candidateMilliseconds: Double?
    let candidateError: String?
    let visionText: String?
    let visionConfidence: Float?
    let visionMilliseconds: Double?
    let visionError: String?
    let timeFocusedRecoveryAttempted: Bool
    let timeFocusedCrop: CalendarOCRBoundingBox?
    let timeFocusedPPocrText: String?
    let timeFocusedPPocrConfidence: Float?
    let timeFocusedPPocrMilliseconds: Double?
    let timeFocusedPPocrError: String?
    let timeFocusedVisionText: String?
    let timeFocusedVisionConfidence: Float?
    let timeFocusedVisionMilliseconds: Double?
    let timeFocusedVisionError: String?
    let timeFocusedSelectionReason: String
    let selectedText: String
    let selectedSource: String
    let selectionReason: String
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
    let oneXTotalMilliseconds: Double
    let ppOCRText: [String]
    let ppOCRError: String?
    let cellUpscaleRecoveryAttempted: Bool
    let cellUpscaleAttempts: [CalendarPhotoCellUpscaleAttemptDiagnostics]
    let cellUpscaleSelectedScale: String

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
    var timeParseQualityOverride: CalendarImportTimeParseQuality? = nil
}

struct CalendarOCRCandidate: Equatable, Sendable {
    let text: String
    let confidence: Float
    var source: CalendarOCRCandidateSource = .observation
    var isPrimary: Bool = false
}

enum CalendarOCRCandidateSource: String, Equatable, Sendable {
    case observation
    case currentPPocr
    case enhancedPPocr
    case candidatePPocr
    case vision
    case visionSecondary
    case timeFocusedPPocr
    case timeFocusedVision
    case cellUpscale

    var engineFamily: String {
        switch self {
        case .currentPPocr, .enhancedPPocr, .candidatePPocr,
             .timeFocusedPPocr, .cellUpscale:
            return "ppocr"
        case .vision, .visionSecondary, .timeFocusedVision:
            return "vision"
        case .observation:
            return "observation"
        }
    }
}

struct CalendarOCRTimeCandidateEvaluation: Equatable, Sendable {
    let candidate: CalendarOCRCandidate
    let time: CalendarImportParsedTime
    let score: Double
    let consensusCount: Int
    let hasCrossEngineConsensus: Bool
    let pageTemplate: CalendarMonthTimeTemplate?
    let pageTemplateDistance: Int?
}

struct CalendarOCRTimeSelection: Equatable, Sendable {
    let selected: CalendarOCRTimeCandidateEvaluation
    let evaluations: [CalendarOCRTimeCandidateEvaluation]
    let selectionReason: String
    let requiresReview: Bool
}

struct CalendarOCRCandidateSelector {
    static func select(from candidates: [CalendarOCRCandidate]) -> CalendarOCRCandidate? {
        guard let first = candidates.first else { return nil }
        guard candidates.contains(where: { CalendarImportTimeParser.parseRangeOnly($0.text) != nil }) else {
            return first
        }
        return candidates.enumerated().max { lhs, rhs in
            score(lhs.element, index: lhs.offset, candidates: candidates)
                < score(rhs.element, index: rhs.offset, candidates: candidates)
        }?.element
    }

    static func selectMonthTime(
        from candidates: [CalendarOCRCandidate],
        pageTemplates: [CalendarMonthTimeTemplate]
    ) -> CalendarOCRTimeSelection? {
        let uniqueCandidates = candidates.reduce(into: [CalendarOCRCandidate]()) {
            result, candidate in
            let normalized = normalizedCandidateText(candidate.text)
            guard !result.contains(where: {
                normalizedCandidateText($0.text) == normalized
                    && $0.source == candidate.source
                    && abs($0.confidence - candidate.confidence) < 0.000_1
            }) else { return }
            result.append(candidate)
        }
        let parsed = uniqueCandidates.compactMap {
            candidate -> (CalendarOCRCandidate, CalendarImportParsedTime)? in
            guard let time = CalendarImportTimeParser.parseMonthRangeOnly(candidate.text),
                  let end = time.endMinutes,
                  end > time.startMinutes else { return nil }
            return (candidate, time)
        }
        guard !parsed.isEmpty else { return nil }

        let evaluations = parsed.map { candidate, time in
            let agreeing = parsed.filter {
                sameTime($0.1, time)
            }
            let engineFamilies = Set(agreeing.map { $0.0.source.engineFamily })
                .subtracting(Set(["observation"]))
            let templateEvidence = nearestTemplate(to: time, templates: pageTemplates)
            let templateBonus: Double
            if let templateEvidence {
                if templateEvidence.distance == 0 {
                    templateBonus = 0.20
                        + min(Double(templateEvidence.template.occurrenceCount), 5) * 0.08
                        + Double(templateEvidence.template.bestConfidence) * 0.10
                } else if templateEvidence.distance == 1 {
                    templateBonus = 0.08
                } else if templateEvidence.distance == 2 {
                    templateBonus = 0.03
                } else {
                    templateBonus = 0
                }
            } else {
                templateBonus = 0
            }
            let parseQualityBonus: Double
            switch time.parseQuality {
            case .exact: parseQualityBonus = 0.50
            case .normalized: parseQualityBonus = 0.32
            case .recovered: parseQualityBonus = 0.08
            }
            let sourceBonus: Double
            switch candidate.source {
            case .currentPPocr: sourceBonus = 0.12
            case .enhancedPPocr, .vision, .visionSecondary: sourceBonus = 0.05
            case .candidatePPocr, .timeFocusedPPocr, .timeFocusedVision,
                 .cellUpscale, .observation:
                sourceBonus = 0
            }
            let consensusBonus = min(Double(max(0, agreeing.count - 1)), 3) * 0.45
            let crossEngineBonus = engineFamilies.contains("ppocr")
                && engineFamilies.contains("vision") ? 0.30 : 0
            let score = Double(candidate.confidence)
                + parseQualityBonus
                + (candidate.isPrimary ? 0.35 : 0)
                + sourceBonus
                + consensusBonus
                + crossEngineBonus
                + templateBonus
            return CalendarOCRTimeCandidateEvaluation(
                candidate: candidate,
                time: time,
                score: score,
                consensusCount: agreeing.count,
                hasCrossEngineConsensus: crossEngineBonus > 0,
                pageTemplate: templateEvidence?.template,
                pageTemplateDistance: templateEvidence?.distance
            )
        }
        let ordered = evaluations.sorted(by: evaluationOrder)
        guard let selected = ordered.first else { return nil }
        let primary = evaluations.first(where: { $0.candidate.isPrimary })
        let distinctTimes = Set(evaluations.map {
            "\($0.time.startMinutes)-\($0.time.endMinutes ?? -1)"
        })
        let nearbyTemplateConflict = selected.pageTemplateDistance.map {
            (1...2).contains($0)
        } ?? false
        let narrowMargin = ordered.dropFirst().first.map {
            selected.score - $0.score < 0.25 && !sameTime(selected.time, $0.time)
        } ?? false
        let selectedDifferentFromPrimary = primary.map {
            !sameTime($0.time, selected.time)
        } ?? false
        let requiresReview = nearbyTemplateConflict
            || narrowMargin
            || distinctTimes.count > 1
            || (selectedDifferentFromPrimary && selected.consensusCount < 2)

        let selectionReason: String
        if selected.hasCrossEngineConsensus {
            selectionReason = "crossEngineConsensus"
        } else if selected.consensusCount > 1 {
            selectionReason = "ocrConsensus"
        } else if selected.pageTemplateDistance == 0, selectedDifferentFromPrimary {
            selectionReason = "ocrAlternativeWithPageTemplate"
        } else if primary.map({ sameTime($0.time, selected.time) }) == true,
                  nearbyTemplateConflict {
            selectionReason = "strongPrimaryPreservedWithTemplateConflict"
        } else if selected.candidate.isPrimary {
            selectionReason = "primaryOCREvidence"
        } else {
            selectionReason = "bestOCREvidence"
        }
        return CalendarOCRTimeSelection(
            selected: selected,
            evaluations: evaluations.sorted(by: evaluationOrder),
            selectionReason: selectionReason,
            requiresReview: requiresReview
        )
    }

    private static func score(
        _ candidate: CalendarOCRCandidate,
        index: Int,
        candidates: [CalendarOCRCandidate]
    ) -> Double {
        guard let range = CalendarImportTimeParser.parseRangeOnly(candidate.text),
              let end = range.endMinutes, end > range.startMinutes else {
            return Double(candidate.confidence)
        }
        let agreement = candidates.filter {
            guard let other = CalendarImportTimeParser.parseRangeOnly($0.text) else { return false }
            return other.startMinutes == range.startMinutes && other.endMinutes == range.endMinutes
        }.count
        let quality: Double
        switch range.parseQuality {
        case .exact: quality = 0.8
        case .normalized: quality = 0.55
        case .recovered: quality = 0.15
        }
        let primarySourceBonus = index == 0 ? 0.2 : 0
        let consensusBonus = agreement > 1 ? Double(agreement) * 0.75 : 0
        return 1 + Double(candidate.confidence) + quality + primarySourceBonus + consensusBonus
    }

    private static func evaluationOrder(
        _ lhs: CalendarOCRTimeCandidateEvaluation,
        _ rhs: CalendarOCRTimeCandidateEvaluation
    ) -> Bool {
        if abs(lhs.score - rhs.score) > 0.000_1 { return lhs.score > rhs.score }
        if lhs.candidate.isPrimary != rhs.candidate.isPrimary {
            return lhs.candidate.isPrimary
        }
        return lhs.candidate.confidence > rhs.candidate.confidence
    }

    private static func nearestTemplate(
        to time: CalendarImportParsedTime,
        templates: [CalendarMonthTimeTemplate]
    ) -> (template: CalendarMonthTimeTemplate, distance: Int)? {
        guard let end = time.endMinutes else { return nil }
        let text = CalendarMonthTimeTemplate(
            startMinutes: time.startMinutes,
            endMinutes: end
        ).displayText
        return templates.filter { $0.occurrenceCount >= 2 }.map { template in
            (template, CalendarMonthTimeRecovery.editDistance(
                CalendarMonthTimeRecovery.comparisonKey(text),
                CalendarMonthTimeRecovery.comparisonKey(template.displayText)
            ))
        }.min { lhs, rhs in
            lhs.1 == rhs.1
                ? lhs.0.occurrenceCount > rhs.0.occurrenceCount
                : lhs.1 < rhs.1
        }
    }

    private static func sameTime(
        _ lhs: CalendarImportParsedTime,
        _ rhs: CalendarImportParsedTime
    ) -> Bool {
        lhs.startMinutes == rhs.startMinutes && lhs.endMinutes == rhs.endMinutes
    }

    private static func normalizedCandidateText(_ text: String) -> String {
        text.folding(options: .widthInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CalendarMonthTimeTemplate: Hashable, Sendable {
    let startMinutes: Int
    let endMinutes: Int
    var occurrenceCount: Int = 1
    var bestConfidence: Float = 1

    var displayText: String {
        String(format: "%02d:%02d-%02d:%02d", startMinutes / 60, startMinutes % 60,
               endMinutes / 60, endMinutes % 60)
    }
}

struct CalendarMonthTimeRecovery {
    struct Result: Equatable, Sendable {
        let time: CalendarImportParsedTime
        let template: CalendarMonthTimeTemplate
        let distance: Int
    }

    static func isTimeLike(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber).count
        guard digits >= 4 else { return false }
        let nonWhitespace = text.filter { !$0.isWhitespace }
        let timeCharacters = nonWhitespace.filter {
            $0.isNumber || ":：.=-–—〜～~".contains($0)
        }.count
        return Double(timeCharacters) / Double(max(nonWhitespace.count, 1)) >= 0.72
    }

    static func templates(from observations: [CalendarOCRObservation]) -> [CalendarMonthTimeTemplate] {
        var evidence: [CalendarMonthTimeTemplate: (count: Int, bestConfidence: Float)] = [:]
        for observation in observations {
            guard let time = CalendarImportTimeParser.parseMonthRangeOnly(observation.text),
                  let end = time.endMinutes, end > time.startMinutes,
                  time.parseQuality != .recovered,
                  observation.timeParseQualityOverride != .recovered,
                  observation.selectionReason?.contains("pageTemplate") != true else { continue }
            let minimumConfidence: Float = time.parseQuality == .exact ? 0.72 : 0.80
            guard observation.confidence >= minimumConfidence else { continue }
            let template = CalendarMonthTimeTemplate(startMinutes: time.startMinutes, endMinutes: end)
            let old = evidence[template] ?? (0, 0)
            evidence[template] = (old.count + 1, max(old.bestConfidence, observation.confidence))
        }
        return evidence.compactMap { template, value in
            guard value.count >= 2 || value.bestConfidence >= 0.90 else { return nil }
            return CalendarMonthTimeTemplate(
                startMinutes: template.startMinutes,
                endMinutes: template.endMinutes,
                occurrenceCount: value.count,
                bestConfidence: value.bestConfidence
            )
        }.sorted { $0.displayText < $1.displayText }
    }

    static func recover(_ text: String, templates: [CalendarMonthTimeTemplate]) -> Result? {
        guard isTimeLike(text), CalendarImportTimeParser.parseMonthRangeOnly(text) == nil else { return nil }
        let source = comparisonKey(text)
        guard source.count >= 7 else { return nil }
        let matches = templates.compactMap { template -> Result? in
            let distance = editDistance(source, comparisonKey(template.displayText))
            guard distance <= 2 else { return nil }
            return Result(
                time: CalendarImportParsedTime(startMinutes: template.startMinutes,
                                               endMinutes: template.endMinutes,
                                               parseQuality: .recovered),
                template: template,
                distance: distance
            )
        }.sorted { $0.distance < $1.distance }
        guard let first = matches.first,
              matches.dropFirst().first?.distance != first.distance else { return nil }
        return first
    }

    static func comparisonKey(_ text: String) -> String {
        text.folding(options: .widthInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .filter(\.isNumber)
    }

    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs), right = Array(rhs)
        var previous = Array(0...right.count)
        for (i, a) in left.enumerated() {
            var current = [i + 1]
            for (j, b) in right.enumerated() {
                current.append(min(current[j] + 1, previous[j + 1] + 1,
                                   previous[j] + (a == b ? 0 : 1)))
            }
            previous = current
        }
        return previous[right.count]
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
    case noParsedTime
    case invalidDate
}

struct CalendarPhotoTimeCandidateDiagnostics: Equatable, Sendable {
    let rawText: String
    let normalizedText: String
    let source: CalendarOCRCandidateSource
    let isPrimary: Bool
    let confidence: Float
    let parseQuality: CalendarImportTimeParseQuality
    let parsedStartMinutes: Int
    let parsedEndMinutes: Int
    let pageTemplateMatch: String?
    let pageTemplateCount: Int?
    let pageTemplateDistance: Int?
    let ocrConsensusCount: Int
    let crossEngineConsensus: Bool
    let score: Double
}

struct CalendarPhotoCellCandidateDiagnostics: Equatable, Sendable {
    let originalTexts: [String]
    let mergedText: String?
    let selectedSource: String
    let selectionReason: String
    let templateMatched: Bool
    let templateDistance: Int?
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
    let allParsedTimeCandidates: [CalendarPhotoTimeCandidateDiagnostics]
    let selectedTimeText: String?
    let selectedTimeSource: String
    let selectionScore: Double?
    let rejectedAlternativeTimes: [String]
    let timeFragmentTexts: [String]
    let titleTexts: [String]
    let appointmentGroup: Int
}

struct CalendarPhotoCellDiagnostics: Equatable, Sendable {
    let day: Int
    let cellBounds: CalendarOCRBoundingBox
    let observationCount: Int
    let printedDayObservationCount: Int
    let rawTexts: [String]
    let normalizedTexts: [String]
    let candidates: [CalendarPhotoCellCandidateDiagnostics]
    let rejectedNoParsedTimeLineCount: Int
    let rejectedReason: CalendarPhotoCellRejectionReason?

    var contentObservationCount: Int { rawTexts.count }
    var timeLinesDetected: Int {
        candidates.filter { $0.parsedStartMinutes != nil }.count
    }
    var candidateCreated: Bool { candidates.contains(where: \.candidateCreated) }
}

struct CalendarPhotoImportDiagnostics: Equatable, Sendable {
    var scanMode: CalendarPhotoScanMode? = nil
    var selectedDate: Date? = nil
    var appLanguage: DisplayLanguage? = nil
    var ocrLanguage: String? = nil
    var timeRecognitionEngine: String? = nil
    var textRecognitionEngine: String? = nil
    var textRecognitionLanguage: String? = nil
    var gridDetection: String = "legacy"
    var recognitionMode: CalendarPhotoRecognitionMode? = nil
    var recognitionCellDiagnostics: [CalendarPhotoCellRecognitionDiagnostics] = []
    var recognitionModelPOC: CalendarPhotoRecognitionModelPOCDiagnostics? = nil
    var cellDiagnostics: [CalendarPhotoCellDiagnostics] = []
    var unassignedRawTexts: [String] = []
    var unassignedNormalizedTexts: [String] = []
    var pageTimeTemplates: [String] = []
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
            || ocrLanguage != nil
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

    var unresolvedTimeDetectionCount: Int {
        recognitionCellDiagnostics.reduce(0) { total, cell in
            let originalUnresolved = cell.recognitionModelComparisons.filter {
                    $0.timeFocusedRecoveryAttempted
                        && $0.selectedSource
                            == PPOCRTimeRecognitionSource.currentPPocr.rawValue
                        && $0.selectionReason == "noValidSecondaryResult"
                }.count
            let recovered = cell.cellUpscaleAttempts
                .first { "\($0.scaleFactor)x" == cell.cellUpscaleSelectedScale }?
                .selectedTexts.count ?? 0
            return total + max(0, originalUnresolved - recovered)
        }
    }

    var cellUpscaleRecoveryCellCount: Int {
        recognitionCellDiagnostics.filter(\.cellUpscaleRecoveryAttempted).count
    }

    var cellUpscale2xTotalMilliseconds: Double {
        cellUpscaleTotalMilliseconds(scaleFactor: 2)
    }

    var cellUpscale3xTotalMilliseconds: Double {
        cellUpscaleTotalMilliseconds(scaleFactor: 3)
    }

    var ppOCROneXCellTotalMilliseconds: Double {
        recognitionCellDiagnostics.map(\.oneXTotalMilliseconds).reduce(0, +)
    }

    var cellUpscaleAddedTotalMilliseconds: Double {
        cellUpscale2xTotalMilliseconds + cellUpscale3xTotalMilliseconds
    }

    var cellUpscaleAddedPercent: Double? {
        guard ppOCROneXCellTotalMilliseconds > 0 else { return nil }
        return cellUpscaleAddedTotalMilliseconds / ppOCROneXCellTotalMilliseconds * 100
    }

    var displayFields: [(label: String, value: String)] {
        [
            ("Scan Mode", scanMode?.rawValue ?? "legacy"),
            ("Selected Date", Self.dateText(selectedDate)),
            ("App Language", appLanguage?.rawValue ?? "unknown"),
            ("OCR Language", ocrLanguage ?? "unknown"),
            ("Time Engine", timeRecognitionEngine ?? "legacy"),
            ("Text Engine", textRecognitionEngine ?? "legacy"),
            ("Text Language", textRecognitionLanguage ?? "unknown"),
            ("Grid Detection", gridDetection),
            ("Recognition", recognitionMode?.rawValue ?? "legacy"),
            ("PP-OCR Success Cells", "\(ppOCRSuccessCellCount)"),
            ("Vision Fallback Cells", "\(visionFallbackCellCount)"),
            ("Unresolved Time Detections", "\(unresolvedTimeDetectionCount)"),
            ("PP-OCR 1x Cell Total", "\(Self.decimalText(ppOCROneXCellTotalMilliseconds)) ms"),
            ("Cell Upscale Retry Cells", "\(cellUpscaleRecoveryCellCount)"),
            ("Cell Upscale 2x Total", "\(Self.decimalText(cellUpscale2xTotalMilliseconds)) ms"),
            ("Cell Upscale 3x Total", "\(Self.decimalText(cellUpscale3xTotalMilliseconds)) ms"),
            ("Cell Upscale Added", "\(Self.decimalText(cellUpscaleAddedTotalMilliseconds)) ms"),
            (
                "Cell Upscale Added vs 1x",
                cellUpscaleAddedPercent.map { "\(Self.decimalText($0))%" } ?? "none"
            ),
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
            "appLanguage=\(appLanguage?.rawValue ?? "unknown")",
            "ocrLanguage=\(ocrLanguage ?? "unknown")",
            "timeRecognitionEngine=\(timeRecognitionEngine ?? "legacy")",
            "textRecognitionEngine=\(textRecognitionEngine ?? "legacy")",
            "textRecognitionLanguage=\(textRecognitionLanguage ?? "unknown")",
            "gridDetection=\(gridDetection)",
            "recognitionMode=\(recognitionMode?.rawValue ?? "legacy")",
            "ppocrSuccessCells=\(ppOCRSuccessCellCount)",
            "visionFallbackCells=\(visionFallbackCellCount)",
            "unresolvedTimeDetections=\(unresolvedTimeDetectionCount)",
            "ppocr1xCellTotalMs=\(Self.decimalText(ppOCROneXCellTotalMilliseconds))",
            "cellUpscaleRecoveryCells=\(cellUpscaleRecoveryCellCount)",
            "cellUpscale2xTotalMs=\(Self.decimalText(cellUpscale2xTotalMilliseconds))",
            "cellUpscale3xTotalMs=\(Self.decimalText(cellUpscale3xTotalMilliseconds))",
            "cellUpscaleAddedTotalMs=\(Self.decimalText(cellUpscaleAddedTotalMilliseconds))",
            "cellUpscaleAddedVs1xPercent=\(Self.decimalText(cellUpscaleAddedPercent))",
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
        let cellUpscaleLines = Self.cellUpscaleLines(recognitionCellDiagnostics)
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
                "primaryModel=currentModel",
                "candidateInput=semanticRecoverySelection"
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
                            "recoveryAttempted=\(comparison.recoveryAttempted)",
                            "recoveryReason=\(comparison.recoveryReason ?? "none")",
                            "originalText=\(Self.quotedText(comparison.currentText))",
                            "originalConfidence=\(Self.decimalText(Double(comparison.currentConfidence)))",
                            "originalParseResult=\(Self.timeParseResult(comparison.currentText))",
                            "enhancedText=\(comparison.enhancedText.map(Self.quotedText) ?? "none")",
                            "enhancedConfidence=\(Self.decimalText(comparison.enhancedConfidence.map(Double.init)))",
                            "enhancedParseResult=\(Self.timeParseResult(comparison.enhancedText))",
                            "enhancedError=\(comparison.enhancedError ?? "none")",
                            "candidateModelText=\(comparison.candidateText.map(Self.quotedText) ?? "none")",
                            "candidateModelConfidence=\(Self.decimalText(comparison.candidateConfidence.map(Double.init)))",
                            "candidateModelParseResult=\(Self.timeParseResult(comparison.candidateText))",
                            "visionText=\(comparison.visionText.map(Self.quotedText) ?? "none")",
                            "visionConfidence=\(Self.decimalText(comparison.visionConfidence.map(Double.init)))",
                            "visionParseResult=\(Self.timeParseResult(comparison.visionText))",
                            "visionError=\(comparison.visionError ?? "none")",
                            "timeFocusedRecoveryAttempted=\(comparison.timeFocusedRecoveryAttempted)",
                            "timeFocusedCropSpace=enhancedDetectionNormalized",
                            "timeFocusedCrop=\(Self.boundingBoxText(comparison.timeFocusedCrop))",
                            "timeFocusedPPocrText=\(comparison.timeFocusedPPocrText.map(Self.quotedText) ?? "none")",
                            "timeFocusedPPocrConfidence=\(Self.decimalText(comparison.timeFocusedPPocrConfidence.map(Double.init)))",
                            "timeFocusedPPocrParseResult=\(Self.timeParseResult(comparison.timeFocusedPPocrText))",
                            "timeFocusedPPocrError=\(comparison.timeFocusedPPocrError ?? "none")",
                            "timeFocusedVisionText=\(comparison.timeFocusedVisionText.map(Self.quotedText) ?? "none")",
                            "timeFocusedVisionConfidence=\(Self.decimalText(comparison.timeFocusedVisionConfidence.map(Double.init)))",
                            "timeFocusedVisionParseResult=\(Self.timeParseResult(comparison.timeFocusedVisionText))",
                            "timeFocusedVisionError=\(comparison.timeFocusedVisionError ?? "none")",
                            "timeFocusedSelectionReason=\(comparison.timeFocusedSelectionReason)",
                            "selectedText=\(Self.quotedText(comparison.selectedText))",
                            "selectedSource=\(comparison.selectedSource)",
                            "selectionReason=\(comparison.selectionReason)",
                            "currentRecognitionMs=\(Self.decimalText(comparison.currentMilliseconds))",
                            "enhancedRecognitionMs=\(Self.decimalText(comparison.enhancedMilliseconds))",
                            "candidateRecognitionMs=\(Self.decimalText(comparison.candidateMilliseconds))",
                            "candidateError=\(comparison.candidateError ?? "none")",
                            "visionRecognitionMs=\(Self.decimalText(comparison.visionMilliseconds))"
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
                "timeLinesDetected=\(cell.timeLinesDetected)",
                "candidates=\(cell.candidates.count)",
                "rejectedReason=\(cell.rejectedReason?.rawValue ?? "none")",
                "rejectedNoParsedTimeLines=\(cell.rejectedNoParsedTimeLineCount)"
            ].joined(separator: " ")
            let candidateLines = cell.candidates.enumerated().flatMap { index, candidate in
                let candidateNumber = index + 1
                let summary = [
                    "day=\(cell.day)",
                    "candidate=\(candidateNumber)",
                    "appointmentGroup=\(candidate.appointmentGroup)",
                    "originalTexts=\(Self.textList(candidate.originalTexts))",
                    "mergedTexts=\(Self.quotedText(candidate.mergedText ?? ""))",
                    "parsedStart=\(Self.timeText(candidate.parsedStartMinutes))",
                    "parsedEnd=\(Self.timeText(candidate.parsedEndMinutes))",
                    "remainingTitle=\(Self.quotedText(candidate.remainingTitle))",
                    "ocrConfidence=\(Self.decimalText(Double(candidate.ocrConfidence)))",
                    "quality=\(candidate.quality.rawValue)",
                    "timeParseQuality=\(candidate.timeParseQuality?.rawValue ?? "none")",
                    "holidayMatch=\(candidate.holidayMatch)",
                    "needsReview=\(candidate.needsReview)",
                    "selectedSource=\(candidate.selectedSource)",
                    "selectionReason=\(candidate.selectionReason)",
                    "templateMatched=\(candidate.templateMatched)",
                    "templateDistance=\(Self.integerText(candidate.templateDistance))",
                    "selectedTime=\(candidate.selectedTimeText.map(Self.quotedText) ?? "none")",
                    "selectedTimeSource=\(candidate.selectedTimeSource)",
                    "selectionScore=\(Self.decimalText(candidate.selectionScore))",
                    "rejectedAlternativeTimes=\(Self.textList(candidate.rejectedAlternativeTimes))",
                    "timeFragmentTexts=\(Self.textList(candidate.timeFragmentTexts))",
                    "titleTexts=\(Self.textList(candidate.titleTexts))",
                    "defaultSelected=\(candidate.defaultSelected)",
                    "candidateCreated=\(candidate.candidateCreated)",
                    "rejectedReason=\(candidate.rejectedReason?.rawValue ?? "none")"
                ].joined(separator: " ")
                let timeCandidateLines = candidate.allParsedTimeCandidates.enumerated().map {
                    candidateIndex, timeCandidate in
                    [
                        "day=\(cell.day)",
                        "appointmentGroup=\(candidate.appointmentGroup)",
                        "timeCandidate=\(candidateIndex + 1)",
                        "rawText=\(Self.quotedText(timeCandidate.rawText))",
                        "normalizedText=\(Self.quotedText(timeCandidate.normalizedText))",
                        "candidateSource=\(timeCandidate.source.rawValue)",
                        "primary=\(timeCandidate.isPrimary)",
                        "candidateConfidence=\(Self.decimalText(Double(timeCandidate.confidence)))",
                        "parseQuality=\(timeCandidate.parseQuality.rawValue)",
                        "parsedStart=\(Self.timeText(timeCandidate.parsedStartMinutes))",
                        "parsedEnd=\(Self.timeText(timeCandidate.parsedEndMinutes))",
                        "pageTemplateMatch=\(timeCandidate.pageTemplateMatch.map(Self.quotedText) ?? "none")",
                        "pageTemplateCount=\(Self.integerText(timeCandidate.pageTemplateCount))",
                        "pageTemplateDistance=\(Self.integerText(timeCandidate.pageTemplateDistance))",
                        "ocrConsensusCount=\(timeCandidate.ocrConsensusCount)",
                        "crossEngineConsensus=\(timeCandidate.crossEngineConsensus)",
                        "score=\(Self.decimalText(timeCandidate.score))"
                    ].joined(separator: " ")
                }
                return [summary] + timeCandidateLines
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
            Self.section(title: "TimeRecovery", lines: [
                "pageTimeTemplates=\(Self.textList(pageTimeTemplates))"
            ]),
            Self.section(title: "RecognitionCells", lines: recognitionLines),
            Self.section(title: "CellUpscaleRecovery", lines: cellUpscaleLines),
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
                "oneXTotalMs=\(decimalText(cell.oneXTotalMilliseconds))",
                "padding=\(cell.paddingApplied)",
                "ppocrText=\(textList(cell.ppOCRText))",
                "ppocrError=\(cell.ppOCRError ?? "none")",
                "cellUpscaleRecoveryAttempted=\(cell.cellUpscaleRecoveryAttempted)",
                "cellUpscale2xAttempted=\(cell.cellUpscaleAttempts.contains { $0.scaleFactor == 2 })",
                "cellUpscale3xAttempted=\(cell.cellUpscaleAttempts.contains { $0.scaleFactor == 3 })",
                "cellUpscaleSelectedScale=\(cell.cellUpscaleSelectedScale)",
                "fallbackUsed=\(cell.fallbackUsed)"
            ].joined(separator: " ")
        }
    }

    private static func cellUpscaleLines(
        _ cells: [CalendarPhotoCellRecognitionDiagnostics]
    ) -> [String] {
        cells.sorted(by: { $0.day < $1.day }).flatMap { cell -> [String] in
            guard cell.cellUpscaleRecoveryAttempted else { return [] }
            let header = [
                "day=\(cell.day)",
                "cellUpscaleRecoveryAttempted=true",
                "cellUpscale2xAttempted=\(cell.cellUpscaleAttempts.contains { $0.scaleFactor == 2 })",
                "cellUpscale3xAttempted=\(cell.cellUpscaleAttempts.contains { $0.scaleFactor == 3 })",
                "cellUpscaleSelectedScale=\(cell.cellUpscaleSelectedScale)"
            ].joined(separator: " ")
            let attempts = cell.cellUpscaleAttempts.flatMap { attempt -> [String] in
                let prefix = "cellUpscale\(attempt.scaleFactor)x"
                let selectedText = attempt.selectedTexts.first
                let summary = [
                    "day=\(cell.day)",
                    "\(prefix)Attempted=true",
                    "\(prefix)Pixels=\(pixelSizeText(attempt.cellPixels))",
                    "\(prefix)DetectorInputPixels=\(optionalPixelSizeText(attempt.detectorInputPixels))",
                    "\(prefix)DetectionCount=\(attempt.detectionCount)",
                    "\(prefix)Texts=\(textList(attempt.detections.map(\.selectedText)))",
                    "\(prefix)TimeCandidates=\(textList(attempt.timeCandidates))",
                    "\(prefix)SelectedText=\(selectedText.map(Self.quotedText) ?? "none")",
                    "\(prefix)SelectedTexts=\(textList(attempt.selectedTexts))",
                    "\(prefix)ParseResult=\(timeParseResult(selectedText))",
                    "\(prefix)SelectionReason=\(attempt.selectionReason)",
                    "\(prefix)TotalMs=\(decimalText(attempt.totalMilliseconds))",
                    "\(prefix)Error=\(attempt.error ?? "none")"
                ].joined(separator: " ")
                let detections = attempt.detections.enumerated().map { index, detection in
                    let bounds = detection.boundingBox
                    return [
                        "day=\(cell.day)",
                        "cellUpscaleScale=\(attempt.scaleFactor)x",
                        "detection=\(index + 1)",
                        "bbox=(x=\(decimalText(bounds.x)),y=\(decimalText(bounds.y)),w=\(decimalText(bounds.width)),h=\(decimalText(bounds.height)))",
                        "currentText=\(quotedText(detection.currentText))",
                        "selectedText=\(quotedText(detection.selectedText))",
                        "selectedSource=\(detection.selectedSource)",
                        "parseResult=\(timeParseResult(detection.selectedText))"
                    ].joined(separator: " ")
                }
                return [summary] + detections
            }
            return [header] + attempts
        }
    }

    private func cellUpscaleTotalMilliseconds(scaleFactor: Int) -> Double {
        recognitionCellDiagnostics
            .flatMap(\.cellUpscaleAttempts)
            .filter { $0.scaleFactor == scaleFactor }
            .map(\.totalMilliseconds)
            .reduce(0, +)
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

    private static func timeParseResult(_ text: String?) -> String {
        guard let text, let parsed = CalendarImportTimeParser.parseMonth(text) else {
            return "none"
        }
        let start = timeText(parsed.startMinutes)
        guard let end = parsed.endMinutes else { return start }
        return "\(start)-\(timeText(end))"
    }

    private static func boundingBoxText(_ box: CalendarOCRBoundingBox?) -> String {
        guard let box else { return "none" }
        return "(x=\(decimalText(box.x)),y=\(decimalText(box.y)),w=\(decimalText(box.width)),h=\(decimalText(box.height)))"
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

    static func dayScan(
        observations: [CalendarOCRObservation],
        selectedDate: Date,
        candidateCount: Int,
        stage: CalendarPhotoImportParseStage,
        failureReason: CalendarPhotoImportParseError?
    ) -> CalendarPhotoImportDiagnostics {
        let meaningful = observations.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let pureNumericCount = meaningful.filter { observation in
            observation.text.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(
                    options: .widthInsensitive,
                    locale: Locale(identifier: "en_US_POSIX")
                )
                .range(of: #"^\d+$"#, options: .regularExpression) != nil
        }.count
        return CalendarPhotoImportDiagnostics(
            scanMode: .day,
            selectedDate: selectedDate,
            gridDetection: "notApplicable",
            orientation: nil,
            manualYearMonth: nil,
            resolvedYearMonth: nil,
            observationCount: observations.count,
            meaningfulObservationCount: meaningful.count,
            pureNumericObservationCount: pureNumericCount,
            dateAnchorCount: 0,
            distinctDayCount: 0,
            sundayStartScore: 0,
            mondayStartScore: 0,
            selectedWeekStart: nil,
            gridColumnCount: 0,
            gridRowCount: 0,
            gridMatchedAnchorCount: 0,
            gridRejectedAnchorCount: 0,
            gridAcceptanceThreshold: 0,
            gridAccepted: false,
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
            dayRegionCount: 0,
            candidateCount: candidateCount,
            parseStage: stage,
            failureReason: failureReason
        )
    }
}

struct CalendarImportTimeParser {
    private struct MatchResult {
        let time: CalendarImportParsedTime
        let range: NSRange
    }

    static func parse(_ text: String) -> CalendarImportParsedTime? {
        match(in: text, includesCompactRecovery: false)?.time
    }

    static func parseMonth(_ text: String) -> CalendarImportParsedTime? {
        match(in: text, includesCompactRecovery: true)?.time
    }

    static func parseRangeOnly(_ text: String) -> CalendarImportParsedTime? {
        guard let parsed = parse(text), parsed.endMinutes != nil else { return nil }
        return parsed
    }

    static func parseMonthRangeOnly(_ text: String) -> CalendarImportParsedTime? {
        guard let parsed = parseMonth(text), parsed.endMinutes != nil else { return nil }
        return parsed
    }

    static func removingTime(from text: String) -> String {
        removingTime(from: text, includesCompactRecovery: false)
    }

    static func removingMonthTime(from text: String) -> String {
        removingTime(from: text, includesCompactRecovery: true)
    }

    static func monthTimeText(in text: String) -> String? {
        guard let match = match(in: text, includesCompactRecovery: true),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    private static func removingTime(
        from text: String,
        includesCompactRecovery: Bool
    ) -> String {
        guard let match = match(in: text, includesCompactRecovery: includesCompactRecovery),
              let range = Range(match.range, in: text) else {
            return text
        }
        var result = text
        result.removeSubrange(range)
        return result
    }

    private static func match(
        in text: String,
        includesCompactRecovery: Bool
    ) -> MatchResult? {
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
        if includesCompactRecovery, let recovered = compactRange(in: text) {
            return recovered
        }
        return nil
    }

    private static func compactRange(in text: String) -> MatchResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (7...9).contains(trimmed.count),
              trimmed.allSatisfy(\.isNumber),
              let sourceRange = text.range(of: trimmed) else {
            return nil
        }
        let digits = Array(trimmed)
        var candidates: [CalendarImportParsedTime] = []

        switch digits.count {
        case 7:
            appendCompactCandidate(
                digits: digits,
                startHourDigits: 1,
                endHourDigits: 2,
                to: &candidates
            )
            appendCompactCandidate(
                digits: digits,
                startHourDigits: 2,
                endHourDigits: 1,
                to: &candidates
            )
        case 8:
            appendCompactCandidate(
                digits: digits,
                startHourDigits: 2,
                endHourDigits: 2,
                to: &candidates
            )
        case 9:
            for offset in 0...1 {
                appendCompactCandidate(
                    digits: Array(digits[offset..<(offset + 8)]),
                    startHourDigits: 2,
                    endHourDigits: 2,
                    to: &candidates
                )
            }
        default:
            return nil
        }

        var unique: [String: CalendarImportParsedTime] = [:]
        for candidate in candidates {
            let key = "\(candidate.startMinutes)-\(candidate.endMinutes ?? -1)"
            unique[key] = candidate
        }
        guard unique.count == 1, let time = unique.values.first else { return nil }
        return MatchResult(
            time: time,
            range: NSRange(sourceRange, in: text)
        )
    }

    private static func appendCompactCandidate(
        digits: [Character],
        startHourDigits: Int,
        endHourDigits: Int,
        to candidates: inout [CalendarImportParsedTime]
    ) {
        let expectedCount = startHourDigits + 2 + endHourDigits + 2
        guard digits.count == expectedCount else { return }
        let startMinuteIndex = startHourDigits
        let endHourIndex = startMinuteIndex + 2
        let endMinuteIndex = endHourIndex + endHourDigits
        guard let startHour = integer(digits[0..<startMinuteIndex]),
              let startMinute = integer(digits[startMinuteIndex..<endHourIndex]),
              let endHour = integer(digits[endHourIndex..<endMinuteIndex]),
              let endMinute = integer(digits[endMinuteIndex..<digits.count]),
              isValid(hour: startHour, minute: startMinute),
              isValid(hour: endHour, minute: endMinute) else {
            return
        }
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        guard end > start else { return }
        candidates.append(CalendarImportParsedTime(
            startMinutes: start,
            endMinutes: end,
            parseQuality: .recovered
        ))
    }

    private static func integer(_ digits: ArraySlice<Character>) -> Int? {
        Int(String(digits))
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

struct CalendarMonthOCRObservationMerger {
    func merge(
        ppOCRObservations: [CalendarOCRObservation],
        visionObservations: [CalendarOCRObservation],
        regions: [CalendarImportDayRegion],
        visionFallbackRegions: [CalendarImportDayRegion]
    ) -> [CalendarOCRObservation] {
        let fallbackDays = Set(visionFallbackRegions.map(\.day))
        var merged: [CalendarOCRObservation] = []

        for region in regions.sorted(by: { $0.day < $1.day }) {
            let ppOCRCell = ppOCRObservations.filter(region.contains)
            let visionCell = visionObservations.filter(region.contains)
            if fallbackDays.contains(region.day) {
                merged.append(contentsOf: visionCell)
                continue
            }

            merged.append(contentsOf: ppOCRCell.compactMap(Self.timeOrNumericObservation))
            merged.append(contentsOf: visionCell.compactMap(Self.titleObservation))
        }
        return merged
    }

    private static func timeOrNumericObservation(
        _ observation: CalendarOCRObservation
    ) -> CalendarOCRObservation? {
        if let timeText = CalendarImportTimeParser.monthTimeText(in: observation.text) {
            return replacingText(timeText, in: observation, reason: "ppocrTime")
        }
        guard !containsLetter(observation.text) else { return nil }
        return observation
    }

    private static func titleObservation(
        _ observation: CalendarOCRObservation
    ) -> CalendarOCRObservation? {
        let title = CalendarImportTimeParser.removingMonthTime(from: observation.text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard containsLetter(title) else { return nil }
        return replacingText(title, in: observation, reason: "visionLanguageAwareTitle")
    }

    private static func replacingText(
        _ text: String,
        in observation: CalendarOCRObservation,
        reason: String
    ) -> CalendarOCRObservation {
        CalendarOCRObservation(
            text: text,
            confidence: observation.confidence,
            boundingBox: observation.boundingBox,
            candidateDiagnostics: observation.candidateDiagnostics,
            selectionReason: reason,
            timeParseQualityOverride: observation.timeParseQualityOverride
        )
    }

    private static func containsLetter(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.letters.contains($0) }
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
            pageTimeTemplates: buildResult.pageTimeTemplates,
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
        calendar: Calendar = Calendar(identifier: .gregorian),
        diagnosticsHandler: ((CalendarPhotoImportDiagnostics) -> Void)? = nil
    ) throws -> CalendarPhotoImportParseResult {
        let meaningful = observations.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !meaningful.isEmpty else {
            diagnosticsHandler?(.dayScan(
                observations: observations,
                selectedDate: selectedDate,
                candidateCount: 0,
                stage: .text,
                failureReason: .noText
            ))
            throw CalendarPhotoImportParseError.noText
        }
        let candidates = CalendarImportCandidateBuilder().makeDayCandidates(
            observations: meaningful,
            selectedDate: selectedDate,
            calendarID: defaultCalendarID,
            calendar: calendar
        )
        guard !candidates.isEmpty else {
            diagnosticsHandler?(.dayScan(
                observations: observations,
                selectedDate: selectedDate,
                candidateCount: 0,
                stage: .candidates,
                failureReason: .noCandidates
            ))
            throw CalendarPhotoImportParseError.noCandidates
        }
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        diagnosticsHandler?(.dayScan(
            observations: observations,
            selectedDate: selectedDate,
            candidateCount: candidates.count,
            stage: .completed,
            failureReason: nil
        ))
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
    var pageTimeTemplates: [String] = []
}

private struct CalendarImportCandidateBuilder {
    private struct Line { var observations: [CalendarOCRObservation] }

    private struct ParsedLine {
        let observations: [CalendarOCRObservation]
        let rawText: String
        let normalizedText: String
        let time: CalendarImportParsedTime?
        let isTimeLike: Bool
        let usedMergedText: Bool
        let templateDistance: Int?
        let timeCandidates: [CalendarOCRCandidate]
        let timeSelection: CalendarOCRTimeSelection?
    }

    private struct AppointmentGroup {
        let index: Int
        var lines: [ParsedLine]
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
        let pageTimeTemplates = CalendarMonthTimeRecovery.templates(from: observations)

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
            let rejectedNoParsedTimeLineCount: Int
            if let date {
                let holidayNames = DateOnly(from: date, in: calendar.timeZone)
                    .map { holidayNamesByDate[$0] ?? [] } ?? []
                (
                    cellCandidates,
                    candidateDiagnostics,
                    rejectedNoParsedTimeLineCount
                ) = makeMonthCellCandidates(
                    observations: meaningful,
                    date: date,
                    calendarID: calendarID,
                    holidayNames: holidayNames,
                    pageTimeTemplates: pageTimeTemplates
                )
            } else {
                cellCandidates = []
                candidateDiagnostics = []
                rejectedNoParsedTimeLineCount = 0
            }
            candidates.append(contentsOf: cellCandidates)

            let rejectedReason: CalendarPhotoCellRejectionReason?
            if date == nil {
                rejectedReason = .invalidDate
            } else if assigned.isEmpty {
                rejectedReason = .noObservations
            } else if content.isEmpty {
                rejectedReason = .printedDayOnly
            } else if meaningful.isEmpty {
                rejectedReason = .emptyText
            } else if rejectedNoParsedTimeLineCount > 0 {
                rejectedReason = .noParsedTime
            } else if cellCandidates.isEmpty {
                rejectedReason = .noParsedTime
            } else {
                rejectedReason = nil
            }
            diagnostics.append(CalendarPhotoCellDiagnostics(
                day: region.day,
                cellBounds: region.boundingBox,
                observationCount: assigned.count,
                printedDayObservationCount: printedDayCount,
                rawTexts: content.map(\.text),
                normalizedTexts: content.map { normalizedText($0.text) },
                candidates: candidateDiagnostics,
                rejectedNoParsedTimeLineCount: rejectedNoParsedTimeLineCount,
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
            unassignedNormalizedTexts: unassigned.map { normalizedText($0.text) },
            pageTimeTemplates: pageTimeTemplates.map {
                "\($0.displayText)(count=\($0.occurrenceCount),bestConfidence="
                    + String(format: "%.4f", Double($0.bestConfidence)) + ")"
            }
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
        holidayNames: Set<String>,
        pageTimeTemplates: [CalendarMonthTimeTemplate]
    ) -> (
        [CalendarImportCandidate],
        [CalendarPhotoCellCandidateDiagnostics],
        rejectedNoParsedTimeLineCount: Int
    ) {
        let groupedLines = group(observations, separatesStackedTimeRows: true)
        let separatorFreeRecoveredLineCount = groupedLines.reduce(into: 0) { count, line in
            let normalized = normalizedText(line.observations.map(\.text).joined(separator: " "))
            guard let parsed = CalendarImportTimeParser.parseMonth(normalized),
                  parsed.parseQuality == .recovered,
                  let endMinutes = parsed.endMinutes,
                  endMinutes > parsed.startMinutes,
                  !normalized.contains(where: { "-–—〜～~".contains($0) }) else {
                return
            }
            count += 1
        }
        let hasIndependentSeparatorFreeRecoveredLines = separatorFreeRecoveredLineCount >= 2
        let parsedLines = groupedLines.compactMap { line -> ParsedLine? in
            let sorted = line.observations.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            let rawText = sorted.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizedText(rawText)
            guard !normalized.isEmpty else { return nil }
            let compactMerged = sorted.map(\.text).joined()
            let candidates = ocrCandidates(from: sorted)
            let safeCandidates = safelySupportedTimeCandidates(
                candidates,
                hasIndependentSeparatorFreeRecoveredLines:
                    hasIndependentSeparatorFreeRecoveredLines
            )
            let timeSelection = CalendarOCRCandidateSelector.selectMonthTime(
                from: safeCandidates,
                pageTemplates: pageTimeTemplates
            )
            let directTime: CalendarImportParsedTime? = timeSelection?.selected.time
                ?? CalendarImportTimeParser.parseMonth(normalized).flatMap {
                    parsed -> CalendarImportParsedTime? in
                    // A separator-free range is too easy for one OCR route to invent.
                    // It still needs independent OCR or another separately grouped
                    // range; page-template similarity alone cannot make it valid.
                    if isSeparatorFreeRecoveredTime(parsed, text: normalized),
                       !hasIndependentSeparatorFreeRecoveredLines {
                        return nil
                    }
                    return parsed
                }
            let mergedRecovery = canMergeTimeFragments(sorted)
                ? CalendarMonthTimeRecovery.recover(compactMerged, templates: pageTimeTemplates)
                : nil
            let recovery = mergedRecovery
                ?? CalendarMonthTimeRecovery.recover(normalized, templates: pageTimeTemplates)
            let parsedTime = (directTime ?? recovery?.time).map { parsed in
                guard sorted.contains(where: {
                    $0.timeParseQualityOverride == .recovered
                }) else { return parsed }
                return CalendarImportParsedTime(
                    startMinutes: parsed.startMinutes,
                    endMinutes: parsed.endMinutes,
                    parseQuality: .recovered
                )
            }
            return ParsedLine(
                observations: sorted,
                rawText: rawText,
                normalizedText: normalized,
                time: parsedTime,
                isTimeLike: sorted.contains { CalendarMonthTimeRecovery.isTimeLike($0.text) },
                usedMergedText: mergedRecovery != nil,
                templateDistance: timeSelection?.selected.pageTemplateDistance
                    ?? recovery?.distance,
                timeCandidates: safeCandidates,
                timeSelection: timeSelection
            )
        }

        var candidates: [CalendarImportCandidate] = []
        var diagnostics: [CalendarPhotoCellCandidateDiagnostics] = []
        var pendingTitleLines: [ParsedLine] = []
        var rejectedNoParsedTimeLines: [ParsedLine] = []
        var appointmentGroups: [AppointmentGroup] = []

        for line in parsedLines {
            if line.time != nil {
                if pendingTitleLines.isEmpty,
                   let lastIndex = appointmentGroups.indices.last,
                   isAlternativeTimeEvidence(
                       line,
                       for: appointmentGroups[lastIndex]
                   ) {
                    appointmentGroups[lastIndex].lines.append(line)
                } else {
                    appointmentGroups.append(AppointmentGroup(
                        index: appointmentGroups.count + 1,
                        lines: pendingTitleLines + [line]
                    ))
                    pendingTitleLines.removeAll(keepingCapacity: true)
                }
            } else if pendingTitleLines.isEmpty,
                      let lastIndex = appointmentGroups.indices.last,
                      isAlternativeTimeEvidence(
                          line,
                          for: appointmentGroups[lastIndex]
                      ) {
                appointmentGroups[lastIndex].lines.append(line)
            } else {
                pendingTitleLines.append(line)
            }
        }

        for group in appointmentGroups {
            let sourceLines = group.lines
            let groupCandidates = safelySupportedTimeCandidates(
                sourceLines.flatMap(\.timeCandidates),
                hasIndependentSeparatorFreeRecoveredLines:
                    hasIndependentSeparatorFreeRecoveredLines
            )
            let selection = CalendarOCRCandidateSelector.selectMonthTime(
                from: groupCandidates,
                pageTemplates: pageTimeTemplates
            )
            guard !sourceLines.isEmpty,
                  let rawTime = selection?.selected.time
                    ?? sourceLines.compactMap(\.time).first else { continue }
            let time = sourceLines.contains(where: { line in
                line.observations.contains { $0.timeParseQualityOverride == .recovered }
            }) ? CalendarImportParsedTime(
                startMinutes: rawTime.startMinutes,
                endMinutes: rawTime.endMinutes,
                parseQuality: .recovered
            ) : rawTime
            let originalText = sourceLines.map(\.rawText).joined(separator: " ")
            let normalized = sourceLines.map(\.normalizedText).joined(separator: " ")
            let personToken = personToken(in: normalized)
            let titleEvidence = titleEvidence(
                from: sourceLines,
                selectedTime: time
            )
            var title = titleEvidence.titleTexts.joined(separator: " ")
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
            // Timed candidates remain selectable even when their title matches a holiday.
            let holidayMatch = false
            let defaultSelected = quality != .lowInformation && !holidayMatch
            let incompleteTime: Bool
            if let endMinutes = time.endMinutes {
                incompleteTime = endMinutes <= time.startMinutes
            } else {
                incompleteTime = true
            }
            let needsReview = quality == .lowInformation
                || holidayMatch
                || time.parseQuality != .exact
                || confidence < 0.75
                || incompleteTime
                || title.isEmpty
                || personToken != nil
                || selection?.requiresReview == true
            candidates.append(CalendarImportCandidate(
                id: UUID(),
                date: date,
                startTimeMinutes: time.startMinutes,
                endTimeMinutes: time.endMinutes,
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
            let selectedEvaluation = selection?.selected
            let selectionReason: String
            let selectedSource: String
            if let selection {
                if selection.evaluations.count == 1,
                   selection.selected.candidate.source == .observation,
                   selection.selected.pageTemplateDistance != 0 {
                    selectionReason = "directParse"
                    selectedSource = "ocr"
                } else {
                    selectionReason = selection.selectionReason
                    selectedSource = selection.selected.candidate.source.rawValue
                }
            } else if sourceLines.contains(where: { $0.templateDistance != nil }) {
                selectionReason = "uniqueTemplateWithinTwoEdits"
                selectedSource = "pageTemplate"
            } else {
                selectionReason = "directParse"
                selectedSource = "ocr"
            }
            let rejectedAlternatives = uniqueStrings(selection?.evaluations.compactMap { evaluation in
                guard evaluation.time.startMinutes != time.startMinutes
                    || evaluation.time.endMinutes != time.endMinutes else { return nil }
                return displayText(evaluation.time)
            } ?? [])
            diagnostics.append(CalendarPhotoCellCandidateDiagnostics(
                originalTexts: candidateObservations.map(\.text),
                mergedText: sourceLines.first(where: \.usedMergedText)?.normalizedText,
                selectedSource: selectedSource,
                selectionReason: selectionReason,
                templateMatched: selectedEvaluation?.pageTemplateDistance == 0
                    || (selection == nil
                        && sourceLines.contains(where: { $0.templateDistance != nil })),
                templateDistance: selectedEvaluation?.pageTemplateDistance
                    ?? sourceLines.compactMap(\.templateDistance).min(),
                parsedStartMinutes: time.startMinutes,
                parsedEndMinutes: time.endMinutes,
                remainingTitle: title,
                ocrConfidence: confidence,
                quality: quality,
                timeParseQuality: time.parseQuality,
                holidayMatch: holidayMatch,
                needsReview: needsReview,
                defaultSelected: defaultSelected,
                candidateCreated: true,
                rejectedReason: nil,
                allParsedTimeCandidates: selection?.evaluations.compactMap {
                    evaluation -> CalendarPhotoTimeCandidateDiagnostics? in
                    guard let end = evaluation.time.endMinutes else { return nil }
                    return CalendarPhotoTimeCandidateDiagnostics(
                        rawText: evaluation.candidate.text,
                        normalizedText: normalizedText(evaluation.candidate.text),
                        source: evaluation.candidate.source,
                        isPrimary: evaluation.candidate.isPrimary,
                        confidence: evaluation.candidate.confidence,
                        parseQuality: evaluation.time.parseQuality,
                        parsedStartMinutes: evaluation.time.startMinutes,
                        parsedEndMinutes: end,
                        pageTemplateMatch: evaluation.pageTemplate?.displayText,
                        pageTemplateCount: evaluation.pageTemplate?.occurrenceCount,
                        pageTemplateDistance: evaluation.pageTemplateDistance,
                        ocrConsensusCount: evaluation.consensusCount,
                        crossEngineConsensus: evaluation.hasCrossEngineConsensus,
                        score: evaluation.score
                    )
                } ?? [],
                selectedTimeText: displayText(time),
                selectedTimeSource: selectedEvaluation?.candidate.source.rawValue
                    ?? selectedSource,
                selectionScore: selectedEvaluation?.score,
                rejectedAlternativeTimes: rejectedAlternatives,
                timeFragmentTexts: titleEvidence.timeFragmentTexts,
                titleTexts: titleEvidence.titleTexts,
                appointmentGroup: group.index
            ))
        }

        rejectedNoParsedTimeLines.append(contentsOf: pendingTitleLines)
        return (
            candidates,
            diagnostics,
            rejectedNoParsedTimeLines.count
        )
    }

    private func ocrCandidates(
        from observations: [CalendarOCRObservation]
    ) -> [CalendarOCRCandidate] {
        var result: [CalendarOCRCandidate] = []
        for observation in observations {
            var alternatives = observation.candidateDiagnostics
            if alternatives.isEmpty {
                alternatives = [CalendarOCRCandidate(
                    text: observation.text,
                    confidence: observation.confidence,
                    source: .observation,
                    isPrimary: true
                )]
            } else if !alternatives.contains(where: \.isPrimary),
                      !alternatives.isEmpty {
                alternatives[0].isPrimary = true
            }
            if !alternatives.contains(where: {
                normalizedText($0.text) == normalizedText(observation.text)
                    && abs($0.confidence - observation.confidence) < 0.000_1
            }) {
                alternatives.append(CalendarOCRCandidate(
                    text: observation.text,
                    confidence: observation.confidence,
                    source: .observation,
                    isPrimary: false
                ))
            }
            for alternative in alternatives where !result.contains(where: {
                normalizedText($0.text) == normalizedText(alternative.text)
                    && $0.source == alternative.source
                    && abs($0.confidence - alternative.confidence) < 0.000_1
            }) {
                result.append(alternative)
            }
        }
        return result
    }

    private func safelySupportedTimeCandidates(
        _ candidates: [CalendarOCRCandidate],
        hasIndependentSeparatorFreeRecoveredLines: Bool
    ) -> [CalendarOCRCandidate] {
        candidates.filter { candidate in
            guard let time = CalendarImportTimeParser.parseMonthRangeOnly(candidate.text),
                  isSeparatorFreeRecoveredTime(time, text: candidate.text) else {
                return true
            }
            if hasIndependentSeparatorFreeRecoveredLines { return true }
            let agreementCount = candidates.filter { other in
                guard let parsed = CalendarImportTimeParser.parseMonthRangeOnly(other.text) else {
                    return false
                }
                return parsed.startMinutes == time.startMinutes
                    && parsed.endMinutes == time.endMinutes
            }.count
            return agreementCount >= 2
        }
    }

    private func isSeparatorFreeRecoveredTime(
        _ time: CalendarImportParsedTime,
        text: String
    ) -> Bool {
        time.parseQuality == .recovered
            && !text.contains(where: { "-–—〜～~".contains($0) })
    }

    private func isAlternativeTimeEvidence(
        _ line: ParsedLine,
        for group: AppointmentGroup
    ) -> Bool {
        guard let selectedTime = group.lines.compactMap(\.time).last,
              line.isTimeLike || line.time != nil,
              let lineBounds = combinedBounds(line.observations),
              let anchorBounds = combinedBounds(
                  group.lines.reversed().first(where: { $0.time != nil })?.observations ?? []
              ),
              areNeighboring(lineBounds, anchorBounds),
              isTimeEvidence(line.normalizedText, similarTo: selectedTime) else {
            return false
        }
        let residual = cleanedTitle(
            CalendarImportTimeParser.removingMonthTime(from: line.normalizedText)
        )
        return residual.isEmpty || line.isTimeLike
    }

    private func titleEvidence(
        from lines: [ParsedLine],
        selectedTime: CalendarImportParsedTime
    ) -> (titleTexts: [String], timeFragmentTexts: [String]) {
        var titleTexts: [String] = []
        var timeFragmentTexts: [String] = []
        for line in lines {
            for observation in line.observations {
                let text = normalizedText(observation.text)
                guard !text.isEmpty else { continue }
                let withoutTime = cleanedTitle(
                    CalendarImportTimeParser.removingMonthTime(from: text)
                )
                if withoutTime != cleanedTitle(text) {
                    if withoutTime.isEmpty {
                        timeFragmentTexts.append(text)
                    } else {
                        titleTexts.append(withoutTime)
                    }
                } else if isTimeEvidence(text, similarTo: selectedTime)
                            || (line.isTimeLike
                                && CalendarMonthTimeRecovery.isTimeLike(text)) {
                    timeFragmentTexts.append(text)
                } else {
                    titleTexts.append(text)
                }
            }
        }
        return (
            uniqueStrings(titleTexts),
            uniqueStrings(timeFragmentTexts)
        )
    }

    private func isTimeEvidence(
        _ text: String,
        similarTo selectedTime: CalendarImportParsedTime
    ) -> Bool {
        let digits = CalendarMonthTimeRecovery.comparisonKey(text)
        let selectedDigits = CalendarMonthTimeRecovery.comparisonKey(displayText(selectedTime))
        guard digits.count >= 4,
              CalendarMonthTimeRecovery.isTimeLike(text)
                || CalendarImportTimeParser.parseMonth(text) != nil else {
            return false
        }
        if selectedDigits.contains(digits) || digits.contains(selectedDigits) { return true }
        let distance = CalendarMonthTimeRecovery.editDistance(digits, selectedDigits)
        if distance <= 2 { return true }
        guard let parsed = CalendarImportTimeParser.parseMonth(text) else { return false }
        if parsed.endMinutes == nil {
            return parsed.startMinutes == selectedTime.startMinutes
                || parsed.startMinutes == selectedTime.endMinutes
        }
        return (parsed.startMinutes == selectedTime.startMinutes
                || parsed.endMinutes == selectedTime.endMinutes)
            && distance <= 2
    }

    private func areNeighboring(
        _ lhs: CalendarOCRBoundingBox,
        _ rhs: CalendarOCRBoundingBox
    ) -> Bool {
        let verticalOverlap = min(lhs.maxY, rhs.maxY) - max(lhs.minY, rhs.minY)
        let verticalGap = max(0, max(lhs.minY, rhs.minY) - min(lhs.maxY, rhs.maxY))
        let horizontalOverlap = min(lhs.maxX, rhs.maxX) - max(lhs.minX, rhs.minX)
        let minimumWidth = min(lhs.width, rhs.width)
        return (verticalOverlap >= min(lhs.height, rhs.height) * 0.15
                || verticalGap <= max(lhs.height, rhs.height) * 0.8)
            && horizontalOverlap >= minimumWidth * 0.20
    }

    private func combinedBounds(
        _ observations: [CalendarOCRObservation]
    ) -> CalendarOCRBoundingBox? {
        guard let first = observations.first else { return nil }
        let minX = observations.dropFirst().reduce(first.boundingBox.minX) {
            min($0, $1.boundingBox.minX)
        }
        let maxX = observations.dropFirst().reduce(first.boundingBox.maxX) {
            max($0, $1.boundingBox.maxX)
        }
        let minY = observations.dropFirst().reduce(first.boundingBox.minY) {
            min($0, $1.boundingBox.minY)
        }
        let maxY = observations.dropFirst().reduce(first.boundingBox.maxY) {
            max($0, $1.boundingBox.maxY)
        }
        return CalendarOCRBoundingBox(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private func displayText(_ time: CalendarImportParsedTime) -> String {
        let start = String(
            format: "%02d:%02d",
            time.startMinutes / 60,
            time.startMinutes % 60
        )
        guard let end = time.endMinutes else { return start }
        return start + String(format: "-%02d:%02d", end / 60, end % 60)
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            if !result.contains(value) { result.append(value) }
        }
    }

    private func group(
        _ observations: [CalendarOCRObservation],
        separatesStackedTimeRows: Bool = false
    ) -> [Line] {
        var lines: [Line] = []
        for observation in observations.sorted(by: observationOrder) {
            if let index = lines.indices.min(by: {
                abs(centerY(lines[$0]) - observation.boundingBox.midY)
                    < abs(centerY(lines[$1]) - observation.boundingBox.midY)
            }), separatesStackedTimeRows
                ? canJoinMonthObservation(observation, to: lines[index])
                : abs(centerY(lines[index]) - observation.boundingBox.midY)
                    <= max(averageHeight(lines[index]), observation.boundingBox.height) * 0.7 {
                lines[index].observations.append(observation)
            } else {
                lines.append(Line(observations: [observation]))
            }
        }
        return lines
    }

    private func canJoinMonthObservation(
        _ observation: CalendarOCRObservation,
        to line: Line
    ) -> Bool {
        let centerDistance = abs(centerY(line) - observation.boundingBox.midY)
        let maximumHeight = max(averageHeight(line), observation.boundingBox.height)
        guard centerDistance <= maximumHeight * 0.7 else { return false }
        let existingTimes = line.observations.compactMap {
            CalendarImportTimeParser.parseMonthRangeOnly($0.text)
        }
        let incomingTime = CalendarImportTimeParser.parseMonthRangeOnly(observation.text)
        if (!existingTimes.isEmpty || incomingTime != nil),
           centerDistance > maximumHeight * 0.45 {
            return false
        }
        if !existingTimes.isEmpty, incomingTime != nil,
           let bounds = combinedBounds(line.observations) {
            let overlap = min(bounds.maxX, observation.boundingBox.maxX)
                - max(bounds.minX, observation.boundingBox.minX)
            let minimumWidth = min(bounds.width, observation.boundingBox.width)
            if overlap >= minimumWidth * 0.4 {
                return centerDistance <= maximumHeight * 0.3
            }
        }
        let bounds = combinedBounds(line.observations)
        let verticalOverlap = bounds.map {
            min($0.maxY, observation.boundingBox.maxY)
                - max($0.minY, observation.boundingBox.minY)
        } ?? 0
        return verticalOverlap >= min(averageHeight(line), observation.boundingBox.height) * 0.25
            || centerDistance <= maximumHeight * 0.45
    }

    private func canMergeTimeFragments(_ observations: [CalendarOCRObservation]) -> Bool {
        guard observations.count == 2 else { return false }
        let sorted = observations.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        let left = sorted[0], right = sorted[1]
        let overlap = min(left.boundingBox.maxY, right.boundingBox.maxY)
            - max(left.boundingBox.minY, right.boundingBox.minY)
        let minimumHeight = min(left.boundingBox.height, right.boundingBox.height)
        let gap = right.boundingBox.minX - left.boundingBox.maxX
        return overlap >= minimumHeight * 0.45
            && abs(left.boundingBox.midY - right.boundingBox.midY)
                <= max(left.boundingBox.height, right.boundingBox.height) * 0.55
            && gap >= -min(left.boundingBox.width, right.boundingBox.width) * 0.15
            && gap <= max(left.boundingBox.height, right.boundingBox.height) * 3
            && observations.contains { CalendarMonthTimeRecovery.isTimeLike($0.text) }
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
                guard !originalText.isEmpty,
                      let time = CalendarImportTimeParser.parse(originalText) else {
                    continue
                }
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
                    || time.endMinutes == nil
                    || time.parseQuality != .exact
                    || title.isEmpty
                    || personToken != nil
                result.append(CalendarImportCandidate(
                    id: UUID(),
                    date: date,
                    startTimeMinutes: time.startMinutes,
                    endTimeMinutes: time.endMinutes,
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
