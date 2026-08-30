import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
@preconcurrency import Vision

private enum CalendarPhotoImportImageError: Error {
    case invalidImage
    case noWritableCalendar
}

private enum CalendarPhotoImportStep {
    case source
    case recognizing
    case review
}

private enum CalendarPhotoImportImageNormalizer {
    static func normalizedCGImage(from image: UIImage) throws -> CGImage {
        let rawWidth = image.cgImage.map { CGFloat($0.width) }
            ?? image.size.width * max(image.scale, 1)
        let rawHeight = image.cgImage.map { CGFloat($0.height) }
            ?? image.size.height * max(image.scale, 1)
        let swapsDimensions: Bool
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            swapsDimensions = true
        default:
            swapsDimensions = false
        }
        let sourceWidth = swapsDimensions ? rawHeight : rawWidth
        let sourceHeight = swapsDimensions ? rawWidth : rawHeight
        guard sourceWidth > 0, sourceHeight > 0 else {
            throw CalendarPhotoImportImageError.invalidImage
        }

        let maximumDimension: CGFloat = 4_096
        let scale = min(1, maximumDimension / max(sourceWidth, sourceHeight))
        let targetSize = CGSize(
            width: max(1, (sourceWidth * scale).rounded()),
            height: max(1, (sourceHeight * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let cgImage = normalized.cgImage else {
            throw CalendarPhotoImportImageError.invalidImage
        }
        return cgImage
    }

    static func resizedCGImage(
        _ image: CGImage,
        maximumDimension: Int
    ) throws -> CGImage {
        let sourceWidth = image.width
        let sourceHeight = image.height
        guard sourceWidth > 0, sourceHeight > 0, maximumDimension > 0 else {
            throw CalendarPhotoImportImageError.invalidImage
        }
        let scale = min(
            1,
            CGFloat(maximumDimension) / CGFloat(max(sourceWidth, sourceHeight))
        )
        let targetWidth = max(1, Int((CGFloat(sourceWidth) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(sourceHeight) * scale).rounded()))
        guard targetWidth != sourceWidth || targetHeight != sourceHeight else {
            return image
        }
        guard let context = bitmapContext(width: targetWidth, height: targetHeight) else {
            throw CalendarPhotoImportImageError.invalidImage
        }
        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(
                x: 0,
                y: 0,
                width: CGFloat(targetWidth),
                height: CGFloat(targetHeight)
            )
        )
        guard let resized = context.makeImage() else {
            throw CalendarPhotoImportImageError.invalidImage
        }
        return resized
    }

    static func rotatedCGImage(
        _ image: CGImage,
        rotation: CalendarPhotoRotation
    ) throws -> CGImage {
        guard rotation != .degrees0 else { return image }
        let swapsDimensions = rotation == .degrees90 || rotation == .degrees270
        let outputWidth = swapsDimensions ? image.height : image.width
        let outputHeight = swapsDimensions ? image.width : image.height
        guard let context = bitmapContext(width: outputWidth, height: outputHeight) else {
            throw CalendarPhotoImportImageError.invalidImage
        }

        let radians = -CGFloat(rotation.rawValue) * .pi / 180
        context.interpolationQuality = .high
        context.translateBy(
            x: CGFloat(outputWidth) / 2,
            y: CGFloat(outputHeight) / 2
        )
        context.rotate(by: radians)
        context.draw(
            image,
            in: CGRect(
                x: -CGFloat(image.width) / 2,
                y: -CGFloat(image.height) / 2,
                width: CGFloat(image.width),
                height: CGFloat(image.height)
            )
        )
        guard let rotated = context.makeImage() else {
            throw CalendarPhotoImportImageError.invalidImage
        }
        return rotated
    }

    private static func bitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}

private struct CalendarVisionOCRResult: Sendable {
    let rotation: CalendarPhotoRotation
    let observations: [CalendarOCRObservation]
    let accurateCandidates: [CalendarPhotoOrientationCandidate]
    let orientationDiagnostics: CalendarPhotoOrientationDiagnostics
    let grid: CalendarPhotoGridGeometry?
}

private struct CalendarVisionOCRService {
    private static let directionDetectionMaximumDimension = 1_600

    func recognize(
        image: CGImage,
        preferredLanguageCode: String,
        expectedGridRows: Int?
    ) async throws -> CalendarVisionOCRResult {
        try await Task.detached(priority: .userInitiated) {
            let observations = try Self.recognizeSynchronously(
                image: image,
                preferredLanguageCode: preferredLanguageCode,
                recognitionLevel: .accurate
            )
            let grid: CalendarPhotoGridGeometry?
            if let expectedGridRows {
                grid = try Self.detectMainGrid(image: image, expectedRows: expectedGridRows)
            } else {
                grid = nil
            }
            return CalendarVisionOCRResult(
                rotation: .degrees0,
                observations: observations,
                accurateCandidates: [],
                orientationDiagnostics: CalendarPhotoOrientationDiagnostics(
                    selectedRotation: .degrees0,
                    evidencePhase: .accurate,
                    candidates: []
                ),
                grid: grid
            )
        }.value
    }

