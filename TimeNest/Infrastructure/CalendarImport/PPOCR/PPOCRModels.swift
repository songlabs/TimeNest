import Foundation

// Portions of the OCR decoding and configuration behavior are derived from
// RapidOCR/PaddleOCR (Apache-2.0) and were rewritten for Swift/iOS by TimeNest.

enum PPOCRConfiguration {
    static let textScore: Float = 0.30

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
    let detectionCount: Int
    let timing: PPOCRCellTiming
    let error: String?
}

struct PPOCRRecognitionRun: Equatable, Sendable {
    let runtimeVersion: String
    let modelInitializedThisRun: Bool
    let modelInitializationMilliseconds: Double
    let totalMilliseconds: Double
    let cells: [PPOCRCellRecognitionResult]
}

struct PPOCRMonthRecognitionPlan: Equatable, Sendable {
    let candidateInputObservations: [CalendarOCRObservation]
    let visionFallbackRegions: [CalendarImportDayRegion]
    let cellDiagnostics: [CalendarPhotoCellRecognitionDiagnostics]
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
                    boundingBox: Self.map(result.boundingBox, into: region.boundingBox)
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
            cellDiagnostics: diagnostics
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
            detections: cell.results.map { result in
                let bounds = result.boundingBox
                return CalendarPhotoOCRDetectionDiagnostics(
                    text: result.text,
                    cellLocalBoundingBox: bounds,
                    distanceToTopPixels: max(0, 1 - bounds.maxY) * cropHeight,
                    distanceToBottomPixels: max(0, bounds.minY) * cropHeight
                )
            },
            ppOCRText: cell.results.map(\.text),
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
