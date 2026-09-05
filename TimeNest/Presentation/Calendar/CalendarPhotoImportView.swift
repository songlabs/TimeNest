import AVFoundation
import CoreImage
import PhotosUI
import SwiftUI
import UIKit
@preconcurrency import Vision

private enum CalendarPhotoImportImageError: Error {
    case invalidImage
    case noWritableCalendar
    case perspectiveCorrectionFailed
}

enum CalendarPhotoGridRectifier {
    static func correct(
        image: CGImage,
        grid: CalendarPhotoGridGeometry
    ) throws -> (image: CGImage, geometry: CalendarPhotoGridGeometry) {
        guard let topLeft = grid.topLeft,
              let topRight = grid.topRight,
              let bottomLeft = grid.bottomLeft,
              let bottomRight = grid.bottomRight else {
            throw CalendarPhotoImportImageError.perspectiveCorrectionFailed
        }
        let width = Double(image.width)
        let height = Double(image.height)
        func ciPoint(_ point: CalendarPhotoGridPoint) -> CIVector {
            CIVector(x: point.x * width, y: point.y * height)
        }
        let filter = CIFilter(name: "CIPerspectiveCorrection")
        filter?.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        filter?.setValue(ciPoint(topLeft), forKey: "inputTopLeft")
        filter?.setValue(ciPoint(topRight), forKey: "inputTopRight")
        filter?.setValue(ciPoint(bottomLeft), forKey: "inputBottomLeft")
        filter?.setValue(ciPoint(bottomRight), forKey: "inputBottomRight")
        guard let output = filter?.outputImage,
              !output.extent.isEmpty,
              !output.extent.isInfinite,
              let corrected = CIContext(options: [.cacheIntermediates: false]).createCGImage(
                output,
                from: output.extent.integral
              ) else {
            throw CalendarPhotoImportImageError.perspectiveCorrectionFailed
        }
        return (corrected, CalendarPhotoGridGeometry(
            boundingBox: CalendarOCRBoundingBox(x: 0, y: 0, width: 1, height: 1),
            columns: grid.columns,
            rows: grid.rows,
            topLeft: topLeft,
            topRight: topRight,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight,
            originalImagePixels: CalendarPhotoPixelSizeDiagnostics(
                width: image.width,
                height: image.height
            ),
            rectifiedGridPixels: CalendarPhotoPixelSizeDiagnostics(
                width: corrected.width,
                height: corrected.height
            )
        ))
    }
}

enum CalendarPhotoImportStep {
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

