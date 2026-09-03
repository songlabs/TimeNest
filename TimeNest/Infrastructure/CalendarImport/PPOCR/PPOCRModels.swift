import Foundation

// Portions of the OCR decoding and configuration behavior are derived from
// RapidOCR/PaddleOCR (Apache-2.0) and were rewritten for Swift/iOS by TimeNest.

enum PPOCRConfiguration {
    static let textScore: Float = 0.30
    static let timeRecoveryConfidenceThreshold: Float = 0.65

    static let detectionLimitSideLength = 960
    static let detectionLimitType = "min"
    static let detectionThreshold: Float = 0.20
    static let detectionBoxThreshold: Float = 0.35
    static let detectionUnclipRatio = 1.8
    static let detectionUsesDilation = true
    static let detectionScoreMode = "fast"
    static let detectionMean: [Float] = [0.5, 0.5, 0.5]
    static let detectionStandardDeviation: [Float] = [0.5, 0.5, 0.5]

    static let classificationImageShape = [3, 48, 192]
    static let classificationThreshold: Float = 0.9
    static let recognitionImageShape = [3, 48, 320]
}

enum PPOCRModelManifest {
    static let onnxRuntimeVersion = "1.29.0"
    static let cocoaPodsVersion = "1.16.2"
    static let rapidOCRModelRevision = "v3.9.2"

    static let detector = PPOCRModelFile(
        resourceName: "PP-OCRv6_det_small",
        fileExtension: "onnx",
        displayName: "PP-OCRv6_det_small",
        byteCount: 9_929_594,
        sha256: "090f04abcd9d9a7498bc4ebf677e4cb9bdce1fe4197ddb7e529f1ef44e1ff94f"
    )
    static let classifier = PPOCRModelFile(
        resourceName: "ch_ppocr_mobile_v2.0_cls_mobile",
        fileExtension: "onnx",
        displayName: "ch_ppocr_mobile_v2.0_cls_mobile",
        byteCount: 585_532,
        sha256: "e47acedf663230f8863ff1ab0e64dd2d82b838fceb5957146dab185a89d6215c"
    )
    static let recognizer = PPOCRModelFile(
        resourceName: "PP-OCRv6_rec_small",
        fileExtension: "onnx",
        displayName: "PP-OCRv6_rec_small",
        byteCount: 21_234_383,
        sha256: "6f327246b50388f3c176ae304bd95767ea6dc0c9ae92153ef8cbe210b3c14884"
    )
    static let recognitionCharacters = PPOCRModelFile(
        resourceName: "PP-OCRv6_rec_small.characters",
        fileExtension: "txt",
        displayName: "PP-OCRv6_rec_small.characters",
        byteCount: 74_947,
        sha256: "b5f2bfe2bdd9448429e3e82b51c789775d9b42f2403d082b00662eb77e401c5d"
    )
    static let candidateRecognizer = PPOCRModelFile(
        resourceName: "ch_PP-OCRv5_rec_mobile",
        fileExtension: "onnx",
        displayName: "PP-OCRv5_mobile_rec (ch_PP-OCRv5_rec_mobile.onnx)",
        byteCount: 16_631_306,
        sha256: "5825fc7ebf84ae7a412be049820b4d86d77620f204a041697b0494669b1742c5"
    )
    static let candidateRecognitionCharacters = PPOCRModelFile(
        resourceName: "ppocrv5_dict",
        fileExtension: "txt",
        displayName: "PP-OCRv5_mobile_rec characters (ppocrv5_dict.txt)",
        byteCount: 74_012,
        sha256: "d1979e9f794c464c0d2e0b70a7fe14dd978e9dc644c0e71f14158cdf8342af1b"
    )

    static let recognitionCharacterCount = 18_708
    static let candidateRecognitionCharacterCount = 18_383
}

struct PPOCRModelFile: Equatable, Sendable {
    let resourceName: String
    let fileExtension: String
    let displayName: String
    let byteCount: Int
    let sha256: String

    var fileName: String { "\(resourceName).\(fileExtension)" }
}

