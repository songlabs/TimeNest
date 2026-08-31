import FirebaseAILogic
import FirebaseCore
import Foundation
import UIKit

struct CalendarGeminiCellRecognitionService {
    private let coordinator = CalendarGeminiCellRecognitionCoordinator(
        maximumConcurrentRequests: 4
    )

    func recognizeMonthCells(
        image: CGImage,
        regions: [CalendarImportDayRegion],
        yearMonth: CalendarImportYearMonth,
        calendarID: UUID,
        languageCode: String
    ) async throws -> CalendarGeminiMonthRecognitionResult {
        let outcomes: [CalendarGeminiCellRecognitionOutcome]
        if FirebaseApp.app() == nil {
            outcomes = try await coordinator.recognize(
                regions: regions,
                requester: CalendarGeminiUnavailableCellRequester()
            )
        } else {
            let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
                modelName: "gemini-2.5-flash"
            )
            outcomes = try await coordinator.recognize(
                regions: regions,
                requester: FirebaseCalendarGeminiCellRequester(
                    image: image,
                    yearMonth: yearMonth,
                    languageCode: languageCode,
                    model: model
                )
            )
        }
        return try CalendarGeminiMonthResultBuilder().makeResult(
            outcomes: outcomes,
            yearMonth: yearMonth,
            calendarID: calendarID
        )
    }
}

private struct CalendarGeminiUnavailableCellRequester: CalendarGeminiCellRequesting {
    func recognizeCell(
        in region: CalendarImportDayRegion
    ) async throws -> [CalendarGeminiRecognizedEvent] {
        throw CalendarGeminiRecognitionError.firebaseNotConfigured
    }
}

private struct FirebaseCalendarGeminiCellRequester: CalendarGeminiCellRequesting {
    let image: CGImage
    let yearMonth: CalendarImportYearMonth
    let languageCode: String
    let model: GenerativeModel

    private let timeoutSeconds: UInt64 = 20

    func recognizeCell(
        in region: CalendarImportDayRegion
    ) async throws -> [CalendarGeminiRecognizedEvent] {
        guard let crop = crop(region.boundingBox, from: image) else {
            throw CalendarGeminiRecognitionError.invalidCrop
        }
        let cellImage = UIImage(cgImage: crop)
        let response = try await withTimeout {
            do {
                return try await model.generateContent(
                    prompt(
                        day: region.day,
                        yearMonth: yearMonth,
                        languageCode: languageCode
                    ),
                    cellImage
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let diagnosticError = Self.diagnosticError(from: error)
                throw CalendarGeminiRequestFailure(
                    category: CalendarGeminiErrorCategory.classify(diagnosticError),
                    diagnostics: CalendarGeminiErrorDiagnostics(error: diagnosticError)
                )
            }
        }
        guard let text = response.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CalendarGeminiRecognitionError.emptyResponse
        }
        return try CalendarGeminiResponseDecoder.decode(text)
    }

    private func prompt(
        day: Int,
        yearMonth: CalendarImportYearMonth,
        languageCode: String
    ) -> String {
        """
        This image is exactly one calendar cell for \(yearMonth.year)-\(String(format: "%02d", yearMonth.month))-\(String(format: "%02d", day)).
        The app calculated this date from grid position. Do not detect, infer, return, or correct the date.
        Identify only schedules added by the user, especially handwriting. Ignore the printed day number, weekday, holiday names, lunar-calendar text, decorations, and all other preprinted calendar text. If there is no user-added schedule, return {"events":[]}.
        Keep separate schedules as separate array items. Do not merge them. Read ranges such as 17:30-20:30 precisely. Never invent missing text or time. A schedule without a written time is all-day and uses null times.
        Respond with JSON only, without Markdown:
        {"events":[{"title":"string","original_text":"string","start_minutes":1050,"end_minutes":1230,"confidence":0.0}]}
        Times are minutes after midnight, or null. Confidence is 0 through 1. Preserve the writing's language; UI language hint: \(languageCode).
        """
    }

    private func crop(_ box: CalendarOCRBoundingBox, from image: CGImage) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let rect = CGRect(
            x: ceil(CGFloat(box.minX) * width),
            y: ceil(CGFloat(1 - box.maxY) * height),
            width: floor(CGFloat(box.width) * width),
            height: floor(CGFloat(box.height) * height)
        ).intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard rect.width >= 2, rect.height >= 2 else { return nil }
        return image.cropping(to: rect)
    }

    private static func diagnosticError(from error: Error) -> Error {
        guard let generateContentError = error as? GenerateContentError else {
            return error
        }
        switch generateContentError {
        case let .internalError(underlying),
             let .promptImageContentError(underlying):
            return diagnosticError(from: underlying)
        case .promptBlocked, .responseStoppedEarly:
            return error
        }
    }

    private func withTimeout<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                throw CalendarGeminiRecognitionError.timedOut
            }
            guard let result = try await group.next() else {
                throw CalendarGeminiRecognitionError.timedOut
            }
            group.cancelAll()
            return result
        }
    }
}