    static func upscaledCGImage(_ image: CGImage, factor: Int) throws -> CGImage {
        guard factor > 1,
              let context = bitmapContext(
                width: image.width * factor,
                height: image.height * factor
              ) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(
            x: 0, y: 0,
            width: image.width * factor,
            height: image.height * factor
        ))
        guard let result = context.makeImage() else {
            throw CalendarPhotoImportImageError.invalidImage
        }
        return result
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
        ocrLanguage: CalendarOCRLanguage,
        expectedGridRows: Int?
    ) async throws -> CalendarVisionOCRResult {
        try await Task.detached(priority: .userInitiated) {
            let grid: CalendarPhotoGridGeometry?
            if let expectedGridRows {
                grid = try Self.detectMainGrid(image: image, expectedRows: expectedGridRows)
            } else {
                grid = nil
            }
            let observations: [CalendarOCRObservation]
            if expectedGridRows == nil {
                observations = try Self.recognizeSynchronously(
                    image: image,
                    ocrLanguage: ocrLanguage,
                    recognitionLevel: .accurate
                )
            } else {
                observations = []
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

    func recognizeMonthCells(
        image: CGImage,
        regions: [CalendarImportDayRegion],
        ocrLanguage: CalendarOCRLanguage
    ) async throws -> [CalendarOCRObservation] {
        try await Task.detached(priority: .userInitiated) {
            var output: [CalendarOCRObservation] = []
            for region in regions {
                try Task.checkCancellation()
                do {
                    let pixelRect = Self.pixelRect(for: region.boundingBox, image: image)
                    guard pixelRect.width >= 2, pixelRect.height >= 2,
                          let crop = image.cropping(to: pixelRect) else { continue }
                    let minimumOCRDimension = 700
                    let factor = min(3, max(1, Int(ceil(
                        Double(minimumOCRDimension) / Double(min(crop.width, crop.height))
                    ))))
                    let ocrImage = factor > 1
                        ? try CalendarPhotoImportImageNormalizer.upscaledCGImage(crop, factor: factor)
                        : crop
                    let local = try Self.recognizeSynchronously(
                        image: ocrImage,
                        ocrLanguage: ocrLanguage,
                        recognitionLevel: .accurate,
                        preservesUnrecognizedText: true
                    )
                    output.append(contentsOf: local.map {
                        Self.map($0, from: region.boundingBox)
                    })
                    Self.debugLogCell(region: region, crop: crop, ocrImage: ocrImage)
                } catch is CancellationError {
                    throw CancellationError()
                } catch let error as CalendarOCRLanguageError {
                    throw error
                } catch {
                    #if DEBUG
                    print("[CalendarImport] Vision fallback failed for day=\(region.day)")
                    #endif
                }
            }
            return output
        }.value
    }

    func recognizeBestOrientation(
        image: CGImage,
        ocrLanguage: CalendarOCRLanguage
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
                    ocrLanguage: ocrLanguage,
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
                    ocrLanguage: ocrLanguage,
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
                        ocrLanguage: ocrLanguage,
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
                structuralConfidence: Double(rectangle.confidence),
                topLeft: point(rectangle.topLeft),
                topRight: point(rectangle.topRight),
                bottomLeft: point(rectangle.bottomLeft),
                bottomRight: point(rectangle.bottomRight)
            )
        }
        return CalendarPhotoGridSelector().selectMainGrid(
            from: candidates,
            expectedRows: expectedRows
        )
    }

    private static func point(_ point: CGPoint) -> CalendarPhotoGridPoint {
        CalendarPhotoGridPoint(x: Double(point.x), y: Double(point.y))
    }

    private static func pixelRect(
        for box: CalendarOCRBoundingBox,
        image: CGImage
    ) -> CGRect {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let minX = ceil(CGFloat(box.minX) * imageWidth)
        let maxX = floor(CGFloat(box.maxX) * imageWidth)
        let minY = ceil(CGFloat(1 - box.maxY) * imageHeight)
        let maxY = floor(CGFloat(1 - box.minY) * imageHeight)
        return CGRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        ).intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
    }

    private static func map(
        _ observation: CalendarOCRObservation,
        from cell: CalendarOCRBoundingBox
    ) -> CalendarOCRObservation {
        CalendarOCRObservation(
            text: observation.text,
            confidence: observation.confidence,
            boundingBox: CalendarOCRBoundingBox(
                x: cell.minX + observation.boundingBox.x * cell.width,
                y: cell.minY + observation.boundingBox.y * cell.height,
                width: observation.boundingBox.width * cell.width,
                height: observation.boundingBox.height * cell.height
            ),
            candidateDiagnostics: observation.candidateDiagnostics,
            selectionReason: observation.selectionReason,
            timeParseQualityOverride: observation.timeParseQualityOverride,
            rawTexts: observation.rawTexts,
            requiresReview: observation.requiresReview
        )
    }

    private static func debugLogCell(
        region: CalendarImportDayRegion,
        crop: CGImage,
        ocrImage: CGImage
    ) {
        #if DEBUG
        print(
            "[CalendarImport] ocrMode=perCell day=\(region.day) "
                + "cellPixels=\(crop.width)x\(crop.height) "
                + "ocrPixels=\(ocrImage.width)x\(ocrImage.height)"
        )
        #endif
    }

    private static func recognizeSynchronously(
        image: CGImage,
        ocrLanguage: CalendarOCRLanguage,
        recognitionLevel: VNRequestTextRecognitionLevel,
        preservesUnrecognizedText: Bool = false
    ) throws -> [CalendarOCRObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = false

        let supportedLanguages = (try? request.supportedRecognitionLanguages()) ?? []
        let recognitionLanguages = ocrLanguage.preferredVisionRecognitionLanguages(
            supported: supportedLanguages
        )
        guard !recognitionLanguages.isEmpty else {
            throw CalendarOCRLanguageError.unsupportedByVision(
                ocrLanguage.visionRecognitionLanguageCode
            )
        }
        request.recognitionLanguages = recognitionLanguages

        let handler = VNImageRequestHandler(
            cgImage: image,
            orientation: .up,
            options: [:]
        )
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            let alternatives = observation.topCandidates(5).enumerated().map { index, value in
                CalendarOCRCandidate(
                    text: value.string,
                    confidence: value.confidence,
                    source: .vision,
                    isPrimary: index == 0
                )
            }
            let unrecognized = preservesUnrecognizedText
                ? CalendarOCRCandidate(text: "", confidence: 0, source: .vision, isPrimary: true)
                : nil
            guard let candidate = CalendarOCRCandidateSelector.select(from: alternatives) ?? unrecognized else {
                return nil
            }
            let box = observation.boundingBox
            #if DEBUG
            for (index, alternative) in alternatives.enumerated() {
                print("[CalendarImport] OCR candidate[\(index)] text=\(alternative.text) confidence=\(alternative.confidence)")
            }
            if candidate != alternatives.first {
                print("[CalendarImport] OCR selectedBy=timeRange text=\(candidate.text)")
            }
            #endif
            return CalendarOCRObservation(
                text: candidate.text,
                confidence: candidate.confidence,
                boundingBox: CalendarOCRBoundingBox(
                    x: Double(box.origin.x),
                    y: Double(box.origin.y),
                    width: Double(box.size.width),
                    height: Double(box.size.height)
                ),
                candidateDiagnostics: alternatives,
                selectionReason: alternatives.isEmpty ? "unrecognizedTextRegion"
                    : candidate == alternatives.first ? nil : "validTimeRange",
                rawTexts: preservesUnrecognizedText ? alternatives.map(\.text) : [],
                requiresReview: preservesUnrecognizedText
                    && candidate.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
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
final class CalendarPhotoImportViewModel: ObservableObject {
    @Published private(set) var step: CalendarPhotoImportStep = .source
    @Published var draft: CalendarMonthInputDraft
    @Published private(set) var commonTargetCalendarID: UUID?
    @Published private(set) var submittedIDs: Set<UUID> = []
    @Published private(set) var recognizedYearMonth: CalendarImportYearMonth?
    @Published private(set) var latestDiagnostics: CalendarPhotoImportDiagnostics?
    @Published var monthSelection: Date
    @Published var daySelection: Date
    @Published var scanMode: CalendarPhotoScanMode = .month
    @Published var weekStart: CalendarPhotoImportWeekStart
    @Published private(set) var isSaving = false
    @Published private(set) var didSave = false
    @Published var failureMessage: String?

    private let eventUseCase: EventUseCase
    private let sharingStore: CalendarSharingStore
    private let ocrService = CalendarVisionOCRService()
    private let ppOCRService = PPOCRService()
    private var observations: [CalendarOCRObservation] = []
    private var accurateOrientationCandidates: [CalendarPhotoOrientationCandidate] = []
    private var orientationDiagnostics: CalendarPhotoOrientationDiagnostics?
    private var scanOCRLanguage: CalendarOCRLanguage?

    init(
        eventUseCase: EventUseCase,
        sharingStore: CalendarSharingStore,
        initialDate: Date
    ) {
        self.eventUseCase = eventUseCase
        self.sharingStore = sharingStore
        self.monthSelection = initialDate
        self.daySelection = initialDate
        let calendars = sharingStore.eventWritableCalendars
        let targetID = calendars.first(where: { $0.id == sharingStore.selection.calendarID })?.id
            ?? calendars.first?.id
        self.commonTargetCalendarID = targetID
        self.draft = CalendarMonthInputDraft(month: initialDate, calendarID: targetID ?? UUID())
        self.weekStart = Calendar.current.firstWeekday == 2 ? .monday : .sunday
    }

    var availableCalendars: [TimeNestCalendar] {
        sharingStore.eventWritableCalendars
    }

    var shiftTemplates: [ShiftTimeTemplate] { ShiftTimeTemplate.enabled() }

    var compatibleCalendars: [TimeNestCalendar] {
        let rows = step == .review ? draft.confirmationRows : draft.validRows
        let containsShift = rows.contains { $0.shiftTemplateID != nil }
        return availableCalendars.filter { !containsShift || $0.canEditContent }
    }

    var canSave: Bool {
        step == .review && !isSaving && !didSave && !draft.confirmationRows.isEmpty
            && draft.confirmationRows.allSatisfy {
                $0.isValidForSaving && $0.candidate.targetCalendarID == commonTargetCalendarID
            }
            && compatibleCalendars.contains { $0.id == commonTargetCalendarID }
    }

    func prepareConfirmation() {
        guard step == .source else { return }
        draft.prepareConfirmation()
        guard !draft.confirmationRows.isEmpty else { return }
        step = .review
    }

    func backToInput() {
        guard !isSaving else { return }
        step = .source
    }

    var visibleDiagnostics: CalendarPhotoImportDiagnostics? {
        guard let latestDiagnostics, latestDiagnostics.shouldDisplay else { return nil }
        return latestDiagnostics
    }

    func process(
        image: UIImage,
        appLanguage: DisplayLanguage,
        systemLocale: Locale = .current
    ) async {
        guard step == .source, submittedIDs.isEmpty else { return }
        let ocrLanguage = CalendarOCRLanguage.resolve(
            appLanguage: appLanguage,
            systemLocale: systemLocale
        )
        scanOCRLanguage = ocrLanguage
        step = .recognizing
        failureMessage = nil
        latestDiagnostics = nil
        do {
            let normalizedImage = try CalendarPhotoImportImageNormalizer
                .normalizedCGImage(from: image)
            #if DEBUG
            let rawSize = image.cgImage.map { "\($0.width)x\($0.height)" } ?? "unknown"
            print(
                "[CalendarImport] sourcePixels=\(rawSize) "
                    + "normalizedPixels=\(normalizedImage.width)x\(normalizedImage.height)"
            )
            print(
                "[CalendarImport] appLanguage=\(ocrLanguage.appLanguage.rawValue) "
                    + "ocrLanguage=\(ocrLanguage.visionRecognitionLanguageCode)"
            )
            #endif
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
                ocrLanguage: ocrLanguage,
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
                let rectified: (image: CGImage, geometry: CalendarPhotoGridGeometry)
                do {
                    rectified = try CalendarPhotoGridRectifier.correct(
                        image: normalizedImage,
                        grid: grid
                    )
                } catch {
                    print("[CalendarImport] gridGeometry=perspectiveCorrectionFailed error=\(error)")
                    throw error
                }
                let monthParser = CalendarPhotoGridFirstParser()
                let regions = monthParser.dayRegions(
                    yearMonth: yearMonth,
                    weekStart: weekStart,
                    grid: rectified.geometry
                )
                let ppOCRRun = try await ppOCRService.recognizeMonthCells(
                    image: rectified.image,
                    regions: regions,
                    ocrLanguage: ocrLanguage
                )
                let recognitionPlan = PPOCRMonthRecognitionRouter().makePlan(
                    run: ppOCRRun,
                    regions: regions
                )
                let languageAwareVisionObservations = try await ocrService.recognizeMonthCells(
                    image: rectified.image,
                    regions: regions,
                    ocrLanguage: ocrLanguage
                )
                observations = CalendarMonthOCRObservationMerger().merge(
                    ppOCRObservations: recognitionPlan.candidateInputObservations,
                    visionObservations: languageAwareVisionObservations,
                    regions: regions,
                    visionFallbackRegions: recognitionPlan.visionFallbackRegions
                )
                let result = try monthParser.parseMonth(
                    observations: observations,
                    yearMonth: yearMonth,
                    weekStart: weekStart,
                    grid: rectified.geometry,
                    defaultCalendarID: defaultCalendarID,
                    holidayNamesByDate: holidayNamesByDate(in: yearMonth),
                    orientationDiagnostics: orientationDiagnostics,
                    recognitionCellDiagnostics: recognitionPlan.cellDiagnostics,
                    recognitionModelPOC: recognitionPlan.recognitionModelPOC,
                    diagnosticsHandler: { [weak self] diagnostics in
                        self?.recordDiagnostics(diagnostics)
                    }
                )
                recognizedYearMonth = result.yearMonth
                draft.prefill(from: result.candidates)
            case .day:
                let result = try CalendarPhotoDayParser().parse(
                    observations: observations,
                    selectedDate: daySelection,
                    defaultCalendarID: defaultCalendarID,
                    diagnosticsHandler: { [weak self] diagnostics in
                        self?.recordDiagnostics(diagnostics)
                    }
                )
                recognizedYearMonth = result.yearMonth
                draft.prefill(from: result.candidates)
            }
            step = .source
        } catch {
            step = .source
            failureMessage = localizedMessage(for: error)
        }
    }

    private var selectedYearMonth: CalendarImportYearMonth? {
        let components = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month], from: monthSelection)
        guard let year = components.year, let month = components.month else { return nil }
        return CalendarImportYearMonth(year: year, month: month)
    }

    private func holidayNamesByDate(
        in yearMonth: CalendarImportYearMonth
    ) -> [DateOnly: Set<String>] {
        let manager = HolidaySubscriptionManager.shared
        let localizer = HolidayNameLocalizer()
        // Printed paper calendars need not match the user's enabled subscriptions.
        // Read existing caches only; this does not change subscriptions or fetch data.
        let events = manager.holidays(for: HolidayRegion.allCases).filter {
            $0.date.year == yearMonth.year && $0.date.month == yearMonth.month
        }
        return events.reduce(into: [:]) { result, event in
            let names = [
                event.name,
                localizer.localizedDisplayName(for: event.name, in: event.region)
            ] + Array(event.translatedNames.values)
            for name in names where !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result[event.date, default: []].insert(name)
            }
        }
    }

    func setTargetCalendarID(_ calendarID: UUID) {
        guard !isSaving, submittedIDs.isEmpty,
              compatibleCalendars.contains(where: { $0.id == calendarID }) else { return }
        commonTargetCalendarID = calendarID
        draft.setTargetCalendarID(calendarID)
    }

    func saveSelected() async -> Bool {
        guard canSave, let calendarID = commonTargetCalendarID,
              let destination = compatibleCalendars.first(where: { $0.id == calendarID }) else {
            failureMessage = LocalizationManager.shared.localized(.calendarPhotoImportInvalidCandidate)
            return false
        }
        isSaving = true
        failureMessage = nil
        defer { isSaving = false }

        // Read the confirmation snapshot only. Convert and validate the whole batch
        // before the first write; a partial time range never reaches persistence.
        let rows = draft.confirmationRows
        let events: [CalendarEvent]
        do {
            events = try rows.map { try $0.makeEvent() }
        } catch {
            failureMessage = LocalizationManager.shared.localized(.calendarPhotoImportInvalidCandidate)
            return false
        }
        if destination.kind != .sharedReceived {
            do {
                try await eventUseCase.createEventsAtomically(events)
                didSave = true
                return true
            } catch {
                failureMessage = error.localizedDescription
                return false
            }
        }

        // Received calendars use the existing event-only outbox. Preserve every
        // draft row and its UUID, and retry through that outbox, never a second create.
        if !submittedIDs.isEmpty { await sharingStore.synchronizeAll() }
        var syncedCount = 0
        var pendingCount = 0
        var failedCount = 0
        for event in events {
            var status = sharingStore.sharedEventSyncStatus(calendarID: calendarID, eventID: event.id)
            if !submittedIDs.contains(event.id) {
                do {
                    status = try await sharingStore.createReceivedSharedEvent(
                        SharedEventSnapshot(
                            id: event.id, title: event.title, startDate: event.startDate,
                            endDate: event.endDate, isAllDay: event.isAllDay, updatedAt: event.updatedAt
                        ),
                        calendarID: calendarID
                    )
                    submittedIDs.insert(event.id)
                } catch {
                    status = sharingStore.sharedEventSyncStatus(calendarID: calendarID, eventID: event.id)
                    if status != nil { submittedIDs.insert(event.id) }
                }
            }
            switch status {
            case .synced: syncedCount += 1
            case .saving, .pending: pendingCount += 1
            case .failed, .permissionRevoked, .deletedRemotely, nil: failedCount += 1
            }
        }
        if failedCount == 0, pendingCount == 0 {
            didSave = true
            return true
        }
        if pendingCount > 0, failedCount > 0 {
            failureMessage = String(
                format: LocalizationManager.shared.localized(.calendarPhotoImportSaveMixedFormat),
                locale: LocalizationManager.shared.currentLocale, syncedCount, pendingCount, failedCount
            )
        } else if pendingCount > 0 {
            failureMessage = String(
                format: LocalizationManager.shared.localized(.calendarPhotoImportSavePendingFormat),
                locale: LocalizationManager.shared.currentLocale, syncedCount, pendingCount
            )
        } else {
            failureMessage = String(
                format: LocalizationManager.shared.localized(.calendarPhotoImportSavePartialFormat),
                locale: LocalizationManager.shared.currentLocale, syncedCount, failedCount
            )
        }
        return false
    }

    private func recordDiagnostics(_ diagnostics: CalendarPhotoImportDiagnostics) {
        var diagnostics = diagnostics
        if let scanOCRLanguage {
            diagnostics.appLanguage = scanOCRLanguage.appLanguage
            diagnostics.ocrLanguage = scanOCRLanguage.visionRecognitionLanguageCode
            diagnostics.timeRecognitionEngine = diagnostics.scanMode == .month
                ? "ppocrv6"
                : "vision"
            diagnostics.textRecognitionEngine = "vision"
            diagnostics.textRecognitionLanguage = scanOCRLanguage.visionRecognitionLanguageCode
        }
        latestDiagnostics = diagnostics
        recognizedYearMonth = diagnostics.resolvedYearMonth
        Self.debugLog(diagnostics)
    }

    private static func debugLog(_ diagnostics: CalendarPhotoImportDiagnostics) {
        #if DEBUG
        func value(_ yearMonth: CalendarImportYearMonth?) -> String {
            guard let yearMonth else { return "none" }
            return String(format: "%04d-%02d", yearMonth.year, yearMonth.month)
        }
        print(
            "[CalendarImport] appLanguage=\(diagnostics.appLanguage?.rawValue ?? "unknown") "
                + "ocrLanguage=\(diagnostics.ocrLanguage ?? "unknown") "
                + "manualYearMonth=\(value(diagnostics.manualYearMonth)) "
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
        if let commonTargetCalendarID, calendars.contains(where: { $0.id == commonTargetCalendarID }) {
            return commonTargetCalendarID
        }
        if calendars.contains(where: { $0.id == sharingStore.selection.calendarID }) {
            return sharingStore.selection.calendarID
        }
        return calendars.first?.id
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
        case CalendarPhotoImportImageError.perspectiveCorrectionFailed:
            return LocalizationManager.shared.localized(.calendarPhotoImportOCRFailed)
        default:
            return LocalizationManager.shared.localized(.calendarPhotoImportOCRFailed)
        }
    }
}