enum PPOCRError: Error, Equatable, Sendable {
    case missingModel(String)
    case invalidModelFile(String)
    case invalidCharacterDictionary
    case invalidImage
    case invalidCrop
    case invalidTensor
    case invalidOutput(String)
    case runtimeFailure(String)

    var diagnosticCode: String {
        switch self {
        case .missingModel(let fileName):
            return "missingModel:\(fileName)"
        case .invalidModelFile(let fileName):
            return "invalidModelFile:\(fileName)"
        case .invalidCharacterDictionary:
            return "invalidCharacterDictionary"
        case .invalidImage:
            return "invalidImage"
        case .invalidCrop:
            return "invalidCrop"
        case .invalidTensor:
            return "invalidTensor"
        case .invalidOutput(let stage):
            return "invalidOutput:\(stage)"
        case .runtimeFailure(let stage):
            return "runtimeFailure:\(stage)"
        }
    }
}

enum PPOCRModelFileValidator {
    static func validate(
        fileName: String,
        actualByteCount: Int,
        expectedByteCount: Int
    ) throws {
        guard actualByteCount == expectedByteCount else {
            throw PPOCRError.invalidModelFile(fileName)
        }
    }
}

struct PPOCRImageSize: Equatable, Sendable {
    let width: Int
    let height: Int

    var text: String { "\(width)x\(height)" }
}

struct PPOCRPoint: Equatable, Sendable {
    var x: Double
    var y: Double
}

struct PPOCRDetectedBox: Equatable, Sendable {
    let points: [PPOCRPoint]
    let score: Float
}

struct PPOCRTextResult: Equatable, Sendable {
    let text: String
    let confidence: Float
    let boundingBox: CalendarOCRBoundingBox
    var timeParseQualityOverride: CalendarImportTimeParseQuality? = nil
}

enum PPOCRTimeRecoveryReason: String, Equatable, Sendable {
    case lowConfidence
    case timeLikeButUnparsed
}

enum PPOCRTimeRecognitionSource: String, Equatable, Sendable {
    case currentPPocr
    case enhancedPPocr
    case candidatePPocr
    case visionSecondary
}

struct PPOCRRecognitionAlternative: Equatable, Sendable {
    let text: String
    let confidence: Float
}

struct PPOCRTimeRecognitionSelection: Equatable, Sendable {
    let alternative: PPOCRRecognitionAlternative
    let source: PPOCRTimeRecognitionSource
    let selectionReason: String

    var isRecovered: Bool { source != .currentPPocr }
}

enum PPOCRTimeRecoveryPolicy {
    static func reason(
        text: String,
        confidence: Float
    ) -> PPOCRTimeRecoveryReason? {
        guard CalendarImportTimeParser.parseMonth(text) == nil else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if confidence < PPOCRConfiguration.timeRecoveryConfidenceThreshold,
           !isInsufficientNumericToken(trimmed) {
            return .lowConfidence
        }
        return isTimeLikeButUnparsed(trimmed) ? .timeLikeButUnparsed : nil
    }

    static func select(
        current: PPOCRRecognitionAlternative,
        enhanced: PPOCRRecognitionAlternative?,
        candidate: PPOCRRecognitionAlternative?,
        vision: PPOCRRecognitionAlternative?
    ) -> PPOCRTimeRecognitionSelection {
        if CalendarImportTimeParser.parseMonth(current.text) != nil {
            return PPOCRTimeRecognitionSelection(
                alternative: current,
                source: .currentPPocr,
                selectionReason: "currentValidTime"
            )
        }
        let secondary: [(PPOCRTimeRecognitionSource, PPOCRRecognitionAlternative?)] = [
            (.enhancedPPocr, enhanced),
            (.candidatePPocr, candidate),
            (.visionSecondary, vision)
        ]
        for (source, alternative) in secondary {
            guard let alternative, isUsableRecoveredRange(alternative.text) else { continue }
            return PPOCRTimeRecognitionSelection(
                alternative: alternative,
                source: source,
                selectionReason: "validTimeBeatsUnparsed"
            )
        }
        return PPOCRTimeRecognitionSelection(
            alternative: current,
            source: .currentPPocr,
            selectionReason: "noValidSecondaryResult"
        )
    }

