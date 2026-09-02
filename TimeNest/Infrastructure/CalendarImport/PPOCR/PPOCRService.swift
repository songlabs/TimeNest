import CoreGraphics
import Foundation

actor PPOCRService {
    private var sessions: PPOCRONNXSessions?
    private var initialModelInitializationMilliseconds: Double?

    func recognizeMonthCells(
        image: CGImage,
        regions: [CalendarImportDayRegion]
    ) async throws -> PPOCRRecognitionRun {
        let modelInitializedThisRun = sessions == nil
        let modelStart = PPOCRMonotonicClock.nowMilliseconds
        let loadedSessions: PPOCRONNXSessions
        do {
            if let sessions {
                loadedSessions = sessions
            } else {
                let created = try PPOCRONNXSessions()
                sessions = created
                loadedSessions = created
                initialModelInitializationMilliseconds =
                    PPOCRMonotonicClock.nowMilliseconds - modelStart
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as PPOCRError {
            let elapsed = PPOCRMonotonicClock.nowMilliseconds - modelStart
            return failureRun(
                image: image,
                regions: regions,
                initializedThisRun: modelInitializedThisRun,
                initializationMilliseconds: elapsed,
                errorCode: error.diagnosticCode
            )
        } catch {
            let elapsed = PPOCRMonotonicClock.nowMilliseconds - modelStart
            return failureRun(
                image: image,
                regions: regions,
                initializedThisRun: modelInitializedThisRun,
                initializationMilliseconds: elapsed,
                errorCode: "runtimeFailure:modelInit"
            )
        }

        let recognitionStart = PPOCRMonotonicClock.nowMilliseconds
        let sortedRegions = regions.sorted(by: { $0.day < $1.day })
        let workResults = try PPOCRCellFailureIsolator.run(
            items: sortedRegions,
            day: { $0.day },
            operation: { region in
                try inferCell(
                    image: image,
                    region: region,
                    sessions: loadedSessions
                )
            }
        )
        var regionsByDay: [Int: CalendarImportDayRegion] = [:]
        for region in sortedRegions { regionsByDay[region.day] = region }
        let cells = workResults.compactMap { result -> PPOCRCellRecognitionResult? in
            switch result {
            case .success(_, let recognition):
                return recognition
            case .failure(let day, let errorCode):
                guard let region = regionsByDay[day] else { return nil }
                return failureCell(image: image, region: region, errorCode: errorCode)
            }
        }
        return PPOCRRecognitionRun(
            runtimeVersion: loadedSessions.runtimeVersion,
            modelInitializedThisRun: modelInitializedThisRun,
            modelInitializationMilliseconds: initialModelInitializationMilliseconds ?? 0,
            totalMilliseconds: PPOCRMonotonicClock.nowMilliseconds - recognitionStart,
            cells: cells
        )
    }

    private func inferCell(
        image: CGImage,
        region: CalendarImportDayRegion,
        sessions: PPOCRONNXSessions
    ) throws -> PPOCRCellRecognitionResult {
        let totalStart = PPOCRMonotonicClock.nowMilliseconds
        let imageSize = PPOCRImageSize(width: image.width, height: image.height)
        guard let pixelRect = PPOCRCellPixelRectConverter.pixelRect(
            for: region.boundingBox,
            imageSize: imageSize
        ), let crop = image.cropping(to: CGRect(
            x: pixelRect.x,
            y: pixelRect.y,
            width: pixelRect.width,
            height: pixelRect.height
        )) else {
            throw PPOCRError.invalidCrop
        }

        try Task.checkCancellation()
        let preprocessStart = PPOCRMonotonicClock.nowMilliseconds
        let cellImage = try PPOCRCGImageBridge.bgrImage(from: crop)
        let detectorInputSize = try PPOCRPreprocessor.detectionInputSize(for: cellImage.size)
        let detectorTensor = try PPOCRPreprocessor.detectionTensor(from: cellImage)
        let preprocessMilliseconds = PPOCRMonotonicClock.nowMilliseconds - preprocessStart

        try Task.checkCancellation()
        let detectionStart = PPOCRMonotonicClock.nowMilliseconds
        let detectionOutput = try sessions.detector.run(
            tensor: detectorTensor,
            stage: "detection"
        )
        let detectionMilliseconds = PPOCRMonotonicClock.nowMilliseconds - detectionStart
        guard detectionOutput.shape.count == 4,
              detectionOutput.shape[0] == 1,
              detectionOutput.shape[1] == 1 else {
            throw PPOCRError.invalidOutput("detectionShape")
        }
        let detectionMapSize = PPOCRImageSize(
            width: detectionOutput.shape[3],
            height: detectionOutput.shape[2]
        )

        let postprocessStart = PPOCRMonotonicClock.nowMilliseconds
        let boxes = try PPOCRDBPostprocessor.process(
            probabilities: detectionOutput.values,
            mapSize: detectionMapSize,
            destinationSize: cellImage.size
        )
        let detectionPostprocessMilliseconds =
            PPOCRMonotonicClock.nowMilliseconds - postprocessStart

        var classificationMilliseconds = 0.0
        var recognitionMilliseconds = 0.0
        var textResults: [PPOCRTextResult] = []
        for box in boxes {
            try Task.checkCancellation()
            let classificationStart = PPOCRMonotonicClock.nowMilliseconds
            var lineImage = try cellImage.perspectiveCrop(points: box.points)
            let classificationTensor = try PPOCRPreprocessor.classificationTensor(
                from: lineImage
            )
            let classificationOutput = try sessions.classifier.run(
                tensor: classificationTensor,
                stage: "classification"
            )
            guard classificationOutput.shape == [1, 2],
                  classificationOutput.values.count == 2 else {
                throw PPOCRError.invalidOutput("classificationShape")
            }
            let predictedAngleIndex = classificationOutput.values[1]
                > classificationOutput.values[0] ? 1 : 0
            let predictedAngleScore = classificationOutput.values[predictedAngleIndex]
            if predictedAngleIndex == 1,
               predictedAngleScore > PPOCRConfiguration.classificationThreshold {
                lineImage = try lineImage.rotated180Degrees()
            }
            classificationMilliseconds +=
                PPOCRMonotonicClock.nowMilliseconds - classificationStart

            try Task.checkCancellation()
            let recognitionStart = PPOCRMonotonicClock.nowMilliseconds
            let recognitionTensor = try PPOCRPreprocessor.recognitionTensor(from: lineImage)
            let recognitionOutput = try sessions.recognizer.run(
                tensor: recognitionTensor,
                stage: "recognition"
            )
            guard recognitionOutput.shape.count == 3,
                  recognitionOutput.shape[0] == 1 else {
                throw PPOCRError.invalidOutput("recognitionShape")
            }
            let decoded = try PPOCRCTCDecoder.decode(
                logits: recognitionOutput.values,
                timeSteps: recognitionOutput.shape[1],
                classCount: recognitionOutput.shape[2],
                characters: sessions.characters
            )
            recognitionMilliseconds +=
                PPOCRMonotonicClock.nowMilliseconds - recognitionStart
            if !decoded.text.isEmpty,
               decoded.confidence >= PPOCRConfiguration.textScore {
                textResults.append(PPOCRTextResult(
                    text: decoded.text,
                    confidence: decoded.confidence,
                    boundingBox: Self.boundingBox(
                        for: box,
                        imageSize: cellImage.size
                    )
                ))
            }
        }

        return PPOCRCellRecognitionResult(
            day: region.day,
            sourcePixels: imageSize,
            cropRect: pixelRect,
            paddingApplied: false,
            cellPixels: cellImage.size,
            detectorInputPixels: detectorInputSize,
            results: textResults,
            detectionCount: boxes.count,
            timing: PPOCRCellTiming(
                preprocessMilliseconds: preprocessMilliseconds,
                detectionMilliseconds: detectionMilliseconds,
                detectionPostprocessMilliseconds: detectionPostprocessMilliseconds,
                classificationMilliseconds: classificationMilliseconds,
                recognitionMilliseconds: recognitionMilliseconds,
                totalMilliseconds: PPOCRMonotonicClock.nowMilliseconds - totalStart
            ),
            error: nil
        )
    }

    private func failureRun(
        image: CGImage,
        regions: [CalendarImportDayRegion],
        initializedThisRun: Bool,
        initializationMilliseconds: Double,
        errorCode: String
    ) -> PPOCRRecognitionRun {
        PPOCRRecognitionRun(
            runtimeVersion: PPOCRModelManifest.onnxRuntimeVersion,
            modelInitializedThisRun: initializedThisRun,
            modelInitializationMilliseconds: initializationMilliseconds,
            totalMilliseconds: 0,
            cells: regions.sorted(by: { $0.day < $1.day }).map {
                failureCell(image: image, region: $0, errorCode: errorCode)
            }
        )
    }

    private func failureCell(
        image: CGImage,
        region: CalendarImportDayRegion,
        errorCode: String
    ) -> PPOCRCellRecognitionResult {
        let sourceSize = PPOCRImageSize(width: image.width, height: image.height)
        let pixelRect = PPOCRCellPixelRectConverter.pixelRect(
            for: region.boundingBox,
            imageSize: sourceSize
        )
        let cellSize = pixelRect?.size ?? PPOCRImageSize(width: 0, height: 0)
        return PPOCRCellRecognitionResult(
            day: region.day,
            sourcePixels: sourceSize,
            cropRect: pixelRect,
            paddingApplied: false,
            cellPixels: cellSize,
            detectorInputPixels: nil,
            results: [],
            detectionCount: 0,
            timing: PPOCRCellTiming(
                preprocessMilliseconds: 0,
                detectionMilliseconds: 0,
                detectionPostprocessMilliseconds: 0,
                classificationMilliseconds: 0,
                recognitionMilliseconds: 0,
                totalMilliseconds: 0
            ),
            error: errorCode
        )
    }

    private static func boundingBox(
        for box: PPOCRDetectedBox,
        imageSize: PPOCRImageSize
    ) -> CalendarOCRBoundingBox {
        let xs = box.points.map(\.x)
        let ys = box.points.map(\.y)
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? minX
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? minY
        let width = Double(max(imageSize.width, 1))
        let height = Double(max(imageSize.height, 1))
        return CalendarOCRBoundingBox(
            x: min(max(minX / width, 0), 1),
            y: min(max(1 - maxY / height, 0), 1),
            width: min(max((maxX - minX) / width, 0), 1),
            height: min(max((maxY - minY) / height, 0), 1)
        )
    }
}

private enum PPOCRMonotonicClock {
    static var nowMilliseconds: Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }
}

private enum PPOCRCGImageBridge {
    static func bgrImage(from image: CGImage) throws -> PPOCRBGRImage {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { throw PPOCRError.invalidImage }
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let created = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let baseAddress = bytes.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                  ) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard created else { throw PPOCRError.invalidImage }
        var bgr = [UInt8](repeating: 0, count: width * height * 3)
        for pixelIndex in 0..<(width * height) {
            let rgbaOffset = pixelIndex * 4
            let bgrOffset = pixelIndex * 3
            bgr[bgrOffset] = rgba[rgbaOffset + 2]
            bgr[bgrOffset + 1] = rgba[rgbaOffset + 1]
            bgr[bgrOffset + 2] = rgba[rgbaOffset]
        }
        return try PPOCRBGRImage(width: width, height: height, pixels: bgr)
    }
}