private struct CalendarMonthTimeSelection: Identifiable {
    let rowID: UUID
    let isStart: Bool
    var id: String { "\(rowID)-\(isStart)" }
}

struct CalendarPhotoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var localization: LocalizationManager
    @ObservedObject private var sharingStore: CalendarSharingStore
    @StateObject private var viewModel: CalendarPhotoImportViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingCameraPermissionAlert = false
    @State private var showingScanOptions = false
    @State private var diagnosticsCopied = false
    @State private var editingTime: CalendarMonthTimeSelection?
    @State private var detailRow: CalendarMonthInputRow?
    @FocusState private var focusedTitleID: UUID?
    let onCompleted: () -> Void

    init(
        eventUseCase: EventUseCase,
        sharingStore: CalendarSharingStore,
        initialDate: Date,
        onCompleted: @escaping () -> Void
    ) {
        self.sharingStore = sharingStore
        _viewModel = StateObject(wrappedValue: CalendarPhotoImportViewModel(
            eventUseCase: eventUseCase, sharingStore: sharingStore, initialDate: initialDate
        ))
        self.onCompleted = onCompleted
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .source: inputView
                case .recognizing: recognizingView
                case .review: confirmationView
                }
            }
            .background(SettingsModalSurface.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if viewModel.step == .review {
                        Button { viewModel.backToInput() } label: {
                            Label(localization.localized(.monthInputBack), systemImage: "chevron.left")
                        }
                        .accessibilityIdentifier("monthInput.back")
                        .disabled(viewModel.isSaving)
                    } else {
                        Button(localization.localized(.cancel)) { dismiss() }
                            .disabled(viewModel.step == .recognizing)
                    }
                }
                if viewModel.step != .review {
                    ToolbarItem(placement: .principal) {
                        Button { showingScanOptions = true } label: {
                            Text(monthText).font(.headline).foregroundStyle(SettingsModalSurface.primaryText)
                        }
                        .disabled(viewModel.step == .recognizing || !viewModel.submittedIDs.isEmpty)
                        .accessibilityIdentifier("monthInput.month")
                        .accessibilityHint(localization.localized(.monthInputScanOptions))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localization.localized(.monthInputConfirm)) {
                            focusedTitleID = nil
                            viewModel.prepareConfirmation()
                        }
                        .disabled(viewModel.draft.validRows.isEmpty || viewModel.step == .recognizing)
                        .accessibilityIdentifier("monthInput.confirm")
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: save) {
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text(localization.localized(.monthInputSaveAndClose))
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(ShiftCalendarColors.accentYellow, in: Capsule())
                        .foregroundStyle(.black)
                        .disabled(!viewModel.canSave)
                        .accessibilityIdentifier("calendarPhotoImport.save")
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
                        await viewModel.process(image: image, appLanguage: localization.currentLanguage,
                                                systemLocale: localization.currentLocale)
                    }
                },
                onCancel: { showingCamera = false }
            ).ignoresSafeArea()
        }
        .sheet(isPresented: $showingScanOptions) { scanOptionsView }
        .sheet(item: $editingTime) { selection in timeEditor(selection) }
        .sheet(item: $detailRow) { row in candidateDetailView(row) }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .alert(localization.localized(.calendarPhotoImportErrorTitle), isPresented: Binding(
            get: { viewModel.failureMessage != nil },
            set: { if !$0 { viewModel.failureMessage = nil } }
        )) {
            Button(localization.localized(.ok)) { viewModel.failureMessage = nil }
        } message: {
            Text(viewModel.failureMessage ?? "")
        }
        .alert(localization.localized(.calendarPhotoImportCameraPermissionDenied),
               isPresented: $showingCameraPermissionAlert) {
            Button(localization.localized(.cancel), role: .cancel) {}
            Button(localization.localized(.calendarPhotoImportOpenSettings)) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        } message: {
            Text(localization.localized(.calendarPhotoImportCameraPermissionMessage))
        }
        .onChange(of: viewModel.latestDiagnostics) { _, _ in diagnosticsCopied = false }
    }

    private var inputView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            sourceButton(.calendarPhotoImportPhotos, icon: "photo", isCamera: false)
                        }
                        .accessibilityIdentifier("calendarPhotoImport.photos")
                        Button(action: openCamera) {
                            sourceButton(.calendarPhotoImportCamera, icon: "camera", isCamera: true)
                        }
                        .accessibilityIdentifier("calendarPhotoImport.camera")
                    }
                    .disabled(!viewModel.submittedIDs.isEmpty)
                    Text(localization.localized(.calendarPhotoImportSourceMessage))
                        .font(.caption)
                        .foregroundStyle(SettingsModalSurface.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 0) {
                    tableHeader(isConfirmation: false)
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.draft.rows) { row in
                            inputRow(row)
                            Divider().overlay(SettingsModalSurface.separator)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("monthInput.editor")
    }

    private func sourceButton(_ title: LocalizedString, icon: String, isCamera: Bool) -> some View {
        Label(localization.localized(title), systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(isCamera ? Color.black : SettingsModalSurface.primaryText)
            .background(isCamera ? ShiftCalendarColors.accentYellow : SettingsModalSurface.sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: TimeNestTheme.controlCornerRadius))
    }

    private func tableHeader(isConfirmation: Bool) -> some View {
        HStack(spacing: 8) {
            Text(localization.localized(.calendarPhotoImportDate)).frame(width: dateWidth, alignment: .leading)
            Text(localization.localized(.calendarPhotoImportSchedule)).frame(maxWidth: .infinity, alignment: .leading)
            Text(localization.localized(isConfirmation ? .monthInputTimeRange : .calendarPhotoImportTime))
                .frame(width: timeWidth, alignment: .leading)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(SettingsModalSurface.secondaryText)
        .padding(.vertical, 12)
        .accessibilityHidden(true)
    }

    private var dateWidth: CGFloat { dynamicTypeSize.isAccessibilitySize ? 82 : 54 }
    private var timeWidth: CGFloat { dynamicTypeSize.isAccessibilitySize ? 180 : 158 }

    @ViewBuilder
    private func inputRow(_ row: CalendarMonthInputRow) -> some View {
        let locked = viewModel.submittedIDs.contains(row.id)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    dateMenu(row)
                    titleField(row)
                    timeButtons(row)
                }
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 8) {
                    dateMenu(row).frame(width: dateWidth, alignment: .leading)
                    titleField(row)
                    timeButtons(row).frame(width: timeWidth)
                }
                .padding(.vertical, 4)
            }
        }
        .disabled(locked)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("monthInput.row.\(dayNumber(row))")
    }

    private func dateMenu(_ row: CalendarMonthInputRow) -> some View {
        Menu {
            Button {
                viewModel.draft.addRow(on: row.candidate.date)
            } label: {
                Label(localization.localized(.monthInputAddRow), systemImage: "plus")
            }
            if !row.isBaseRow {
                Button(role: .destructive) { viewModel.draft.deleteRow(id: row.id) } label: {
                    Label(localization.localized(.monthInputDeleteRow), systemImage: "trash")
                }
            }
        } label: {
            dateLabel(row)
                .frame(minHeight: 32)
        }
        .accessibilityHint(localization.localized(.monthInputAddRow))
        .accessibilityIdentifier("monthInput.day.\(dayNumber(row))")
    }

    private func titleField(_ row: CalendarMonthInputRow) -> some View {
        HStack(spacing: 2) {
            TextField(localization.localized(.monthInputTitlePlaceholder), text: Binding(
                get: { currentRow(row).candidate.title },
                set: { title in updateRow(row.id) { $0.setTitle(title) } }
            ))
            .focused($focusedTitleID, equals: row.id)
            .font(.subheadline)
            .submitLabel(.done)
            .onSubmit { focusedTitleID = nil }
            .accessibilityLabel(localization.localized(.calendarPhotoImportSchedule))
            .accessibilityIdentifier("monthInput.title.\(dayNumber(row))")
            Menu {
                ForEach(viewModel.shiftTemplates) { template in
                    Button(template.displayName) {
                        focusedTitleID = nil
                        updateRow(row.id) { $0.selectShift(template) }
                    }
                }
                if row.ocrSource != nil {
                    Button(localization.localized(.calendarPhotoImportOriginalText)) { detailRow = row }
                }
            } label: {
                Image(systemName: row.candidate.needsReview ? "exclamationmark.circle" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(row.candidate.needsReview ? Color.orange : SettingsModalSurface.secondaryText)
                    .frame(width: 26, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(localization.localized(.monthInputChooseShift))
            .accessibilityIdentifier("monthInput.shift.\(dayNumber(row))")
        }
        .padding(.leading, 10)
        .background(titleColor(row).opacity(row.shiftTemplateID == nil ? 0.06 : 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(SettingsModalSurface.separator, lineWidth: 0.5))
    }

    private func titleColor(_ row: CalendarMonthInputRow) -> Color {
        row.shiftColorHex.flatMap { Color(hex: $0) } ?? SettingsModalSurface.secondaryText
    }

    private func timeButtons(_ row: CalendarMonthInputRow) -> some View {
        HStack(spacing: 4) {
            timeButton(row, isStart: true)
            Text("–").foregroundStyle(SettingsModalSurface.secondaryText)
            timeButton(row, isStart: false)
        }
        .font(.subheadline.monospacedDigit())
    }

    private func timeButton(_ row: CalendarMonthInputRow, isStart: Bool) -> some View {
        Button {
            focusedTitleID = nil
            editingTime = CalendarMonthTimeSelection(rowID: row.id, isStart: isStart)
        } label: {
            Text(timeText(row, isStart: isStart))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(SettingsModalSurface.fieldBackground, in: Capsule())
                .overlay(Capsule().stroke(SettingsModalSurface.separator, lineWidth: 0.5))
        }
        .foregroundStyle(SettingsModalSurface.primaryText)
        .accessibilityLabel(localization.localized(isStart ? .calendarPhotoImportStartTime : .calendarPhotoImportEndTime))
        .accessibilityValue(timeText(row, isStart: isStart))
    }

    private func timeEditor(_ selection: CalendarMonthTimeSelection) -> some View {
        NavigationStack {
            DatePicker(
                localization.localized(selection.isStart ? .calendarPhotoImportStartTime : .calendarPhotoImportEndTime),
                selection: timeBinding(selection), displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.localized(.done)) {
                        // A missing OCR endpoint only becomes valid after an explicit choice,
                        // including Done with the initially displayed picker value.
                        let value = timeBinding(selection).wrappedValue
                        timeBinding(selection).wrappedValue = value
                        editingTime = nil
                    }
                }
            }
        }
        .environment(\.locale, localization.currentLocale)
        .presentationDetents([.height(320)])
    }

    private func timeBinding(_ selection: CalendarMonthTimeSelection) -> Binding<Date> {
        Binding(
            get: {
                let row = viewModel.draft.rows.first { $0.id == selection.rowID }
                let minutes = selection.isStart ? row?.candidate.startTimeMinutes : row?.candidate.endTimeMinutes
                let clock = minutes ?? (selection.isStart ? 9 * 60 : 17 * 60 + 30)
                return Calendar(identifier: .gregorian).date(
                    bySettingHour: clock / 60, minute: clock % 60, second: 0,
                    of: row?.candidate.date ?? viewModel.draft.month
                ) ?? viewModel.draft.month
            },
            set: { date in
                let parts = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
                updateRow(selection.rowID) {
                    $0.setTime((parts.hour ?? 0) * 60 + (parts.minute ?? 0), isStart: selection.isStart)
                }
            }
        )
    }

    private var confirmationView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(monthText).font(.title3.bold())
                        Spacer(minLength: 8)
                        Text(String(format: localization.localized(.monthInputSaveCountFormat),
                                    locale: localization.currentLocale, viewModel.draft.confirmationRows.count))
                            .font(.subheadline)
                            .foregroundStyle(SettingsModalSurface.secondaryText)
                            .accessibilityIdentifier("monthInput.saveCount")
                    }
                    Divider()
                    targetCalendarPicker
                }
                .padding(16)
                .background(SettingsModalSurface.sectionBackground, in: RoundedRectangle(cornerRadius: 16))
                VStack(spacing: 0) {
                    tableHeader(isConfirmation: true)
                    VStack(spacing: 0) {
                        ForEach(viewModel.draft.confirmationRows) { row in
                            confirmationRow(row)
                            if row.id != viewModel.draft.confirmationRows.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 8)
                    .background(SettingsModalSurface.sectionBackground, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
        }
        .accessibilityIdentifier("monthInput.confirmation")
    }

    private var targetCalendarPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(localization.localized(.calendarPhotoImportTargetCalendar), selection: Binding(
                get: { viewModel.commonTargetCalendarID },
                set: { if let id = $0 { viewModel.setTargetCalendarID(id) } }
            )) {
                if viewModel.commonTargetCalendarID == nil {
                    Text(localization.localized(.calendarPhotoImportNoWritableCalendar)).tag(Optional<UUID>.none)
                }
                ForEach(viewModel.availableCalendars) { calendar in
                    Text(calendar.name).tag(Optional(calendar.id))
                        .disabled(!viewModel.compatibleCalendars.contains { $0.id == calendar.id })
                }
            }
            .tint(SettingsModalSurface.secondaryText)
            .disabled(viewModel.isSaving || !viewModel.submittedIDs.isEmpty)
            .accessibilityIdentifier("calendarPhotoImport.targetCalendar")
            if !viewModel.compatibleCalendars.contains(where: { $0.id == viewModel.commonTargetCalendarID }) {
                Text(localization.localized(viewModel.availableCalendars.isEmpty
                    ? .calendarPhotoImportNoWritableCalendar : .monthInputShiftCalendarRequired))
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func confirmationRow(_ row: CalendarMonthInputRow) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    dateLabel(row)
                    confirmationTitle(row)
                    Text(timeRange(row)).font(.body.monospacedDigit())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    dateLabel(row).frame(width: dateWidth, alignment: .leading)
                    confirmationTitle(row)
                    Text(timeRange(row))
                        .font(.subheadline.monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .frame(width: timeWidth, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("monthInput.confirmedRow.\(dayNumber(row))")
    }

    private func confirmationTitle(_ row: CalendarMonthInputRow) -> some View {
        HStack(spacing: 4) {
            Text(row.candidate.effectiveTitle).font(.subheadline.weight(.medium))
            if row.candidate.needsReview {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    .accessibilityLabel(localization.localized(.calendarPhotoImportNeedsReview))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(titleColor(row).opacity(row.shiftTemplateID == nil ? 0.08 : 0.18),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private var scanOptionsView: some View {
        NavigationStack {
            Form {
                Section(localization.localized(.monthInputScanOptions)) {
                    Picker(localization.localized(.calendarPhotoImportScanMode), selection: $viewModel.scanMode) {
                        Text(localization.localized(.calendarPhotoImportMonthScan)).tag(CalendarPhotoScanMode.month)
                        Text(localization.localized(.calendarPhotoImportDayScan)).tag(CalendarPhotoScanMode.day)
                    }
                    if viewModel.scanMode == .month {
                        Picker(localization.localized(.calendarPhotoImportWeekStart), selection: $viewModel.weekStart) {
                            Text(localization.localized(.calendarPhotoImportSundayFirst)).tag(CalendarPhotoImportWeekStart.sunday)
                            Text(localization.localized(.calendarPhotoImportMondayFirst)).tag(CalendarPhotoImportWeekStart.monday)
                        }
                        Text(localization.localized(.calendarPhotoImportWeekStartHelp)).font(.footnote)
                    } else {
                        DatePicker(localization.localized(.calendarPhotoImportSelectDate),
                                   selection: $viewModel.daySelection, in: monthDateRange, displayedComponents: .date)
                    }
                }
                if let diagnostics = viewModel.visibleDiagnostics { diagnosticsSection(diagnostics) }
            }
            .navigationTitle(localization.localized(.monthInputScanOptions))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.localized(.done)) { showingScanOptions = false }
                }
            }
        }
    }

    private var monthDateRange: ClosedRange<Date> {
        let lastDate = viewModel.draft.rows.last?.candidate.date ?? viewModel.draft.month
        return viewModel.draft.month...lastDate
    }

    private func candidateDetailView(_ row: CalendarMonthInputRow) -> some View {
        NavigationStack {
            Form {
                Section {
                    Text(currentRow(row).candidate.effectiveTitle)
                    Text(timeRange(currentRow(row)))
                    if currentRow(row).candidate.needsReview {
                        Button(localization.localized(.calendarPhotoImportMarkReviewed)) {
                            updateRow(row.id) { $0.candidate.needsReview = false }
                        }
                    }
                    if row.candidate.personToken != nil {
                        Toggle(localization.localized(.calendarPhotoImportIncludePersonInTitle), isOn: Binding(
                            get: { currentRow(row).candidate.includesPersonTokenInTitle },
                            set: { value in updateRow(row.id) { $0.candidate.includesPersonTokenInTitle = value } }
                        ))
                    }
                    Text(String(format: localization.localized(.calendarPhotoImportConfidenceFormat),
                                locale: localization.currentLocale, Int(row.candidate.confidence * 100)))
                }
                Section(localization.localized(.calendarPhotoImportOriginalText)) {
                    Text(row.candidate.originalText).textSelection(.enabled)
                }
            }
            .navigationTitle(dateText(row.candidate.date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.localized(.done)) { detailRow = nil }
                }
            }
        }
    }

    private var recognizingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text(localization.localized(.calendarPhotoImportRecognizing)).font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("calendarPhotoImport.recognizing")
    }

    private func currentRow(_ fallback: CalendarMonthInputRow) -> CalendarMonthInputRow {
        viewModel.draft.rows.first { $0.id == fallback.id } ?? fallback
    }

    private func updateRow(_ id: UUID, _ update: (inout CalendarMonthInputRow) -> Void) {
        guard !viewModel.isSaving, !viewModel.submittedIDs.contains(id),
              let index = viewModel.draft.rows.firstIndex(where: { $0.id == id }) else { return }
        update(&viewModel.draft.rows[index])
    }

    private func dayNumber(_ row: CalendarMonthInputRow) -> Int {
        Calendar(identifier: .gregorian).component(.day, from: row.candidate.date)
    }

    private func dateLabel(_ row: CalendarMonthInputRow) -> some View {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: row.candidate.date)
        return Text(dateText(row.candidate.date))
            .font(.subheadline)
            .foregroundStyle(weekday == 1 ? ShiftCalendarColors.sundayRed
                : weekday == 7 ? ShiftCalendarColors.saturdayBlue : SettingsModalSurface.primaryText)
            .lineLimit(1).minimumScaleFactor(0.8)
    }

    private func dateText(_ date: Date) -> String {
        CalendarMonthInputDraft.dateText(date, locale: localization.currentLocale)
    }

    private var monthText: String {
        let formatter = DateFormatter()
        formatter.locale = localization.currentLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: viewModel.draft.month)
    }

    private func timeText(_ row: CalendarMonthInputRow, isStart: Bool) -> String {
        guard let minutes = isStart ? row.candidate.startTimeMinutes : row.candidate.endTimeMinutes else { return "—" }
        let prefix = !isStart && row.spansMidnight ? localization.localized(.workNextDayPrefix) : ""
        return prefix + String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func timeRange(_ row: CalendarMonthInputRow) -> String {
        "\(timeText(row, isStart: true)) – \(timeText(row, isStart: false))"
    }

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
                appLanguage: localization.currentLanguage,
                systemLocale: localization.currentLocale
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