    static func isUsableRecoveredRange(_ text: String) -> Bool {
        guard let parsed = CalendarImportTimeParser.parseMonthRangeOnly(text),
              let end = parsed.endMinutes else {
            return false
        }
        return end > parsed.startMinutes
    }

    private static func isInsufficientNumericToken(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy(\.isNumber) && !(7...9).contains(text.count)
    }

    private static func isTimeLikeButUnparsed(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber).count
        guard digits >= 6 else { return false }
        let significant = text.filter { !$0.isWhitespace }.count
        guard significant > 0, Double(digits) / Double(significant) >= 0.6 else {
            return false
        }
        let possibleTimeCharacters = CharacterSet(charactersIn: ":：.=-–—〜～~")
        let hasTimePunctuation = text.unicodeScalars.contains {
            possibleTimeCharacters.contains($0)
        }
        if hasTimePunctuation { return digits <= 10 }
        return (7...9).contains(digits)
    }
}

struct PPOCRRecognitionModelComparison: Equatable, Sendable {
    let boundingBox: CalendarOCRBoundingBox
    let currentText: String
    let currentConfidence: Float
    let currentMilliseconds: Double
    var recoveryAttempted: Bool = false
    var recoveryReason: PPOCRTimeRecoveryReason? = nil
    var enhancedText: String? = nil
    var enhancedConfidence: Float? = nil
    var enhancedMilliseconds: Double? = nil
    var enhancedError: String? = nil
    let candidateText: String?
    let candidateConfidence: Float?
    let candidateMilliseconds: Double?
    let candidateError: String?
    var visionText: String? = nil
    var visionConfidence: Float? = nil
    var visionMilliseconds: Double? = nil
    var visionError: String? = nil
    var selectedText: String? = nil
    var selectedSource: PPOCRTimeRecognitionSource = .currentPPocr
    var selectionReason: String = "recoveryNotTriggered"
}

struct PPOCRRecognitionModelPOC: Equatable, Sendable {
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

struct PPOCRCellTiming: Equatable, Sendable {
    let preprocessMilliseconds: Double
    let detectionMilliseconds: Double
    let detectionPostprocessMilliseconds: Double
    let classificationMilliseconds: Double
    let recognitionMilliseconds: Double
    let totalMilliseconds: Double
}

struct PPOCRCellRecognitionResult: Equatable, Sendable {
    let day: Int
    let sourcePixels: PPOCRImageSize
    let cropRect: PPOCRPixelRect?
    let paddingApplied: Bool
    let cellPixels: PPOCRImageSize
    let detectorInputPixels: PPOCRImageSize?
    let results: [PPOCRTextResult]
    let recognitionModelComparisons: [PPOCRRecognitionModelComparison]
    let detectionCount: Int
    let timing: PPOCRCellTiming
    let error: String?
}

struct PPOCRRecognitionRun: Equatable, Sendable {
    let runtimeVersion: String
    let modelInitializedThisRun: Bool
    let modelInitializationMilliseconds: Double
    let totalMilliseconds: Double
    let recognitionModelPOC: PPOCRRecognitionModelPOC
    let cells: [PPOCRCellRecognitionResult]
}

struct PPOCRMonthRecognitionPlan: Equatable, Sendable {
    let candidateInputObservations: [CalendarOCRObservation]
    let visionFallbackRegions: [CalendarImportDayRegion]
    let cellDiagnostics: [CalendarPhotoCellRecognitionDiagnostics]
    let recognitionModelPOC: CalendarPhotoRecognitionModelPOCDiagnostics
}

struct PPOCRMonthRecognitionRouter {
    func makePlan(
        run: PPOCRRecognitionRun,
        regions: [CalendarImportDayRegion]
    ) -> PPOCRMonthRecognitionPlan {
        let regionsByDay = Dictionary(
            uniqueKeysWithValues: regions.map { ($0.day, $0) }
        )
        var observations: [CalendarOCRObservation] = []
        var fallbackRegions: [CalendarImportDayRegion] = []
        var diagnostics: [CalendarPhotoCellRecognitionDiagnostics] = []

        for cell in run.cells.sorted(by: { $0.day < $1.day }) {
            guard let region = regionsByDay[cell.day] else { continue }
            if let error = cell.error {
                fallbackRegions.append(region)
                diagnostics.append(Self.diagnostics(
                    for: cell,
                    region: region,
                    recognitionSource: .visionFallback,
                    error: error
                ))
                continue
            }

            observations.append(contentsOf: cell.results.map { result in
                CalendarOCRObservation(
                    text: result.text,
                    confidence: result.confidence,
                    boundingBox: Self.map(result.boundingBox, into: region.boundingBox),
                    timeParseQualityOverride: result.timeParseQualityOverride
                )
            })
            diagnostics.append(Self.diagnostics(
                for: cell,
                region: region,
                recognitionSource: .ppocrv6,
                error: nil
            ))
        }

        return PPOCRMonthRecognitionPlan(
            candidateInputObservations: observations,
            visionFallbackRegions: fallbackRegions,
            cellDiagnostics: diagnostics,
            recognitionModelPOC: CalendarPhotoRecognitionModelPOCDiagnostics(
                currentModel: run.recognitionModelPOC.currentModel,
                candidateModel: run.recognitionModelPOC.candidateModel,
                currentInitializedThisRun: run.recognitionModelPOC.currentInitializedThisRun,
                candidateInitializedThisRun: run.recognitionModelPOC.candidateInitializedThisRun,
                currentInitializationMilliseconds:
                    run.recognitionModelPOC.currentInitializationMilliseconds,
                candidateInitializationMilliseconds:
                    run.recognitionModelPOC.candidateInitializationMilliseconds,
                candidateInitializationError:
                    run.recognitionModelPOC.candidateInitializationError,
                currentTotalMilliseconds: run.recognitionModelPOC.currentTotalMilliseconds,
                candidateTotalMilliseconds: run.recognitionModelPOC.candidateTotalMilliseconds
            )
        )
    }