private final class PPOCRONNXSessions {
    let runtimeVersion: String
    let detector: PPOCRONNXSession
    let classifier: PPOCRONNXSession
    let recognizer: PPOCRONNXSession
    let characters: [String]
    private let environment: ORTEnv

    init(bundle: Bundle = .main) throws {
        let runtimeVersion = ORTVersion() ?? "unknown"
        guard runtimeVersion == PPOCRModelManifest.onnxRuntimeVersion else {
            throw PPOCRError.runtimeFailure("versionMismatch")
        }
        self.runtimeVersion = runtimeVersion
        let detectorURL = try Self.resourceURL(
            PPOCRModelManifest.detector,
            bundle: bundle
        )
        let classifierURL = try Self.resourceURL(
            PPOCRModelManifest.classifier,
            bundle: bundle
        )
        let recognizerURL = try Self.resourceURL(
            PPOCRModelManifest.recognizer,
            bundle: bundle
        )
        let characterURL = try Self.characterResourceURL(bundle: bundle)
        let rawCharacters = try String(contentsOf: characterURL, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
            .dropLastWhileEmpty()
        guard rawCharacters.count == 18_708,
              rawCharacters.allSatisfy({ !$0.isEmpty }) else {
            throw PPOCRError.invalidCharacterDictionary
        }
        characters = ["blank"] + rawCharacters + [" "]
        do {
            let environment = try ORTEnv(loggingLevel: .warning)
            self.environment = environment
            detector = try PPOCRONNXSession(environment: environment, modelURL: detectorURL)
            classifier = try PPOCRONNXSession(environment: environment, modelURL: classifierURL)
            recognizer = try PPOCRONNXSession(environment: environment, modelURL: recognizerURL)
        } catch {
            throw PPOCRError.runtimeFailure("modelInit")
        }
    }

    private static func resourceURL(
        _ model: PPOCRModelFile,
        bundle: Bundle
    ) throws -> URL {
        guard let url = bundle.url(
            forResource: model.resourceName,
            withExtension: model.fileExtension
        ) else { throw PPOCRError.missingModel(model.fileName) }
        let byteCount = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
        try PPOCRModelFileValidator.validate(
            fileName: model.fileName,
            actualByteCount: byteCount,
            expectedByteCount: model.byteCount
        )
        return url
    }

    private static func characterResourceURL(bundle: Bundle) throws -> URL {
        let model = PPOCRModelManifest.recognitionCharacters
        guard let url = bundle.url(
            forResource: model.resourceName,
            withExtension: model.fileExtension
        ) else { throw PPOCRError.missingModel(model.fileName) }
        let byteCount = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
        try PPOCRModelFileValidator.validate(
            fileName: model.fileName,
            actualByteCount: byteCount,
            expectedByteCount: model.byteCount
        )
        return url
    }
}

private struct PPOCRTensorOutput {
    let values: [Float]
    let shape: [Int]
}

private final class PPOCRONNXSession {
    private let session: ORTSession
    private let inputName: String
    private let outputName: String

