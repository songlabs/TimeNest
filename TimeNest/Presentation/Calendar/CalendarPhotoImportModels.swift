import Foundation

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
}

struct CalendarPhotoOrientationSelector {
    func selectBest(
        from candidates: [CalendarPhotoOrientationCandidate],
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> CalendarPhotoOrientationSelection? {
        let parser = CalendarPhotoParser()
        return candidates.map { candidate in
            CalendarPhotoOrientationSelection(
                rotation: candidate.rotation,
                observations: candidate.observations,
                evidence: parser.orientationEvidence(
                    observations: candidate.observations,
                    calendar: calendar
                )
            )
        }.max { lhs, rhs in
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
        }
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

struct CalendarImportParsedTime: Equatable, Sendable {
    let startMinutes: Int
    let endMinutes: Int?
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

enum CalendarPhotoImportParseError: Error, Equatable {
    case noText
    case noDateStructure
    case noCandidates
}

struct CalendarImportTimeParser {
    private struct MatchResult {
        let time: CalendarImportParsedTime
        let range: NSRange
    }

    static func parse(_ text: String) -> CalendarImportParsedTime? {
        match(in: text)?.time
    }

    static func removingTime(from text: String) -> String {
        guard let match = match(in: text),
              let range = Range(match.range, in: text) else {
            return text
        }
        var result = text
        result.removeSubrange(range)
        return result
    }

    private static func match(in text: String) -> MatchResult? {
        let clockPattern = #"(?<!\d)(\d{1,2})\s*[:：]\s*(\d{2})(?:\s*[-–—〜～~]\s*(\d{1,2})\s*[:：]\s*(\d{2}))?(?!\d)"#
        if let match = firstMatch(pattern: clockPattern, text: text),
           let parsed = parsedTime(match: match, text: text) {
            return MatchResult(time: parsed, range: match.range)
        }

        let japanesePattern = #"(?<!\d)(\d{1,2})\s*時\s*(\d{1,2})\s*分(?:\s*[-–—〜～~]\s*(\d{1,2})\s*時\s*(\d{1,2})\s*分)?(?!\d)"#
        if let match = firstMatch(pattern: japanesePattern, text: text),
           let parsed = parsedTime(match: match, text: text) {
            return MatchResult(time: parsed, range: match.range)
        }
        return nil
    }

    private static func firstMatch(pattern: String, text: String) -> NSTextCheckingResult? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range)
    }

    private static func parsedTime(
        match: NSTextCheckingResult,
        text: String
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
            endMinutes: end
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

    func parse(
        observations: [CalendarOCRObservation],
        overridingYearMonth: CalendarImportYearMonth? = nil,
        defaultCalendarID: UUID,
        calendar inputCalendar: Calendar = Calendar(identifier: .gregorian)
    ) throws -> CalendarPhotoImportParseResult {
        let meaningful = observations.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !meaningful.isEmpty else { throw CalendarPhotoImportParseError.noText }

        let numericAnchors = meaningful.compactMap(Self.dateAnchor)
        guard Set(numericAnchors.map(\.day)).count >= 7 else {
            throw CalendarPhotoImportParseError.noDateStructure
        }

        let yearMonth = overridingYearMonth ?? Self.inferYearMonth(from: meaningful)
        guard let yearMonth else {
            return CalendarPhotoImportParseResult(
                yearMonth: nil,
                candidates: [],
                dayRegions: []
            )
        }

        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        guard let monthStart = yearMonth.date(calendar: calendar),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart),
              let fit = fitGrid(
                anchors: numericAnchors,
                monthStart: monthStart,
                dayCount: dayRange.count,
                calendar: calendar
              ) else {
            throw CalendarPhotoImportParseError.noDateStructure
        }

        let regions = makeDayRegions(
            fit: fit,
            dayCount: dayRange.count
        )
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
        guard !candidates.isEmpty else { throw CalendarPhotoImportParseError.noCandidates }
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
        let reliableText = observations
            .filter { $0.confidence >= 0.4 }
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

        guard matches.count == 1,
              let value = matches.first else { return nil }
        let components = value.split(separator: "-").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        return CalendarImportYearMonth(year: components[0], month: components[1])
    }

    func orientationEvidence(
        observations: [CalendarOCRObservation],
        calendar inputCalendar: Calendar = Calendar(identifier: .gregorian)
    ) -> CalendarPhotoOrientationEvidence {
        let meaningful = observations.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let reliableTextCount = meaningful.filter { $0.confidence >= 0.4 }.count
        let numericAnchors = meaningful.compactMap(Self.dateAnchor)
        let dateAnchorCount = Set(numericAnchors.map(\.day)).count
        let yearMonth = Self.inferYearMonth(from: meaningful)

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

    private func fitGrid(
        anchors: [DateAnchor],
        monthStart: Date,
        dayCount: Int,
        calendar: Calendar
    ) -> GridFit? {
        let firstColumns = [
            Self.column(
                for: monthStart,
                weekStartsOnMonday: false,
                calendar: calendar
            ),
            Self.column(
                for: monthStart,
                weekStartsOnMonday: true,
                calendar: calendar
            )
        ]
        return fitGrid(
            anchors: anchors,
            dayCount: dayCount,
            firstColumns: firstColumns
        )
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
        firstColumns: [Int]
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
                guard matched.count >= 7,
                      distinctRows.count >= 2,
                      distinctColumns.count >= 4 else {
                    continue
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
                guard !originalText.isEmpty else { continue }

                let time = CalendarImportTimeParser.parse(originalText)
                let personToken = Self.personToken(in: originalText)
                var title = CalendarImportTimeParser.removingTime(from: originalText)
                if let personToken, let range = title.range(of: personToken) {
                    title.removeSubrange(range)
                }
                title = Self.cleanedTitle(title)
                let confidence = sorted.map(\.confidence).reduce(0, +)
                    / Float(max(sorted.count, 1))
                let needsReview = confidence < 0.75
                    || (time != nil && time?.endMinutes == nil)
                    || title.isEmpty
                    || personToken != nil
                result.append(CalendarImportCandidate(
                    id: UUID(),
                    date: date,
                    startTimeMinutes: time?.startMinutes,
                    endTimeMinutes: time?.endMinutes,
                    title: title,
                    originalText: originalText,
                    personToken: personToken,
                    confidence: confidence,
                    isSelected: true,
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