    private static func diagnostics(
        for cell: PPOCRCellRecognitionResult,
        region: CalendarImportDayRegion,
        recognitionSource: CalendarPhotoCellRecognitionSource,
        error: String?
    ) -> CalendarPhotoCellRecognitionDiagnostics {
        let cropHeight = Double(cell.cellPixels.height)
        return CalendarPhotoCellRecognitionDiagnostics(
            day: cell.day,
            recognitionSource: recognitionSource,
            cellBounds: region.boundingBox,
            sourceImagePixels: CalendarPhotoPixelSizeDiagnostics(
                width: cell.sourcePixels.width,
                height: cell.sourcePixels.height
            ),
            cropRect: cell.cropRect.map {
                CalendarPhotoPixelRectDiagnostics(
                    x: $0.x,
                    y: $0.y,
                    width: $0.width,
                    height: $0.height
                )
            },
            cropImagePixels: CalendarPhotoPixelSizeDiagnostics(
                width: cell.cellPixels.width,
                height: cell.cellPixels.height
            ),
            paddingApplied: cell.paddingApplied,
            detections: cell.recognitionModelComparisons.map { comparison in
                let bounds = comparison.boundingBox
                return CalendarPhotoOCRDetectionDiagnostics(
                    text: comparison.currentText,
                    cellLocalBoundingBox: bounds,
                    distanceToTopPixels: max(0, 1 - bounds.maxY) * cropHeight,
                    distanceToBottomPixels: max(0, bounds.minY) * cropHeight
                )
            },
            recognitionModelComparisons: cell.recognitionModelComparisons.map { comparison in
                CalendarPhotoRecognitionModelComparisonDiagnostics(
                    boundingBox: comparison.boundingBox,
                    currentText: comparison.currentText,
                    currentConfidence: comparison.currentConfidence,
                    currentMilliseconds: comparison.currentMilliseconds,
                    recoveryAttempted: comparison.recoveryAttempted,
                    recoveryReason: comparison.recoveryReason?.rawValue,
                    enhancedText: comparison.enhancedText,
                    enhancedConfidence: comparison.enhancedConfidence,
                    enhancedMilliseconds: comparison.enhancedMilliseconds,
                    enhancedError: comparison.enhancedError,
                    candidateText: comparison.candidateText,
                    candidateConfidence: comparison.candidateConfidence,
                    candidateMilliseconds: comparison.candidateMilliseconds,
                    candidateError: comparison.candidateError,
                    visionText: comparison.visionText,
                    visionConfidence: comparison.visionConfidence,
                    visionMilliseconds: comparison.visionMilliseconds,
                    visionError: comparison.visionError,
                    selectedText: comparison.selectedText ?? comparison.currentText,
                    selectedSource: comparison.selectedSource.rawValue,
                    selectionReason: comparison.selectionReason
                )
            },
            ppOCRText: cell.recognitionModelComparisons
                .map(\.currentText)
                .filter { !$0.isEmpty },
            ppOCRError: error
        )
    }