    func recognizeBestOrientation(
        image: CGImage,
        preferredLanguageCode: String
    ) async throws -> CalendarVisionOCRResult {
        try await Task.detached(priority: .userInitiated) {
            let selector = CalendarPhotoOrientationSelector()
            let preview = try CalendarPhotoImportImageNormalizer.resizedCGImage(
                image,
                maximumDimension: Self.directionDetectionMaximumDimension
            )
            var fastCandidates: [CalendarPhotoOrientationCandidate] = []
            for rotation in CalendarPhotoRotation.allCases {
                let rotated = try CalendarPhotoImportImageNormalizer.rotatedCGImage(
                    preview,
                    rotation: rotation
                )
                let observations = try Self.recognizeSynchronously(
                    image: rotated,
                    preferredLanguageCode: preferredLanguageCode,
                    recognitionLevel: .fast
                )
                fastCandidates.append(CalendarPhotoOrientationCandidate(
                    rotation: rotation,
                    observations: observations
                ))
            }
            guard let fastSelection = selector.selectBest(from: fastCandidates) else {
                throw CalendarPhotoImportImageError.invalidImage
            }
            Self.debugLog(candidates: fastCandidates, phase: "fast")

            let selectedObservations: [CalendarOCRObservation] = try {
                let selectedImage = try CalendarPhotoImportImageNormalizer.rotatedCGImage(
                    image,
                    rotation: fastSelection.rotation
                )
                return try Self.recognizeSynchronously(
                    image: selectedImage,
                    preferredLanguageCode: preferredLanguageCode,
                    recognitionLevel: .accurate
                )
            }()
            var accurateCandidates = [CalendarPhotoOrientationCandidate(
                rotation: fastSelection.rotation,
                observations: selectedObservations
            )]
            var accurateSelection = selector.selectBest(from: accurateCandidates)

            // If the low-cost pass chose on weak OCR evidence, evaluate the other
            // full-resolution directions before committing observations to parsing.
            // Keep all four accurate candidates when automatic year/month recognition
            // failed so a later manual selection can re-evaluate orientation.
            if fastSelection.evidence.hasReliableCalendarStructure != true
                || accurateSelection?.evidence.hasReliableCalendarStructure != true
                || accurateSelection?.evidence.yearMonth == nil {
                for rotation in CalendarPhotoRotation.allCases
                    where rotation != fastSelection.rotation {
                    let rotated = try CalendarPhotoImportImageNormalizer.rotatedCGImage(
                        image,
                        rotation: rotation
                    )
                    let observations = try Self.recognizeSynchronously(
                        image: rotated,
                        preferredLanguageCode: preferredLanguageCode,
                        recognitionLevel: .accurate
                    )
                    accurateCandidates.append(CalendarPhotoOrientationCandidate(
                        rotation: rotation,
                        observations: observations
                    ))
                }
                accurateSelection = selector.selectBest(from: accurateCandidates)
            }
            guard let accurateSelection else {
                throw CalendarPhotoImportImageError.invalidImage
            }
            let hasAllAccurateCandidates = accurateCandidates.count
                == CalendarPhotoRotation.allCases.count
            let orientationDiagnostics = CalendarPhotoOrientationDiagnostics(
                selectedRotation: accurateSelection.rotation,
                evidencePhase: hasAllAccurateCandidates ? .accurate : .fast,
                candidates: hasAllAccurateCandidates
                    ? accurateSelection.candidateDiagnostics
                    : fastSelection.candidateDiagnostics
            )
            Self.debugLog(candidates: accurateCandidates, phase: "accurate")
            Self.debugLog(selection: accurateSelection)
            return CalendarVisionOCRResult(
                rotation: accurateSelection.rotation,
                observations: accurateSelection.observations,
                accurateCandidates: accurateCandidates,
                orientationDiagnostics: orientationDiagnostics,
                grid: nil
            )
        }.value
    }

    private static func detectMainGrid(
        image: CGImage,
        expectedRows: Int
    ) throws -> CalendarPhotoGridGeometry? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 24
        request.minimumConfidence = 0.45
        request.minimumAspectRatio = 0.25
        request.maximumAspectRatio = 1
        request.minimumSize = 0.08
        request.quadratureTolerance = 25
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        let rectangles: [VNRectangleObservation] = request.results ?? []
        let candidates: [CalendarPhotoGridCandidate] = rectangles.map { rectangle in
            let boundingBox: CGRect = rectangle.boundingBox
            return CalendarPhotoGridCandidate(
                boundingBox: CalendarOCRBoundingBox(
                    x: Double(boundingBox.minX),
                    y: Double(boundingBox.minY),
                    width: Double(boundingBox.width),
                    height: Double(boundingBox.height)
                ),
                structuralConfidence: Double(rectangle.confidence)
            )
        }
        return CalendarPhotoGridSelector().selectMainGrid(
            from: candidates,
            expectedRows: expectedRows
        )
    }

