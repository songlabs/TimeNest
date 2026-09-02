import Foundation

// Portions of the OCR decoding and configuration behavior are derived from
// RapidOCR/PaddleOCR (Apache-2.0) and were rewritten for Swift/iOS by TimeNest.

// This entire namespace is an experimental, observation-only benchmark.
// It must never be used to create or mutate CalendarImportCandidate values.
enum PPOCRPOCConfiguration {
    static let targetYear = 2026
    static let targetMonth = 9
    static let targetDays = [18, 19, 24, 25, 26]

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

    static func shouldRun(for yearMonth: CalendarImportYearMonth) -> Bool {
        yearMonth.year == targetYear && yearMonth.month == targetMonth
    }

    static func targetRegions(
        from regions: [CalendarImportDayRegion],
        yearMonth: CalendarImportYearMonth
    ) -> [CalendarImportDayRegion] {
        guard shouldRun(for: yearMonth) else { return [] }
        let allowedDays = Set(targetDays)
        return regions
            .filter { allowedDays.contains($0.day) }
            .sorted { $0.day < $1.day }
    }
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
}

struct PPOCRVisionCellBenchmark: Equatable, Sendable {
    let day: Int
    let cellPixels: PPOCRImageSize
    let results: [PPOCRTextResult]
    let totalMilliseconds: Double
    let error: String?
}

struct PPOCRCellTiming: Equatable, Sendable {
    let preprocessMilliseconds: Double
    let detectionMilliseconds: Double
    let detectionPostprocessMilliseconds: Double
    let classificationMilliseconds: Double
    let recognitionMilliseconds: Double
    let totalMilliseconds: Double
}

struct PPOCRCellInferenceBenchmark: Equatable, Sendable {
    let day: Int
    let cellPixels: PPOCRImageSize
    let detectorInputPixels: PPOCRImageSize?
    let results: [PPOCRTextResult]
    let detectionCount: Int
    let timing: PPOCRCellTiming
    let error: String?
}

struct PPOCRInferenceRun: Equatable, Sendable {
    let runtimeVersion: String
    let modelInitializedThisRun: Bool
    let modelInitializationMilliseconds: Double
    let fiveCellTotalMilliseconds: Double
    let cells: [PPOCRCellInferenceBenchmark]
}

struct PPOCRPOCCellDiagnostics: Equatable, Sendable {
    let day: Int
    let cellPixels: PPOCRImageSize
    let detectorInputPixels: PPOCRImageSize?
    let visionResults: [PPOCRTextResult]
    let visionMilliseconds: Double
    let ppOCRResults: [PPOCRTextResult]
    let detectionCount: Int
    let timing: PPOCRCellTiming
    let error: String?
}

struct PPOCRPOCDiagnostics: Equatable, Sendable {
    let runtimeVersion: String
    let modelInitializedThisRun: Bool
    let modelInitializationMilliseconds: Double
    let fiveCellTotalMilliseconds: Double
    let cells: [PPOCRPOCCellDiagnostics]

    static func merge(
        vision: [PPOCRVisionCellBenchmark],
        ppOCR: PPOCRInferenceRun
    ) -> PPOCRPOCDiagnostics {
        let visionByDay = Dictionary(uniqueKeysWithValues: vision.map { ($0.day, $0) })
        let cells = ppOCR.cells.map { inference -> PPOCRPOCCellDiagnostics in
            let visionCell = visionByDay[inference.day]
            let errors = [visionCell?.error, inference.error].compactMap { $0 }
            return PPOCRPOCCellDiagnostics(
                day: inference.day,
                cellPixels: inference.cellPixels,
                detectorInputPixels: inference.detectorInputPixels,
                visionResults: visionCell?.results ?? [],
                visionMilliseconds: visionCell?.totalMilliseconds ?? 0,
                ppOCRResults: inference.results,
                detectionCount: inference.detectionCount,
                timing: inference.timing,
                error: errors.isEmpty ? nil : errors.joined(separator: ",")
            )
        }
        return PPOCRPOCDiagnostics(
            runtimeVersion: ppOCR.runtimeVersion,
            modelInitializedThisRun: ppOCR.modelInitializedThisRun,
            modelInitializationMilliseconds: ppOCR.modelInitializationMilliseconds,
            fiveCellTotalMilliseconds: ppOCR.fiveCellTotalMilliseconds,
            cells: cells
        )
    }

    var plainTextLines: [String] {
        var lines = [
            "scope=2026-09 days=18,19,24,25,26",
            "localOnly=true candidateInput=false",
            "onnxRuntime=onnxruntime-objc \(runtimeVersion)",
            "modelInitializedThisRun=\(modelInitializedThisRun)",
            "modelInitMs=\(Self.milliseconds(modelInitializationMilliseconds))",
            "fiveCellTotalMs=\(Self.milliseconds(fiveCellTotalMilliseconds))"
        ]
        for cell in cells.sorted(by: { $0.day < $1.day }) {
            lines.append(contentsOf: [
                "",
                "day=\(cell.day)",
                "cellPixels=\(cell.cellPixels.text)",
                "detectorInputPixels=\(cell.detectorInputPixels?.text ?? "none")",
                "Vision:",
                "  text=\(Self.textList(cell.visionResults.map(\.text)))",
                "  confidence=\(Self.confidenceList(cell.visionResults.map(\.confidence)))",
                "  totalMs=\(Self.milliseconds(cell.visionMilliseconds))",
                "PPOCR:",
                "  text=\(Self.textList(cell.ppOCRResults.map(\.text)))",
                "  confidence=\(Self.confidenceList(cell.ppOCRResults.map(\.confidence)))",
                "PPOCR detections=\(cell.detectionCount)",
                "model:",
                "  det=\(PPOCRModelManifest.detector.displayName)",
                "  cls=\(PPOCRModelManifest.classifier.displayName)",
                "  rec=\(PPOCRModelManifest.recognizer.displayName)",
                "timing:",
                "  modelInitMs=\(Self.milliseconds(modelInitializationMilliseconds))",
                "  preprocessMs=\(Self.milliseconds(cell.timing.preprocessMilliseconds))",
                "  detMs=\(Self.milliseconds(cell.timing.detectionMilliseconds))",
                "  detPostprocessMs=\(Self.milliseconds(cell.timing.detectionPostprocessMilliseconds))",
                "  clsMs=\(Self.milliseconds(cell.timing.classificationMilliseconds))",
                "  recMs=\(Self.milliseconds(cell.timing.recognitionMilliseconds))",
                "  totalMs=\(Self.milliseconds(cell.timing.totalMilliseconds))",
                "error=\(cell.error ?? "none")"
            ])
        }
        return lines
    }

    private static func milliseconds(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func confidenceList(_ values: [Float]) -> String {
        "[" + values.map { String(format: "%.5f", Double($0)) }.joined(separator: ",") + "]"
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
        return "\"\(escaped)\""
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
