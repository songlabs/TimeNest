import CoreGraphics
import Foundation
import Vision

actor PPOCRService {
    private var sessions: PPOCRONNXSessions?

    // The bundled ONNX recognizers are fixed models and do not consume a
    // language hint. ocrLanguage is forwarded only to the Vision time-recovery
    // path, which has a real recognitionLanguages API.
    func recognizeMonthCells(
        image: CGImage,
        regions: [CalendarImportDayRegion],
        ocrLanguage: CalendarOCRLanguage
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
                    sessions: loadedSessions,
                    ocrLanguage: ocrLanguage
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
            modelInitializationMilliseconds: loadedSessions.currentInitializationMilliseconds,
            totalMilliseconds: PPOCRMonotonicClock.nowMilliseconds - recognitionStart,
            recognitionModelPOC: PPOCRRecognitionModelPOC(
                currentModel: PPOCRModelManifest.recognizer.displayName,
                candidateModel: PPOCRModelManifest.candidateRecognizer.displayName,
                currentInitializedThisRun: modelInitializedThisRun,
                candidateInitializedThisRun: modelInitializedThisRun
                    && loadedSessions.candidateRecognizer != nil,
                currentInitializationMilliseconds:
                    loadedSessions.currentInitializationMilliseconds,
                candidateInitializationMilliseconds:
                    loadedSessions.candidateInitializationMilliseconds,
                candidateInitializationError:
                    loadedSessions.candidateInitializationError,
                currentTotalMilliseconds: cells
                    .flatMap(\.recognitionModelComparisons)
                    .map(\.currentMilliseconds)
                    .reduce(0, +),
                candidateTotalMilliseconds: cells
                    .flatMap(\.recognitionModelComparisons)
                    .compactMap(\.candidateMilliseconds)
                    .reduce(0, +)
            ),
            cells: cells
        )
    }

    private func inferCell(
        image: CGImage,
        region: CalendarImportDayRegion,
        sessions: PPOCRONNXSessions,
        ocrLanguage: CalendarOCRLanguage,
        allowsUpscaleRetry: Bool = true,
        cellImageOverride: PPOCRBGRImage? = nil
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
        let cellImage: PPOCRBGRImage
        if let cellImageOverride {
            guard cellImageOverride.size == pixelRect.size else {
                throw PPOCRError.invalidCrop
            }
            cellImage = cellImageOverride
        } else {
            cellImage = try PPOCRCGImageBridge.bgrImage(from: crop)
        }
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
        var modelComparisons: [PPOCRRecognitionModelComparison] = []
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
            let rotatesLine = predictedAngleIndex == 1
                && predictedAngleScore > PPOCRConfiguration.classificationThreshold
            if rotatesLine {
                lineImage = try lineImage.rotated180Degrees()
            }
            classificationMilliseconds +=
                PPOCRMonotonicClock.nowMilliseconds - classificationStart

            try Task.checkCancellation()
            let recognitionTensor = try PPOCRPreprocessor.recognitionTensor(from: lineImage)
            let currentStart = PPOCRMonotonicClock.nowMilliseconds
            let decoded = try Self.recognize(
                tensor: recognitionTensor,
                session: sessions.recognizer,
                characters: sessions.characters,
                stage: "recognition"
            )
            let currentMilliseconds = PPOCRMonotonicClock.nowMilliseconds - currentStart
            recognitionMilliseconds += currentMilliseconds
            let localBoundingBox = PPOCRNormalizedBoxConverter.boundingBox(
                for: box,
                imageSize: cellImage.size
            )

            let candidateDecoded: PPOCRDecodedText?
            let candidateMilliseconds: Double?
            let candidateError: String?
            if let candidateRecognizer = sessions.candidateRecognizer {
                let candidateStart = PPOCRMonotonicClock.nowMilliseconds
                do {
                    candidateDecoded = try Self.recognize(
                        tensor: recognitionTensor,
                        session: candidateRecognizer,
                        characters: sessions.candidateCharacters,
                        stage: "candidateRecognition"
                    )
                    candidateMilliseconds =
                        PPOCRMonotonicClock.nowMilliseconds - candidateStart
                    candidateError = nil
                } catch let error as PPOCRError {
                    candidateDecoded = nil
                    candidateMilliseconds =
                        PPOCRMonotonicClock.nowMilliseconds - candidateStart
                    candidateError = error.diagnosticCode
                } catch {
                    candidateDecoded = nil
                    candidateMilliseconds =
                        PPOCRMonotonicClock.nowMilliseconds - candidateStart
                    candidateError = "runtimeFailure:candidateRecognition"
                }
            } else {
                candidateDecoded = nil
                candidateMilliseconds = nil
                candidateError = sessions.candidateInitializationError
                    ?? "runtimeFailure:candidateModelUnavailable"
            }
            let currentAlternative = PPOCRRecognitionAlternative(
                text: decoded.text,
                confidence: decoded.confidence
            )
            let candidateAlternative = candidateDecoded.map {
                PPOCRRecognitionAlternative(text: $0.text, confidence: $0.confidence)
            }
            let recoveryReason = PPOCRTimeRecoveryPolicy.reason(
                text: decoded.text,
                confidence: decoded.confidence
            )
            var enhancedDecoded: PPOCRDecodedText?
            var enhancedMilliseconds: Double?
            var enhancedError: String?
            var recoveryImage: PPOCRBGRImage?
            if recoveryReason != nil {
                let enhancedStart = PPOCRMonotonicClock.nowMilliseconds
                do {
                    let expandedPoints = PPOCRDetectionCropper.expandedPoints(
                        box.points,
                        imageSize: cellImage.size
                    )
                    var enhancedLine = try cellImage.perspectiveCrop(points: expandedPoints)
                    if rotatesLine {
                        enhancedLine = try enhancedLine.rotated180Degrees()
                    }
                    enhancedLine = try enhancedLine.timeRecoveryEnhanced()
                    recoveryImage = enhancedLine
                    let enhancedTensor = try PPOCRPreprocessor.recognitionTensor(
                        from: enhancedLine
                    )
                    enhancedDecoded = try Self.recognize(
                        tensor: enhancedTensor,
                        session: sessions.recognizer,
                        characters: sessions.characters,
                        stage: "enhancedRecognition"
                    )
                    enhancedMilliseconds = PPOCRMonotonicClock.nowMilliseconds - enhancedStart
                } catch let error as PPOCRError {
                    enhancedMilliseconds = PPOCRMonotonicClock.nowMilliseconds - enhancedStart
                    enhancedError = error.diagnosticCode
                } catch {
                    enhancedMilliseconds = PPOCRMonotonicClock.nowMilliseconds - enhancedStart
                    enhancedError = "runtimeFailure:enhancedRecognition"
                }
            }
            let enhancedAlternative = enhancedDecoded.map {
                PPOCRRecognitionAlternative(text: $0.text, confidence: $0.confidence)
            }
            var selection: PPOCRTimeRecognitionSelection
            if recoveryReason == nil {
                selection = PPOCRTimeRecognitionSelection(
                    alternative: currentAlternative,
                    source: .currentPPocr,
                    selectionReason: CalendarImportTimeParser.parseMonth(decoded.text) == nil
                        ? "recoveryNotTriggered"
                        : "currentValidTime"
                )
            } else {
                selection = PPOCRTimeRecoveryPolicy.select(
                    current: currentAlternative,
                    enhanced: enhancedAlternative,
                    candidate: candidateAlternative,
                    vision: nil
                )
            }
            var visionAlternative: PPOCRRecognitionAlternative?
            var visionLocalizedAlternative: PPOCRLocalizedRecognitionAlternative?
            var visionInputImage: PPOCRBGRImage?
            var visionMilliseconds: Double?
            var visionError: String?
            if recoveryReason != nil,
               selection.source == .currentPPocr,
               CalendarImportTimeParser.parseMonth(decoded.text) == nil {
                let visionStart = PPOCRMonotonicClock.nowMilliseconds
                do {
                    let inputImage = try recoveryImage ?? lineImage.timeRecoveryEnhanced()
                    visionInputImage = inputImage
                    let visionImage = try PPOCRCGImageBridge.cgImage(from: inputImage)
                    visionLocalizedAlternative = try PPOCRVisionTimeRecognizer.recognize(
                        image: visionImage,
                        ocrLanguage: ocrLanguage
                    )
                    visionAlternative = visionLocalizedAlternative?.alternative
                    visionMilliseconds = PPOCRMonotonicClock.nowMilliseconds - visionStart
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    visionMilliseconds = PPOCRMonotonicClock.nowMilliseconds - visionStart
                    visionError = "runtimeFailure:visionSecondary"
                }
                selection = PPOCRTimeRecoveryPolicy.select(
                    current: currentAlternative,
                    enhanced: enhancedAlternative,
                    candidate: candidateAlternative,
                    vision: visionAlternative
                )
            }
            var timeFocusedRecoveryAttempted = false
            var timeFocusedCrop: CalendarOCRBoundingBox?
            var timeFocusedPPocrAlternative: PPOCRRecognitionAlternative?
            var timeFocusedPPocrMilliseconds: Double?
            var timeFocusedPPocrError: String?
            var timeFocusedVisionAlternative: PPOCRRecognitionAlternative?
            var timeFocusedVisionMilliseconds: Double?
            var timeFocusedVisionError: String?
            var timeFocusedSelectionReason = "notAttempted"
            // Only a failed recovery with bounded time-like OCR evidence reaches
            // this path. Vision's own observation bounds localize the pixels;
            // the strict month range parser remains the acceptance gate.
            if recoveryReason != nil,
               selection.source == .currentPPocr,
               CalendarImportTimeParser.parseMonth(decoded.text) == nil,
               PPOCRTimeRecoveryPolicy.shouldAttemptTimeFocusedRecovery(
                   current: currentAlternative,
                   enhanced: enhancedAlternative,
                   candidate: candidateAlternative,
                   vision: visionAlternative
               ) {
                timeFocusedRecoveryAttempted = true
                if let localized = visionLocalizedAlternative,
                   PPOCRTimeRecoveryPolicy.isTimeLikeEvidence(
                       localized.alternative.text
                   ),
                   let inputImage = visionInputImage {
                    do {
                        if let focusedCrop = try PPOCRTimeFocusedCropper.crop(
                            inputImage,
                            around: localized.boundingBox
                        ) {
                            timeFocusedCrop = focusedCrop.boundingBox
                            try Task.checkCancellation()
                            let ppocrStart = PPOCRMonotonicClock.nowMilliseconds
                            do {
                                let tensor = try PPOCRPreprocessor.recognitionTensor(
                                    from: focusedCrop.image
                                )
                                let focusedDecoded = try Self.recognize(
                                    tensor: tensor,
                                    session: sessions.recognizer,
                                    characters: sessions.characters,
                                    stage: "timeFocusedRecognition"
                                )
                                timeFocusedPPocrAlternative = PPOCRRecognitionAlternative(
                                    text: focusedDecoded.text,
                                    confidence: focusedDecoded.confidence
                                )
                                timeFocusedPPocrMilliseconds =
                                    PPOCRMonotonicClock.nowMilliseconds - ppocrStart
                            } catch let error as PPOCRError {
                                timeFocusedPPocrMilliseconds =
                                    PPOCRMonotonicClock.nowMilliseconds - ppocrStart
                                timeFocusedPPocrError = error.diagnosticCode
                            } catch {
                                timeFocusedPPocrMilliseconds =
                                    PPOCRMonotonicClock.nowMilliseconds - ppocrStart
                                timeFocusedPPocrError =
                                    "runtimeFailure:timeFocusedRecognition"
                            }

                            selection = PPOCRTimeRecoveryPolicy.select(
                                current: currentAlternative,
                                enhanced: enhancedAlternative,
                                candidate: candidateAlternative,
                                vision: visionAlternative,
                                timeFocusedPPocr: timeFocusedPPocrAlternative
                            )
                            if selection.source == .timeFocusedPPocr {
                                timeFocusedSelectionReason = "validFocusedRangeSelected"
                            } else {
                                try Task.checkCancellation()
                                let focusedVisionStart =
                                    PPOCRMonotonicClock.nowMilliseconds
                                do {
                                    let focusedVisionImage = try PPOCRCGImageBridge.cgImage(
                                        from: focusedCrop.image
                                    )
                                    timeFocusedVisionAlternative = try
                                        PPOCRVisionTimeRecognizer.recognize(
                                            image: focusedVisionImage,
                                            ocrLanguage: ocrLanguage
                                        )?.alternative
                                    timeFocusedVisionMilliseconds =
                                        PPOCRMonotonicClock.nowMilliseconds
                                            - focusedVisionStart
                                } catch is CancellationError {
                                    throw CancellationError()
                                } catch {
                                    timeFocusedVisionMilliseconds =
                                        PPOCRMonotonicClock.nowMilliseconds
                                            - focusedVisionStart
                                    timeFocusedVisionError =
                                        "runtimeFailure:timeFocusedVision"
                                }
                                selection = PPOCRTimeRecoveryPolicy.select(
                                    current: currentAlternative,
                                    enhanced: enhancedAlternative,
                                    candidate: candidateAlternative,
                                    vision: visionAlternative,
                                    timeFocusedPPocr: timeFocusedPPocrAlternative,
                                    timeFocusedVision: timeFocusedVisionAlternative
                                )
                                timeFocusedSelectionReason = [
                                    PPOCRTimeRecognitionSource.timeFocusedPPocr,
                                    .timeFocusedVision
                                ].contains(selection.source)
                                    ? "validFocusedRangeSelected"
                                    : "noValidFocusedResult"
                            }
                        } else {
                            timeFocusedSelectionReason = "noDistinctVisionTimeCrop"
                        }
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch let error as PPOCRError {
                        timeFocusedSelectionReason = "focusedCropFailed"
                        timeFocusedPPocrError = error.diagnosticCode
                    } catch {
                        timeFocusedSelectionReason = "focusedCropFailed"
                        timeFocusedPPocrError = "runtimeFailure:timeFocusedCrop"
                    }
                } else {
                    timeFocusedSelectionReason = "noLocalizedVisionTimeEvidence"
                }
            }
            let comparison = PPOCRRecognitionModelComparison(
                boundingBox: localBoundingBox,
                currentText: decoded.text,
                currentConfidence: decoded.confidence,
                currentMilliseconds: currentMilliseconds,
                recoveryAttempted: recoveryReason != nil,
                recoveryReason: recoveryReason,
                enhancedText: enhancedDecoded?.text,
                enhancedConfidence: enhancedDecoded?.confidence,
                enhancedMilliseconds: enhancedMilliseconds,
                enhancedError: enhancedError,
                candidateText: candidateDecoded?.text,
                candidateConfidence: candidateDecoded?.confidence,
                candidateMilliseconds: candidateMilliseconds,
                candidateError: candidateError,
                visionText: visionAlternative?.text,
                visionConfidence: visionAlternative?.confidence,
                visionMilliseconds: visionMilliseconds,
                visionError: visionError,
                timeFocusedRecoveryAttempted: timeFocusedRecoveryAttempted,
                timeFocusedCrop: timeFocusedCrop,
                timeFocusedPPocrText: timeFocusedPPocrAlternative?.text,
                timeFocusedPPocrConfidence: timeFocusedPPocrAlternative?.confidence,
                timeFocusedPPocrMilliseconds: timeFocusedPPocrMilliseconds,
                timeFocusedPPocrError: timeFocusedPPocrError,
                timeFocusedVisionText: timeFocusedVisionAlternative?.text,
                timeFocusedVisionConfidence: timeFocusedVisionAlternative?.confidence,
                timeFocusedVisionMilliseconds: timeFocusedVisionMilliseconds,
                timeFocusedVisionError: timeFocusedVisionError,
                timeFocusedSelectionReason: timeFocusedSelectionReason,
                selectedText: selection.alternative.text,
                selectedSource: selection.source,
                selectionReason: selection.selectionReason
            )
            modelComparisons.append(comparison)
            let selectedTime = CalendarImportTimeParser.parseMonth(selection.alternative.text)
            let passesTextScore = selection.alternative.confidence
                >= PPOCRConfiguration.textScore
            let recoveredValidTime = selection.isRecovered && selectedTime != nil
            if !selection.alternative.text.isEmpty, passesTextScore || recoveredValidTime {
                textResults.append(PPOCRTextResult(
                    text: selection.alternative.text,
                    confidence: selection.alternative.confidence,
                    boundingBox: localBoundingBox,
                    timeParseQualityOverride: selection.isRecovered ? .recovered : nil,
                    candidateDiagnostics: comparison.calendarOCRCandidates,
                    selectionReason: comparison.selectionReason
                ))
            }
        }

        let primaryResult = PPOCRCellRecognitionResult(
            day: region.day,
            sourcePixels: imageSize,
            cropRect: pixelRect,
            paddingApplied: false,
            cellPixels: cellImage.size,
            detectorInputPixels: detectorInputSize,
            results: textResults,
            recognitionModelComparisons: modelComparisons,
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
        guard allowsUpscaleRetry else { return primaryResult }

        // Bounded POC: only a still-unresolved 1x detection reaches this runner.
        // Each retry starts from the whole Cell and re-enters this same detector,
        // classifier, perspective-crop, recognizer, and recovery pipeline.
        let upscaleRecovery = try PPOCRCellUpscaleRecoveryRunner.run(
            original: primaryResult,
            pipeline: { scaleFactor in
                let scaledCellImage = try cellImage.upscaled(by: scaleFactor)
                let scaledCGImage = try PPOCRCGImageBridge.cgImage(from: scaledCellImage)
                return try inferCell(
                    image: scaledCGImage,
                    region: CalendarImportDayRegion(
                        day: region.day,
                        boundingBox: CalendarOCRBoundingBox(
                            x: 0,
                            y: 0,
                            width: 1,
                            height: 1
                        )
                    ),
                    sessions: sessions,
                    ocrLanguage: ocrLanguage,
                    allowsUpscaleRetry: false,
                    cellImageOverride: scaledCellImage
                )
            }
        )
        guard upscaleRecovery.attempted else { return primaryResult }
        return PPOCRCellRecognitionResult(
            day: primaryResult.day,
            sourcePixels: primaryResult.sourcePixels,
            cropRect: primaryResult.cropRect,
            paddingApplied: primaryResult.paddingApplied,
            cellPixels: primaryResult.cellPixels,
            detectorInputPixels: primaryResult.detectorInputPixels,
            results: primaryResult.results + upscaleRecovery.recoveredResults,
            recognitionModelComparisons: primaryResult.recognitionModelComparisons,
            detectionCount: primaryResult.detectionCount,
            timing: primaryResult.timing,
            error: primaryResult.error,
            cellUpscaleRecoveryAttempted: true,
            cellUpscaleAttempts: upscaleRecovery.attempts,
            cellUpscaleSelectedScale: upscaleRecovery.selectedScale
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
            recognitionModelPOC: PPOCRRecognitionModelPOC(
                currentModel: PPOCRModelManifest.recognizer.displayName,
                candidateModel: PPOCRModelManifest.candidateRecognizer.displayName,
                currentInitializedThisRun: false,
                candidateInitializedThisRun: false,
                currentInitializationMilliseconds: initializationMilliseconds,
                candidateInitializationMilliseconds: 0,
                candidateInitializationError: "notAttempted:currentModelInit",
                currentTotalMilliseconds: 0,
                candidateTotalMilliseconds: 0
            ),
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
            recognitionModelComparisons: [],
            detectionCount: 0,
            timing: PPOCRCellTiming(
                preprocessMilliseconds: 0,
                detectionMilliseconds: 0,
                detectionPostprocessMilliseconds: 0,
                classificationMilliseconds: 0,
                recognitionMilliseconds: 0,
                totalMilliseconds: 0
            ),
            error: errorCode,
            cellUpscaleSelectedScale: .none
        )
    }

    private static func recognize(
        tensor: PPOCRTensor,
        session: PPOCRONNXSession,
        characters: [String],
        stage: String
    ) throws -> PPOCRDecodedText {
        let output = try session.run(tensor: tensor, stage: stage)
        guard output.shape.count == 3,
              output.shape[0] == 1,
              output.shape[2] == characters.count else {
            throw PPOCRError.invalidOutput("\(stage)Shape")
        }
        return try PPOCRCTCDecoder.decode(
            logits: output.values,
            timeSteps: output.shape[1],
            classCount: output.shape[2],
            characters: characters
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

    static func cgImage(from image: PPOCRBGRImage) throws -> CGImage {
        var rgba = [UInt8](repeating: 255, count: image.width * image.height * 4)
        for pixelIndex in 0..<(image.width * image.height) {
            let bgrOffset = pixelIndex * 3
            let rgbaOffset = pixelIndex * 4
            rgba[rgbaOffset] = image.pixels[bgrOffset + 2]
            rgba[rgbaOffset + 1] = image.pixels[bgrOffset + 1]
            rgba[rgbaOffset + 2] = image.pixels[bgrOffset]
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let output = CGImage(
                  width: image.width,
                  height: image.height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: image.width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(
                      rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                  ).union(.byteOrder32Big),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            throw PPOCRError.invalidImage
        }
        return output
    }
}

private enum PPOCRVisionTimeRecognizer {
    static func recognize(
        image: CGImage,
        ocrLanguage: CalendarOCRLanguage
    ) throws -> PPOCRLocalizedRecognitionAlternative? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = false
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let preferred = ocrLanguage.preferredVisionRecognitionLanguages(
            supported: supported
        )
        guard !preferred.isEmpty else {
            throw CalendarOCRLanguageError.unsupportedByVision(
                ocrLanguage.visionRecognitionLanguageCode
            )
        }
        request.recognitionLanguages = preferred
        try VNImageRequestHandler(
            cgImage: image,
            orientation: .up,
            options: [:]
        ).perform([request])
        let alternatives = (request.results ?? []).flatMap { observation in
            observation.topCandidates(5).map { candidate in
                let timeLikeRange = PPOCRTimeRecoveryPolicy.timeLikeEvidenceRange(
                    in: candidate.string
                )
                let localizedTime = timeLikeRange.flatMap {
                    try? candidate.boundingBox(for: $0)
                }
                let box = localizedTime?.boundingBox ?? observation.boundingBox
                return PPOCRLocalizedRecognitionAlternative(
                    alternative: PPOCRRecognitionAlternative(
                        text: candidate.string,
                        confidence: candidate.confidence
                    ),
                    boundingBox: CalendarOCRBoundingBox(
                        x: Double(box.origin.x),
                        y: Double(box.origin.y),
                        width: Double(box.width),
                        height: Double(box.height)
                    )
                )
            }
        }
        return PPOCRTimeRecoveryPolicy.preferredLocalizedVisionAlternative(alternatives)
    }

}

private final class PPOCRONNXSessions {
    let runtimeVersion: String
    let detector: PPOCRONNXSession
    let classifier: PPOCRONNXSession
    let recognizer: PPOCRONNXSession
    let characters: [String]
    let candidateRecognizer: PPOCRONNXSession?
    let candidateCharacters: [String]
    let currentInitializationMilliseconds: Double
    let candidateInitializationMilliseconds: Double
    let candidateInitializationError: String?
    private let environment: ORTEnv

    init(bundle: Bundle = .main) throws {
        let currentStart = PPOCRMonotonicClock.nowMilliseconds
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
        characters = try Self.characters(
            model: PPOCRModelManifest.recognitionCharacters,
            expectedCount: PPOCRModelManifest.recognitionCharacterCount,
            bundle: bundle
        )
        let sharedEnvironment: ORTEnv
        do {
            let environment = try ORTEnv(loggingLevel: .warning)
            sharedEnvironment = environment
            self.environment = environment
            detector = try PPOCRONNXSession(environment: environment, modelURL: detectorURL)
            classifier = try PPOCRONNXSession(environment: environment, modelURL: classifierURL)
            recognizer = try PPOCRONNXSession(environment: environment, modelURL: recognizerURL)
        } catch {
            throw PPOCRError.runtimeFailure("modelInit")
        }
        currentInitializationMilliseconds =
            PPOCRMonotonicClock.nowMilliseconds - currentStart

        let candidateStart = PPOCRMonotonicClock.nowMilliseconds
        var candidateRecognizerValue: PPOCRONNXSession? = nil
        var candidateCharactersValue: [String] = []
        var candidateInitializationErrorValue: String? = nil
        do {
            let candidateRecognizerURL = try Self.resourceURL(
                PPOCRModelManifest.candidateRecognizer,
                bundle: bundle
            )
            let characters = try Self.characters(
                model: PPOCRModelManifest.candidateRecognitionCharacters,
                expectedCount: PPOCRModelManifest.candidateRecognitionCharacterCount,
                bundle: bundle
            )
            let recognizer = try PPOCRONNXSession(
                environment: sharedEnvironment,
                modelURL: candidateRecognizerURL
            )
            candidateRecognizerValue = recognizer
            candidateCharactersValue = characters
        } catch let error as PPOCRError {
            candidateInitializationErrorValue = error.diagnosticCode
        } catch {
            candidateInitializationErrorValue = "runtimeFailure:candidateModelInit"
        }
        candidateRecognizer = candidateRecognizerValue
        candidateCharacters = candidateCharactersValue
        candidateInitializationError = candidateInitializationErrorValue
        candidateInitializationMilliseconds =
            PPOCRMonotonicClock.nowMilliseconds - candidateStart
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

    private static func characters(
        model: PPOCRModelFile,
        expectedCount: Int,
        bundle: Bundle
    ) throws -> [String] {
        let url = try resourceURL(model, bundle: bundle)
        let rawCharacters = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
            .dropLastWhileEmpty()
        guard rawCharacters.count == expectedCount,
              rawCharacters.allSatisfy({ !$0.isEmpty }) else {
            throw PPOCRError.invalidCharacterDictionary
        }
        return ["blank"] + rawCharacters + [" "]
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