    private static func recognizeSynchronously(
        image: CGImage,
        preferredLanguageCode: String,
        recognitionLevel: VNRequestTextRecognitionLevel
    ) throws -> [CalendarOCRObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let supportedLanguages = (try? request.supportedRecognitionLanguages()) ?? []
        let recognitionLanguages = preferredRecognitionLanguages(
            supported: supportedLanguages,
            preferredLanguageCode: preferredLanguageCode
        )
        if !recognitionLanguages.isEmpty {
            request.recognitionLanguages = recognitionLanguages
        }

        let handler = VNImageRequestHandler(
            cgImage: image,
            orientation: .up,
            options: [:]
        )
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return CalendarOCRObservation(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: CalendarOCRBoundingBox(
                    x: Double(box.origin.x),
                    y: Double(box.origin.y),
                    width: Double(box.size.width),
                    height: Double(box.size.height)
                )
            )
        }
    }

    private static func preferredRecognitionLanguages(
        supported: [String],
        preferredLanguageCode: String
    ) -> [String] {
        let desired: [String]
        switch preferredLanguageCode.lowercased() {
        case let code where code.contains("hant") || code.contains("tw") || code.contains("hk"):
            desired = ["zh-Hant", "ja", "zh-Hans", "en", "ko"]
        case let code where code.contains("hans") || code.contains("cn") || code.contains("sg"):
            desired = ["zh-Hans", "ja", "zh-Hant", "en", "ko"]
        case let code where code.hasPrefix("en"):
            desired = ["en", "ja", "zh-Hans", "zh-Hant", "ko"]
        case let code where code.hasPrefix("ko"):
            desired = ["ko", "ja", "zh-Hans", "zh-Hant", "en"]
        default:
            desired = ["ja", "zh-Hans", "zh-Hant", "en", "ko"]
        }

        var selected: [String] = []
        for language in desired {
            guard let supportedLanguage = supported.first(where: {
                languageMatches($0, desired: language)
            }), !selected.contains(supportedLanguage) else {
                continue
            }
            selected.append(supportedLanguage)
        }
        return selected
    }

    private static func languageMatches(_ supported: String, desired: String) -> Bool {
        let value = supported.lowercased().replacingOccurrences(of: "_", with: "-")
        switch desired {
        case "zh-Hans":
            return value.contains("hans") || value == "zh-cn" || value == "zh-sg"
        case "zh-Hant":
            return value.contains("hant") || value == "zh-tw" || value == "zh-hk"
        default:
            return value == desired.lowercased()
                || value.hasPrefix(desired.lowercased() + "-")
        }
    }

    private static func debugLog(
        candidates: [CalendarPhotoOrientationCandidate],
        phase: String
    ) {
        #if DEBUG
        let selector = CalendarPhotoOrientationSelector()
        for candidate in candidates {
            guard let selection = selector.selectBest(from: [candidate]) else { continue }
            let evidence = selection.evidence
            print(
                "[CalendarImport] phase=\(phase) orientation=\(candidate.rotation.rawValue) "
                    + "score=\(evidence.score) yearMonth=\(evidence.yearMonth != nil) "
                    + "dateAnchors=\(evidence.dateAnchorCount) "
                    + "matched=\(evidence.matchedDateAnchorCount) "
                    + "grid=\(evidence.columnCount)x\(evidence.rowCount)"
            )
        }
        #endif
    }

    private static func debugLog(selection: CalendarPhotoOrientationSelection) {
        #if DEBUG
        print("[CalendarImport] selected=\(selection.rotation.rawValue)")
        if let yearMonth = selection.evidence.yearMonth {
            let month = yearMonth.month < 10 ? "0\(yearMonth.month)" : "\(yearMonth.month)"
            print("[CalendarImport] yearMonth=\(yearMonth.year)-\(month)")
        } else {
            print("[CalendarImport] yearMonth=unknown")
        }
        print(
            "[CalendarImport] dateAnchors=\(selection.evidence.dateAnchorCount) "
                + "matched=\(selection.evidence.matchedDateAnchorCount)"
        )
        #endif
    }
}

@MainActor
private final class CalendarPhotoImportViewModel: ObservableObject {
    @Published private(set) var step: CalendarPhotoImportStep = .source
    @Published var candidates: [CalendarImportCandidate] = []
    @Published private(set) var recognizedYearMonth: CalendarImportYearMonth?
    @Published private(set) var latestDiagnostics: CalendarPhotoImportDiagnostics?
    @Published var monthSelection: Date
    @Published var daySelection: Date
    @Published var scanMode: CalendarPhotoScanMode = .month
    @Published var weekStart: CalendarPhotoImportWeekStart
    @Published private(set) var isSaving = false
    @Published var failureMessage: String?

    private let eventUseCase: EventUseCase
    private let sharingStore: CalendarSharingStore
    private let parser = CalendarPhotoParser()
    private let ocrService = CalendarVisionOCRService()
    private var observations: [CalendarOCRObservation] = []
    private var accurateOrientationCandidates: [CalendarPhotoOrientationCandidate] = []
    private var orientationDiagnostics: CalendarPhotoOrientationDiagnostics?

    init(
        eventUseCase: EventUseCase,
        sharingStore: CalendarSharingStore,
        initialDate: Date
    ) {
        self.eventUseCase = eventUseCase
        self.sharingStore = sharingStore
        self.monthSelection = initialDate
        self.daySelection = initialDate
        self.weekStart = Calendar.current.firstWeekday == 2 ? .monday : .sunday
    }

    var availableCalendars: [TimeNestCalendar] {
        sharingStore.eventWritableCalendars
    }

    var selectedCandidateCount: Int {
        candidates.filter(\.isSelected).count
    }

    var commonTargetCalendarID: UUID? {
        candidates.first?.targetCalendarID
    }

    var canSave: Bool {
        let writableIDs = Set(availableCalendars.map(\.id))
        let selected = candidates.filter(\.isSelected)
        return !selected.isEmpty
            && selected.allSatisfy {
                $0.isValidForSaving && writableIDs.contains($0.targetCalendarID)
            }
            && !isSaving
    }

    var visibleDiagnostics: CalendarPhotoImportDiagnostics? {
        guard let latestDiagnostics, latestDiagnostics.shouldDisplay else { return nil }
        return latestDiagnostics
    }

    func process(image: UIImage, languageCode: String) async {
        step = .recognizing
        failureMessage = nil
        latestDiagnostics = nil
        do {
            let normalizedImage = try CalendarPhotoImportImageNormalizer
                .normalizedCGImage(from: image)
            let yearMonth = selectedYearMonth
            let expectedRows: Int?
            switch scanMode {
            case .month:
                guard let yearMonth else { throw CalendarPhotoImportParseError.missingYearMonth }
                expectedRows = CalendarPhotoGridFirstParser().expectedRows(
                    yearMonth: yearMonth,
                    weekStart: weekStart
                )
            case .day:
                expectedRows = nil
            }
            let recognized = try await ocrService.recognize(
                image: normalizedImage,
                preferredLanguageCode: languageCode,
                expectedGridRows: expectedRows
            )
            observations = recognized.observations
            accurateOrientationCandidates = recognized.accurateCandidates
            orientationDiagnostics = recognized.orientationDiagnostics
            guard let defaultCalendarID else {
                throw CalendarPhotoImportImageError.noWritableCalendar
            }
            switch scanMode {
            case .month:
                guard let yearMonth, let grid = recognized.grid else {
                    throw CalendarPhotoImportParseError.noDateStructure
                }
                let result = try CalendarPhotoGridFirstParser().parseMonth(
                    observations: observations,
                    yearMonth: yearMonth,
                    weekStart: weekStart,
                    grid: grid,
                    defaultCalendarID: defaultCalendarID
                )
                recognizedYearMonth = result.yearMonth
                candidates = result.candidates
            case .day:
                let result = try CalendarPhotoDayParser().parse(
                    observations: observations,
                    selectedDate: daySelection,
                    defaultCalendarID: defaultCalendarID
                )
                recognizedYearMonth = result.yearMonth
                candidates = result.candidates
            }
            step = .review
        } catch {
            step = latestDiagnostics == nil ? .source : .review
            failureMessage = localizedMessage(for: error)
        }
    }