    private static func map(
        _ local: CalendarOCRBoundingBox,
        into cell: CalendarOCRBoundingBox
    ) -> CalendarOCRBoundingBox {
        CalendarOCRBoundingBox(
            x: cell.minX + local.x * cell.width,
            y: cell.minY + local.y * cell.height,
            width: local.width * cell.width,
            height: local.height * cell.height
        )
    }
}

struct PPOCRDecodedText: Equatable, Sendable {
    let text: String
    let confidence: Float
}

enum PPOCRCTCDecoder {
    static func decode(
        tokenIndices: [Int],
        probabilities: [Float],
        characters: [String]
    ) throws -> PPOCRDecodedText {
        guard tokenIndices.count == probabilities.count else {
            throw PPOCRError.invalidOutput("recognition")
        }
        var text = ""
        var acceptedProbabilities: [Float] = []
        var previousToken: Int?
        for (index, token) in tokenIndices.enumerated() {
            defer { previousToken = token }
            guard token != previousToken, token != 0 else { continue }
            guard characters.indices.contains(token) else {
                throw PPOCRError.invalidOutput("recognitionDictionary")
            }
            text += characters[token]
            acceptedProbabilities.append(probabilities[index])
        }
        let confidence: Float
        if acceptedProbabilities.isEmpty {
            confidence = 0
        } else {
            confidence = acceptedProbabilities.reduce(0, +)
                / Float(acceptedProbabilities.count)
        }
        return PPOCRDecodedText(text: text, confidence: confidence)
    }

    static func decode(
        logits: [Float],
        timeSteps: Int,
        classCount: Int,
        characters: [String]
    ) throws -> PPOCRDecodedText {
        guard timeSteps >= 0,
              classCount > 0,
              logits.count == timeSteps * classCount else {
            throw PPOCRError.invalidOutput("recognitionShape")
        }
        var tokens: [Int] = []
        var probabilities: [Float] = []
        tokens.reserveCapacity(timeSteps)
        probabilities.reserveCapacity(timeSteps)
        for step in 0..<timeSteps {
            let start = step * classCount
            var bestIndex = 0
            var bestProbability = logits[start]
            if classCount > 1 {
                for index in 1..<classCount {
                    let probability = logits[start + index]
                    if probability > bestProbability {
                        bestIndex = index
                        bestProbability = probability
                    }
                }
            }
            tokens.append(bestIndex)
            probabilities.append(bestProbability)
        }
        return try decode(
            tokenIndices: tokens,
            probabilities: probabilities,
            characters: characters
        )
    }
}

enum PPOCRCellWorkResult<Value> {
    case success(day: Int, value: Value)
    case failure(day: Int, errorCode: String)
}

enum PPOCRCellFailureIsolator {
    static func run<Item, Value>(
        items: [Item],
        day: (Item) -> Int,
        operation: (Item) throws -> Value
    ) throws -> [PPOCRCellWorkResult<Value>] {
        var output: [PPOCRCellWorkResult<Value>] = []
        for item in items {
            try Task.checkCancellation()
            let itemDay = day(item)
            do {
                output.append(.success(day: itemDay, value: try operation(item)))
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as PPOCRError {
                output.append(.failure(day: itemDay, errorCode: error.diagnosticCode))
            } catch {
                output.append(.failure(day: itemDay, errorCode: "runtimeFailure:cell"))
            }
        }
        return output
    }
}
