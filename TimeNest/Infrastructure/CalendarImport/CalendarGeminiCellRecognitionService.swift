import FirebaseAI
import FirebaseCore
import Foundation
import UIKit

enum CalendarGeminiRecognitionError: Error {
    case firebaseNotConfigured
    case invalidCrop
    case emptyResponse
    case invalidResponse
    case timedOut
}

struct CalendarGeminiCellRecognitionService {
    private let timeoutSeconds: UInt64 = 20

    func recognizeMonthCells(
        image: CGImage,
        regions: [CalendarImportDayRegion],
        yearMonth: CalendarImportYearMonth,
        calendarID: UUID,
        languageCode: String
    ) async throws -> [CalendarImportCandidate] {
        try configureFirebaseIfNeeded()
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: "gemini-2.5-flash"
        )
        var candidates: [CalendarImportCandidate] = []
        let calendar = Calendar(identifier: .gregorian)
        guard let monthStart = yearMonth.date(calendar: calendar) else {
            throw CalendarGeminiRecognitionError.invalidResponse
        }

        // One locally dated cell per request: model output can never change its date.
        for region in regions {
            guard let crop = crop(region.boundingBox, from: image) else {
                throw CalendarGeminiRecognitionError.invalidCrop
            }
            let cellImage = UIImage(cgImage: crop)
            let response = try await withTimeout {
                try await model.generateContent(
                    prompt(day: region.day, yearMonth: yearMonth, languageCode: languageCode),
                    cellImage
                )
            }
            guard let text = response.text, !text.isEmpty else {
                throw CalendarGeminiRecognitionError.emptyResponse
            }
            let events = try CalendarGeminiResponseDecoder.decode(text)
            guard let date = calendar.date(byAdding: .day, value: region.day - 1, to: monthStart) else {
                continue
            }
            candidates.append(contentsOf: events.map { event in
                CalendarImportCandidate(
                    id: UUID(), date: date,
                    startTimeMinutes: event.startMinutes,
                    endTimeMinutes: event.endMinutes,
                    title: event.title, originalText: event.originalText,
                    personToken: nil, confidence: event.confidence,
                    isSelected: true,
                    needsReview: event.confidence < 0.75 || event.title.isEmpty,
                    targetCalendarID: calendarID,
                    includesPersonTokenInTitle: false
                )
            })
        }
        return candidates
    }

    private func configureFirebaseIfNeeded() throws {
        guard FirebaseApp.app() == nil else { return }
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path) else {
            throw CalendarGeminiRecognitionError.firebaseNotConfigured
        }
        FirebaseApp.configure(options: options)
    }

    private func prompt(day: Int, yearMonth: CalendarImportYearMonth, languageCode: String) -> String {
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
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let rect = CGRect(
            x: ceil(CGFloat(box.minX) * width),
            y: ceil(CGFloat(1 - box.maxY) * height),
            width: floor(CGFloat(box.width) * width),
            height: floor(CGFloat(box.height) * height)
        ).intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard rect.width >= 2, rect.height >= 2 else { return nil }
        return image.cropping(to: rect)
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