    private var selectedYearMonth: CalendarImportYearMonth? {
        let components = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month], from: monthSelection)
        guard let year = components.year, let month = components.month else { return nil }
        return CalendarImportYearMonth(year: year, month: month)
    }

    func applySelectedYearMonth() {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: monthSelection)
        guard let year = components.year,
              let month = components.month,
              let yearMonth = CalendarImportYearMonth(year: year, month: month) else {
            failureMessage = LocalizationManager.shared.localized(
                .calendarPhotoImportInvalidCandidate
            )
            return
        }
        do {
            if let selection = CalendarPhotoOrientationSelector().selectBest(
                from: accurateOrientationCandidates,
                overridingYearMonth: yearMonth
            ) {
                observations = selection.observations
                orientationDiagnostics = CalendarPhotoOrientationDiagnostics(
                    selectedRotation: selection.rotation,
                    evidencePhase: .accurate,
                    candidates: selection.candidateDiagnostics
                )
            }
            try applyParse(overridingYearMonth: yearMonth)
        } catch {
            failureMessage = localizedMessage(for: error)
        }
    }

    func deleteCandidate(id: UUID) {
        candidates.removeAll { $0.id == id }
    }

    func setTargetCalendarID(_ calendarID: UUID) {
        candidates = candidates.map { candidate in
            var updated = candidate
            updated.targetCalendarID = calendarID
            return updated
        }
    }

    func startOver() {
        observations = []
        accurateOrientationCandidates = []
        orientationDiagnostics = nil
        candidates = []
        recognizedYearMonth = nil
        latestDiagnostics = nil
        failureMessage = nil
        step = .source
    }

    func saveSelected() async -> Bool {
        guard canSave else {
            failureMessage = LocalizationManager.shared.localized(
                .calendarPhotoImportInvalidCandidate
            )
            return false
        }
        isSaving = true
        defer { isSaving = false }

        let selected = candidates.filter(\.isSelected)
        let calendarsByID = Dictionary(
            uniqueKeysWithValues: availableCalendars.map { ($0.id, $0) }
        )
        var acceptedIDs = Set<UUID>()
        var syncedCount = 0
        var pendingCount = 0
        var failedCount = 0

        let localCandidates = selected.filter {
            calendarsByID[$0.targetCalendarID]?.kind != .sharedReceived
        }
        do {
            let events = try localCandidates.map(makeEvent)
            if !events.isEmpty {
                try await eventUseCase.createEventsAtomically(events)
                acceptedIDs.formUnion(localCandidates.map(\.id))
                syncedCount += localCandidates.count
            }
        } catch {
            failedCount += localCandidates.count
        }

        for candidate in selected where calendarsByID[candidate.targetCalendarID]?.kind == .sharedReceived {
            do {
                let event = try makeEvent(candidate)
                let snapshot = SharedEventSnapshot(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    updatedAt: event.updatedAt
                )
                let status = try await sharingStore.createReceivedSharedEvent(
                    snapshot,
                    calendarID: candidate.targetCalendarID
                )
                switch status {
                case .synced:
                    acceptedIDs.insert(candidate.id)
                    syncedCount += 1
                case .saving, .pending:
                    acceptedIDs.insert(candidate.id)
                    pendingCount += 1
                case .failed, .permissionRevoked, .deletedRemotely:
                    failedCount += 1
                }
            } catch {
                failedCount += 1
            }
        }

        if failedCount == 0, pendingCount == 0 {
            return true
        }

        candidates.removeAll { acceptedIDs.contains($0.id) }
        if pendingCount > 0, failedCount > 0 {
            failureMessage = String(
                format: LocalizationManager.shared.localized(
                    .calendarPhotoImportSaveMixedFormat
                ),
                locale: LocalizationManager.shared.currentLocale,
                syncedCount,
                pendingCount,
                failedCount
            )
        } else if pendingCount > 0 {
            failureMessage = String(
                format: LocalizationManager.shared.localized(
                    .calendarPhotoImportSavePendingFormat
                ),
                locale: LocalizationManager.shared.currentLocale,
                syncedCount,
                pendingCount
            )
        } else {
            failureMessage = String(
                format: LocalizationManager.shared.localized(
                    .calendarPhotoImportSavePartialFormat
                ),
                locale: LocalizationManager.shared.currentLocale,
                syncedCount,
                failedCount
            )
        }
        return false
    }

    private func applyParse(
        overridingYearMonth: CalendarImportYearMonth?
    ) throws {
        guard let defaultCalendarID = defaultCalendarID else {
            throw CalendarPhotoImportImageError.noWritableCalendar
        }
        failureMessage = nil
        candidates = []
        recognizedYearMonth = overridingYearMonth
        if let date = overridingYearMonth?.date() {
            monthSelection = date
        }
        let result = try parser.parse(
            observations: observations,
            overridingYearMonth: overridingYearMonth,
            defaultCalendarID: defaultCalendarID,
            orientationDiagnostics: orientationDiagnostics,
            diagnosticsHandler: { [weak self] diagnostics in
                self?.recordDiagnostics(diagnostics)
            }
        )
        recognizedYearMonth = result.yearMonth
        candidates = result.candidates
        if let date = result.yearMonth?.date() {
            monthSelection = date
        }
    }

    private func recordDiagnostics(_ diagnostics: CalendarPhotoImportDiagnostics) {
        latestDiagnostics = diagnostics
        recognizedYearMonth = diagnostics.resolvedYearMonth
        if let date = diagnostics.resolvedYearMonth?.date() {
            monthSelection = date
        }
        Self.debugLog(diagnostics)
    }

    private static func debugLog(_ diagnostics: CalendarPhotoImportDiagnostics) {
        #if DEBUG
        func value(_ yearMonth: CalendarImportYearMonth?) -> String {
            guard let yearMonth else { return "none" }
            return String(format: "%04d-%02d", yearMonth.year, yearMonth.month)
        }
        print(
            "[CalendarImport] manualYearMonth=\(value(diagnostics.manualYearMonth)) "
                + "resolvedYearMonth=\(value(diagnostics.resolvedYearMonth)) "
                + "ocrObservations=\(diagnostics.observationCount) "
                + "meaningful=\(diagnostics.meaningfulObservationCount) "
                + "pureNumeric=\(diagnostics.pureNumericObservationCount) "
                + "dateAnchors=\(diagnostics.dateAnchorCount) "
                + "distinctDays=\(diagnostics.distinctDayCount) "
                + "sundayScore=\(diagnostics.sundayStartScore) "
                + "mondayScore=\(diagnostics.mondayStartScore) "
                + "weekStart=\(diagnostics.selectedWeekStart?.rawValue ?? "none") "
                + "grid=\(diagnostics.gridColumnCount)x\(diagnostics.gridRowCount) "
                + "matched=\(diagnostics.gridMatchedAnchorCount) "
                + "rejected=\(diagnostics.gridRejectedAnchorCount) "
                + "threshold=\(diagnostics.gridAcceptanceThreshold) "
                + "gridAccepted=\(diagnostics.gridAccepted) "
                + "dayRegions=\(diagnostics.dayRegionCount) "
                + "candidates=\(diagnostics.candidateCount) "
                + "stage=\(diagnostics.parseStage.rawValue) "
                + "failure=\(diagnostics.failureReason.map(String.init(describing:)) ?? "none")"
        )
        #endif
    }

    private var defaultCalendarID: UUID? {
        let calendars = availableCalendars
        if calendars.contains(where: { $0.id == sharingStore.selection.calendarID }) {
            return sharingStore.selection.calendarID
        }
        return calendars.first?.id
    }

    private func makeEvent(_ candidate: CalendarImportCandidate) throws -> CalendarEvent {
        guard candidate.isValidForSaving else {
            throw EventUseCaseError.invalidDateRange
        }
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: candidate.date)
        let startDate: Date
        let endDate: Date
        let isAllDay: Bool
        if let startMinutes = candidate.startTimeMinutes,
           let endMinutes = candidate.endTimeMinutes {
            guard let start = calendar.date(
                byAdding: .minute,
                value: startMinutes,
                to: dayStart
            ), let end = calendar.date(
                byAdding: .minute,
                value: endMinutes,
                to: dayStart
            ), end > start else {
                throw EventUseCaseError.invalidDateRange
            }
            startDate = start
            endDate = end
            isAllDay = false
        } else {
            guard candidate.startTimeMinutes == nil,
                  candidate.endTimeMinutes == nil,
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                throw EventUseCaseError.invalidDateRange
            }
            startDate = dayStart
            endDate = nextDay
            isAllDay = true
        }
        let now = Date()
        return CalendarEvent(
            id: candidate.id,
            calendarID: candidate.targetCalendarID,
            title: candidate.effectiveTitle,
            note: nil,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            categoryID: nil,
            recurrenceRule: .none,
            reminderTemplateID: nil,
            reminderOffsetMinutes: nil,
            notificationID: nil,
            importSource: nil,
            createdAt: now,
            updatedAt: now,
            shiftTemplateID: nil,
            workInfo: nil
        )
    }

    private func localizedMessage(for error: Error) -> String {
        switch error {
        case CalendarPhotoImportParseError.missingYearMonth:
            return LocalizationManager.shared.localized(.calendarPhotoImportYearMonthRequired)
        case CalendarPhotoImportParseError.noText:
            return LocalizationManager.shared.localized(.calendarPhotoImportNoText)
        case CalendarPhotoImportParseError.noDateStructure:
            return LocalizationManager.shared.localized(.calendarPhotoImportNoDateStructure)
        case CalendarPhotoImportParseError.noCandidates:
            return LocalizationManager.shared.localized(.calendarPhotoImportNoCandidates)
        case CalendarPhotoImportImageError.invalidImage:
            return LocalizationManager.shared.localized(.calendarPhotoImportPhotoLoadFailed)
        case CalendarPhotoImportImageError.noWritableCalendar:
            return LocalizationManager.shared.localized(.calendarPhotoImportNoWritableCalendar)
        default:
            return LocalizationManager.shared.localized(.calendarPhotoImportOCRFailed)
        }
    }
}