    init(environment: ORTEnv, modelURL: URL) throws {
        let createdSession = try ORTSession(
            env: environment,
            modelPath: modelURL.path,
            sessionOptions: nil
        )
        let inputNames = try createdSession.inputNames()
        let outputNames = try createdSession.outputNames()
        guard inputNames.count == 1, outputNames.count == 1,
              let inputName = inputNames.first,
              let outputName = outputNames.first else {
            throw PPOCRError.invalidModelFile(modelURL.lastPathComponent)
        }
        session = createdSession
        self.inputName = inputName
        self.outputName = outputName
    }

    func run(tensor: PPOCRTensor, stage: String) throws -> PPOCRTensorOutput {
        let data = tensor.values.withUnsafeBufferPointer { Data(buffer: $0) }
        let inputValue = try ORTValue(
            tensorData: NSMutableData(data: data),
            elementType: .float,
            shape: tensor.shape.map { NSNumber(value: $0) }
        )
        let outputs: [String: ORTValue]
        do {
            outputs = try session.run(
                withInputs: [inputName: inputValue],
                outputNames: [outputName],
                runOptions: nil
            )
        } catch {
            throw PPOCRError.runtimeFailure(stage)
        }
        guard let output = outputs[outputName] else {
            throw PPOCRError.invalidOutput(stage)
        }
        let info = try output.tensorTypeAndShapeInfo()
        guard info.elementType == .float else {
            throw PPOCRError.invalidOutput("\(stage)Type")
        }
        let outputData = try output.tensorData() as Data
        let values: [Float] = outputData.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float.self))
        }
        let shape = info.shape.map(\.intValue)
        guard shape.allSatisfy({ $0 >= 0 }),
              shape.reduce(1, *) == values.count else {
            throw PPOCRError.invalidOutput("\(stage)Shape")
        }
        return PPOCRTensorOutput(values: values, shape: shape)
    }
}

private extension Array where Element == String {
    func dropLastWhileEmpty() -> [String] {
        var copy = self
        while copy.last?.isEmpty == true { copy.removeLast() }
        return copy
    }
}