private enum CalendarPhotoImportResultLayout {
    static let selectionColumnWidth: CGFloat = 28
    static let dateColumnWidth: CGFloat = 46
    static let timeColumnWidth: CGFloat = 92
    static let columnSpacing: CGFloat = 8
}

struct CalendarPhotoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var viewModel: CalendarPhotoImportViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingCameraPermissionAlert = false
    @State private var diagnosticsCopied = false
    let onCompleted: () -> Void

    init(
        eventUseCase: EventUseCase,
        sharingStore: CalendarSharingStore,
        initialDate: Date,
        onCompleted: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: CalendarPhotoImportViewModel(
            eventUseCase: eventUseCase,
            sharingStore: sharingStore,
            initialDate: initialDate
        ))
        self.onCompleted = onCompleted
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .source:
                    sourceView
                case .recognizing:
                    recognizingView
                case .review:
                    reviewView
                }
            }
            .navigationTitle(localization.localized(.calendarPhotoImportTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.cancel)) { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                if viewModel.step == .review {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(localization.localized(.calendarPhotoImportRetry)) {
                            viewModel.startOver()
                        }
                        .disabled(viewModel.isSaving)
                    }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving || viewModel.step == .recognizing)
        .fullScreenCover(isPresented: $showingCamera) {
            CalendarCameraPicker(
                onImage: { image in
                    showingCamera = false
                    Task {
                        await viewModel.process(
                            image: image,
                            languageCode: localization.currentLanguageCode
                        )
                    }
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .alert(
            localization.localized(.calendarPhotoImportErrorTitle),
            isPresented: Binding(
                get: {
                    viewModel.failureMessage != nil
                        && viewModel.visibleDiagnostics == nil
                },
                set: { if !$0 { viewModel.failureMessage = nil } }
            )
        ) {
            Button(localization.localized(.ok)) {
                viewModel.failureMessage = nil
            }
        } message: {
            Text(viewModel.failureMessage ?? "")
        }
        .alert(
            localization.localized(.calendarPhotoImportCameraPermissionDenied),
            isPresented: $showingCameraPermissionAlert
        ) {
            Button(localization.localized(.cancel), role: .cancel) {}
            Button(localization.localized(.calendarPhotoImportOpenSettings)) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        } message: {
            Text(localization.localized(.calendarPhotoImportCameraPermissionMessage))
        }
        .onChange(of: viewModel.latestDiagnostics) { _, _ in
            diagnosticsCopied = false
        }
    }

    private var sourceView: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    Picker(
                        localization.localized(.calendarPhotoImportScanMode),
                        selection: $viewModel.scanMode
                    ) {
                        Text(localization.localized(.calendarPhotoImportMonthScan))
                            .tag(CalendarPhotoScanMode.month)
                        Text(localization.localized(.calendarPhotoImportDayScan))
                            .tag(CalendarPhotoScanMode.day)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("calendarPhotoImport.scanMode")

                    if viewModel.scanMode == .month {
                        LabeledContent(localization.localized(.calendarPhotoImportSelectYearMonth)) {
                            HStack(spacing: 8) {
                                Picker(
                                    localization.localized(.yearLabel),
                                    selection: yearSelectionBinding
                                ) {
                                    ForEach(1900...2200, id: \.self) {
                                        Text(verbatim: "\($0)").tag($0)
                                    }
                                }
                                Picker(
                                    localization.localized(.monthLabel),
                                    selection: monthSelectionBinding
                                ) {
                                    ForEach(1...12, id: \.self) {
                                        Text(verbatim: "\($0)").tag($0)
                                    }
                                }
                            }
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(localization.localized(.calendarPhotoImportWeekStart))
                                .font(.subheadline.weight(.semibold))

                            Picker(
                                localization.localized(.calendarPhotoImportWeekStart),
                                selection: $viewModel.weekStart
                            ) {
                                Text(localization.localized(.calendarPhotoImportSundayFirst))
                                    .tag(CalendarPhotoImportWeekStart.sunday)
                                Text(localization.localized(.calendarPhotoImportMondayFirst))
                                    .tag(CalendarPhotoImportWeekStart.monday)
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("calendarPhotoImport.weekStart")

                            Text(localization.localized(.calendarPhotoImportWeekStartHelp))
                                .font(.footnote)
                                .foregroundStyle(SettingsModalSurface.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        DatePicker(
                            localization.localized(.calendarPhotoImportSelectDate),
                            selection: $viewModel.daySelection,
                            displayedComponents: .date
                        )
                    }

                    Spacer()
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundColor(ShiftCalendarColors.primaryBlue)
                        .accessibilityHidden(true)

                    Text(localization.localized(.calendarPhotoImportSourceMessage))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: openCamera) {
                        Label(
                            localization.localized(.calendarPhotoImportCamera),
                            systemImage: "camera"
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.availableCalendars.isEmpty)
                    .accessibilityIdentifier("calendarPhotoImport.camera")

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(
                            localization.localized(.calendarPhotoImportPhotos),
                            systemImage: "photo.on.rectangle"
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.availableCalendars.isEmpty)
                    .accessibilityIdentifier("calendarPhotoImport.photos")

                    if viewModel.availableCalendars.isEmpty {
                        Text(localization.localized(.calendarPhotoImportNoWritableCalendar))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, SettingsModalSurface.horizontalPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(SettingsModalSurface.background)
    }

    private var recognizingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(localization.localized(.calendarPhotoImportRecognizing))
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsModalSurface.background)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("calendarPhotoImport.recognizing")
    }

    private var reviewView: some View {
        Form {
            Section(localization.localized(.calendarPhotoImportResults)) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if viewModel.scanMode == .month,
                       let yearMonth = viewModel.recognizedYearMonth,
                       let date = yearMonth.date() {
                        Text(monthText(date))
                            .font(.headline)
                    } else if viewModel.scanMode == .day {
                        Text(candidateHeader(viewModel.daySelection))
                            .font(.headline)
                    } else {
                        Label(
                            localization.localized(.calendarPhotoImportYearMonthRequired),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                    }

                    Spacer(minLength: 8)

                    Text(candidateCountText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !viewModel.candidates.isEmpty {
                    Picker(
                        localization.localized(.calendarPhotoImportTargetCalendar),
                        selection: commonTargetCalendarBinding
                    ) {
                        ForEach(viewModel.availableCalendars) { calendar in
                            Text(calendar.name).tag(Optional(calendar.id))
                        }
                    }
                    .accessibilityIdentifier("calendarPhotoImport.targetCalendar")
                }

                if let failureMessage = viewModel.failureMessage,
                   viewModel.visibleDiagnostics != nil {
                    Label(failureMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            if let diagnostics = viewModel.visibleDiagnostics {
                diagnosticsSection(diagnostics)
            }

            if !viewModel.candidates.isEmpty {
                Section {
                    ForEach($viewModel.candidates) { $candidate in
                        candidateRow(candidate: $candidate)
                    }
                } header: {
                    candidateTableHeader
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: save) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(addButtonTitle)
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 50)
            .background(
                viewModel.canSave
                    ? ShiftCalendarColors.primaryBlue
                    : Color.secondary.opacity(0.35)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(
                cornerRadius: TimeNestTheme.controlCornerRadius,
                style: .continuous
            ))
            .disabled(!viewModel.canSave)
            .padding(.horizontal, SettingsModalSurface.horizontalPadding)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .accessibilityIdentifier("calendarPhotoImport.save")
        }
    }

    @ViewBuilder
    private func diagnosticsSection(_ diagnostics: CalendarPhotoImportDiagnostics) -> some View {
        Section {
            DisclosureGroup(localization.localized(.calendarPhotoImportDiagnostics)) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(diagnostics.displayFields.enumerated()), id: \.offset) { _, field in
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: field.label)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 16)
                            Text(verbatim: field.value)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.caption.monospaced())
                    }

                    Button {
                        UIPasteboard.general.string = diagnostics.plainText
                        diagnosticsCopied = true
                    } label: {
                        Label(
                            localization.localized(.calendarPhotoImportCopyDiagnostics),
                            systemImage: "doc.on.doc"
                        )
                    }
                    .padding(.top, 4)
                    .accessibilityIdentifier("calendarPhotoImport.copyDiagnostics")

                    if diagnosticsCopied {
                        Label(
                            localization.localized(.calendarPhotoImportDiagnosticsCopied),
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("calendarPhotoImport.diagnostics")
        }
    }

    @ViewBuilder
    private var candidateTableHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: CalendarPhotoImportResultLayout.columnSpacing) {
                Color.clear
                    .frame(width: CalendarPhotoImportResultLayout.selectionColumnWidth)
                Text(
                    [
                        localization.localized(.calendarPhotoImportDate),
                        localization.localized(.calendarPhotoImportTime),
                        localization.localized(.calendarPhotoImportSchedule)
                    ].joined(separator: " · ")
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(spacing: CalendarPhotoImportResultLayout.columnSpacing) {
                Color.clear
                    .frame(width: CalendarPhotoImportResultLayout.selectionColumnWidth)
                Text(localization.localized(.calendarPhotoImportDate))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(
                        width: CalendarPhotoImportResultLayout.dateColumnWidth,
                        alignment: .leading
                    )
                Text(localization.localized(.calendarPhotoImportTime))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(
                        width: CalendarPhotoImportResultLayout.timeColumnWidth,
                        alignment: .leading
                    )
                Text(localization.localized(.calendarPhotoImportSchedule))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func candidateRow(
        candidate: Binding<CalendarImportCandidate>
    ) -> some View {
        HStack(spacing: CalendarPhotoImportResultLayout.columnSpacing) {
            Button {
                candidate.wrappedValue.isSelected.toggle()
            } label: {
                Image(
                    systemName: candidate.wrappedValue.isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    candidate.wrappedValue.isSelected
                        ? ShiftCalendarColors.primaryBlue
                        : SettingsModalSurface.secondaryText
                )
                .frame(width: CalendarPhotoImportResultLayout.selectionColumnWidth)
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localization.localized(.calendarPhotoImportSelected))
            .accessibilityAddTraits(
                candidate.wrappedValue.isSelected ? .isSelected : []
            )

            NavigationLink {
                candidateDetailView(candidate: candidate)
            } label: {
                candidateRowContent(candidate.wrappedValue)
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteCandidate(id: candidate.wrappedValue.id)
            } label: {
                Label(
                    localization.localized(.calendarPhotoImportDeleteCandidate),
                    systemImage: "trash"
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func candidateRowContent(_ candidate: CalendarImportCandidate) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(candidateDateText(candidate.date))
                    Text(candidateTimeText(candidate))
                        .monospacedDigit()
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    candidateReviewIndicator(candidate)
                }
                .font(.subheadline)

                Text(candidate.effectiveTitle)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(
                candidate.isSelected
                    ? SettingsModalSurface.primaryText
                    : SettingsModalSurface.secondaryText
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: CalendarPhotoImportResultLayout.columnSpacing) {
                Text(candidateDateText(candidate.date))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(
                        width: CalendarPhotoImportResultLayout.dateColumnWidth,
                        alignment: .leading
                    )
                Text(candidateTimeText(candidate))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(
                        width: CalendarPhotoImportResultLayout.timeColumnWidth,
                        alignment: .leading
                    )
                Text(candidate.effectiveTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                candidateReviewIndicator(candidate)
            }
            .font(.subheadline)
            .foregroundStyle(
                candidate.isSelected
                    ? SettingsModalSurface.primaryText
                    : SettingsModalSurface.secondaryText
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func candidateReviewIndicator(_ candidate: CalendarImportCandidate) -> some View {
        if candidate.needsReview || !candidate.isValidForSaving {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel(localization.localized(.calendarPhotoImportNeedsReview))
        }
    }

    private func candidateDetailView(
        candidate: Binding<CalendarImportCandidate>
    ) -> some View {
        Form {
            Section {
                Toggle(
                    localization.localized(.calendarPhotoImportSelected),
                    isOn: candidate.isSelected
                )

                TextField(
                    localization.localized(.editorTitle),
                    text: candidate.title,
                    axis: .vertical
                )
                .textInputAutocapitalization(.sentences)

                DatePicker(
                    localization.localized(.calendarPhotoImportDate),
                    selection: candidate.date,
                    displayedComponents: .date
                )

                if candidate.wrappedValue.startTimeMinutes != nil {
                    DatePicker(
                        localization.localized(.calendarPhotoImportStartTime),
                        selection: timeBinding(
                            minutes: candidate.startTimeMinutes,
                            date: candidate.wrappedValue.date
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    if candidate.wrappedValue.endTimeMinutes != nil {
                        DatePicker(
                            localization.localized(.calendarPhotoImportEndTime),
                            selection: timeBinding(
                                minutes: candidate.endTimeMinutes,
                                date: candidate.wrappedValue.date
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    } else {
                        Button(localization.localized(.calendarPhotoImportAddEndTime)) {
                            let start = candidate.wrappedValue.startTimeMinutes ?? 9 * 60
                            candidate.wrappedValue.endTimeMinutes = min(
                                start + 60,
                                23 * 60 + 59
                            )
                        }
                        .foregroundStyle(.orange)
                    }
                    Button(localization.localized(.calendarPhotoImportMakeAllDay)) {
                        candidate.wrappedValue.startTimeMinutes = nil
                        candidate.wrappedValue.endTimeMinutes = nil
                    }
                } else {
                    LabeledContent(
                        localization.localized(.calendarPhotoImportTime),
                        value: localization.localized(.calendarPhotoImportAllDay)
                    )
                    Button(localization.localized(.calendarPhotoImportSetTime)) {
                        candidate.wrappedValue.startTimeMinutes = 9 * 60
                        candidate.wrappedValue.endTimeMinutes = nil
                        candidate.wrappedValue.needsReview = true
                    }
                }

                if let personToken = candidate.wrappedValue.personToken {
                    LabeledContent(
                        localization.localized(.calendarPhotoImportPersonToken),
                        value: personToken
                    )
                    Toggle(
                        localization.localized(.calendarPhotoImportIncludePersonInTitle),
                        isOn: candidate.includesPersonTokenInTitle
                    )
                }

                if candidate.wrappedValue.needsReview {
                    HStack {
                        Label(
                            localization.localized(.calendarPhotoImportNeedsReview),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                        Spacer()
                        Button(localization.localized(.calendarPhotoImportMarkReviewed)) {
                            candidate.wrappedValue.needsReview = false
                        }
                    }
                }

                if !candidate.wrappedValue.isValidForSaving {
                    Text(localization.localized(.calendarPhotoImportInvalidCandidate))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                DisclosureGroup(localization.localized(.calendarPhotoImportOriginalText)) {
                    Text(candidate.wrappedValue.originalText)
                        .textSelection(.enabled)
                    Text(confidenceText(candidate.wrappedValue.confidence))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(candidateHeader(candidate.wrappedValue.date))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var addButtonTitle: String {
        String(
            format: localization.localized(.calendarPhotoImportAddCountFormat),
            locale: localization.currentLocale,
            viewModel.selectedCandidateCount
        )
    }

    private var candidateCountText: String {
        String(
            format: localization.localized(.calendarPhotoImportCandidateCountFormat),
            locale: localization.currentLocale,
            viewModel.candidates.count
        )
    }

    private var commonTargetCalendarBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.commonTargetCalendarID },
            set: { calendarID in
                guard let calendarID else { return }
                viewModel.setTargetCalendarID(calendarID)
            }
        )
    }

    private var yearSelectionBinding: Binding<Int> {
        Binding(
            get: {
                Calendar(identifier: .gregorian).component(
                    .year,
                    from: viewModel.monthSelection
                )
            },
            set: { year in
                updateMonthSelection(year: year, month: monthSelectionBinding.wrappedValue)
            }
        )
    }

    private var monthSelectionBinding: Binding<Int> {
        Binding(
            get: {
                Calendar(identifier: .gregorian).component(
                    .month,
                    from: viewModel.monthSelection
                )
            },
            set: { month in
                updateMonthSelection(year: yearSelectionBinding.wrappedValue, month: month)
            }
        )
    }

    private func updateMonthSelection(year: Int, month: Int) {
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: 1
        )) else { return }
        viewModel.monthSelection = date
    }

    private func candidateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.currentLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("MMMEd")
        return formatter.string(from: date)
    }

    private func candidateDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.currentLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
    }

    private func candidateTimeText(_ candidate: CalendarImportCandidate) -> String {
        switch (candidate.startTimeMinutes, candidate.endTimeMinutes) {
        case (nil, nil):
            return localization.localized(.calendarPhotoImportAllDay)
        case let (start?, end?):
            return "\(timeText(start))–\(timeText(end))"
        case let (start?, nil):
            return "\(timeText(start))–"
        case let (nil, end?):
            return "–\(timeText(end))"
        }
    }

    private func timeText(_ minutes: Int) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        guard let date = calendar.date(byAdding: .minute, value: minutes, to: startOfDay) else {
            return ""
        }
        return localization.dateFormatter(dateFormat: "HH:mm").string(from: date)
    }

    private func monthText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.currentLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    private func confidenceText(_ confidence: Float) -> String {
        String(
            format: localization.localized(.calendarPhotoImportConfidenceFormat),
            locale: localization.currentLocale,
            Int((confidence * 100).rounded())
        )
    }

    private func timeBinding(minutes: Binding<Int?>, date: Date) -> Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar(identifier: .gregorian)
                return calendar.date(
                    byAdding: .minute,
                    value: minutes.wrappedValue ?? 0,
                    to: calendar.startOfDay(for: date)
                ) ?? date
            },
            set: { newValue in
                let calendar = Calendar(identifier: .gregorian)
                let components = calendar.dateComponents([.hour, .minute], from: newValue)
                minutes.wrappedValue = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            viewModel.failureMessage = localization.localized(
                .calendarPhotoImportCameraUnavailable
            )
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        showingCamera = true
                    } else {
                        showingCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingCameraPermissionAlert = true
        @unknown default:
            showingCameraPermissionAlert = true
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        defer { selectedPhoto = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw CalendarPhotoImportImageError.invalidImage
            }
            await viewModel.process(
                image: image,
                languageCode: localization.currentLanguageCode
            )
        } catch {
            viewModel.failureMessage = localization.localized(
                .calendarPhotoImportPhotoLoadFailed
            )
        }
    }

    private func save() {
        Task {
            if await viewModel.saveSelected() {
                onCompleted()
                dismiss()
            }
        }
    }
}

private struct CalendarCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }
            onImage(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
