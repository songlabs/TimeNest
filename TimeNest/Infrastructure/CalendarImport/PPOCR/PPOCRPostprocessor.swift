import Foundation

// Portions derive from RapidOCR/PaddleOCR DB postprocessing (Apache-2.0).
// Modified and rewritten for Swift/iOS without OpenCV/pyclipper by TimeNest.

enum PPOCRDBPostprocessor {
    static func process(
        probabilities: [Float],
        mapSize: PPOCRImageSize,
        destinationSize: PPOCRImageSize
    ) throws -> [PPOCRDetectedBox] {
        guard probabilities.count == mapSize.width * mapSize.height else {
            throw PPOCRError.invalidOutput("detectionShape")
        }
        var mask = probabilities.map {
            $0 > PPOCRConfiguration.detectionThreshold ? UInt8(1) : UInt8(0)
        }
        if PPOCRConfiguration.detectionUsesDilation {
            mask = dilated2x2(mask, size: mapSize)
        }

        let contours = boundaryContours(mask: mask, size: mapSize, limit: 1_000)
        var boxes: [PPOCRDetectedBox] = []
        for contour in contours {
            guard let rectangle = minimumAreaRectangle(contour),
                  rectangle.minimumSide >= 3 else { continue }
            let score = fastScore(
                probabilities: probabilities,
                mapSize: mapSize,
                box: rectangle.points
            )
            guard score >= PPOCRConfiguration.detectionBoxThreshold else { continue }
            let expanded = expandedRectangle(
                rectangle,
                ratio: PPOCRConfiguration.detectionUnclipRatio
            )
            guard expanded.minimumSide >= 5 else { continue }
            let converted = orderClockwise(PPOCRBoxCoordinateConverter.convert(
                points: expanded.points,
                mapSize: mapSize,
                destinationSize: destinationSize
            ))
            guard converted.count == 4 else { continue }
            let rectWidth = Int(distance(converted[0], converted[1]))
            let rectHeight = Int(distance(converted[0], converted[3]))
            guard rectWidth > 3, rectHeight > 3 else { continue }
            boxes.append(PPOCRDetectedBox(points: converted, score: score))
        }
        return PPOCRBoxSorter.sorted(boxes)
    }

    private static func dilated2x2(
        _ mask: [UInt8],
        size: PPOCRImageSize
    ) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: mask.count)
        for y in 0..<size.height {
            for x in 0..<size.width {
                var value: UInt8 = 0
                for sourceY in max(0, y - 1)...y {
                    for sourceX in max(0, x - 1)...x where value == 0 {
                        value = mask[sourceY * size.width + sourceX]
                    }
                }
                output[y * size.width + x] = value
            }
        }
        return output
    }

    private static func boundaryContours(
        mask: [UInt8],
        size: PPOCRImageSize,
        limit: Int
    ) -> [[PPOCRPoint]] {
        var visited = [UInt8](repeating: 0, count: mask.count)
        var contours: [[PPOCRPoint]] = []
        let eightNeighbors = [
            (-1, -1), (0, -1), (1, -1),
            (-1, 0), (1, 0),
            (-1, 1), (0, 1), (1, 1)
        ]
        let fourNeighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]

        for y in 0..<size.height {
            for x in 0..<size.width {
                let start = y * size.width + x
                guard mask[start] != 0, visited[start] == 0 else { continue }
                guard contours.count < limit else { return contours }
                visited[start] = 1
                var queue = [start]
                var cursor = 0
                var boundary: [PPOCRPoint] = []
                while cursor < queue.count {
                    let index = queue[cursor]
                    cursor += 1
                    let currentX = index % size.width
                    let currentY = index / size.width
                    let isBoundary = fourNeighbors.contains { dx, dy in
                        let neighborX = currentX + dx
                        let neighborY = currentY + dy
                        return neighborX < 0 || neighborX >= size.width
                            || neighborY < 0 || neighborY >= size.height
                            || mask[neighborY * size.width + neighborX] == 0
                    }
                    if isBoundary {
                        boundary.append(PPOCRPoint(
                            x: Double(currentX),
                            y: Double(currentY)
                        ))
                    }
                    for (dx, dy) in eightNeighbors {
                        let neighborX = currentX + dx
                        let neighborY = currentY + dy
                        guard neighborX >= 0, neighborX < size.width,
                              neighborY >= 0, neighborY < size.height else { continue }
                        let neighbor = neighborY * size.width + neighborX
                        guard mask[neighbor] != 0, visited[neighbor] == 0 else { continue }
                        visited[neighbor] = 1
                        queue.append(neighbor)
                    }
                }
                contours.append(boundary)
            }
        }
        return contours
    }

    private static func fastScore(
        probabilities: [Float],
        mapSize: PPOCRImageSize,
        box: [PPOCRPoint]
    ) -> Float {
        guard box.count == 4 else { return 0 }
        let minimumX = max(0, Int(floor(box.map(\.x).min() ?? 0)))
        let maximumX = min(mapSize.width - 1, Int(ceil(box.map(\.x).max() ?? 0)))
        let minimumY = max(0, Int(floor(box.map(\.y).min() ?? 0)))
        let maximumY = min(mapSize.height - 1, Int(ceil(box.map(\.y).max() ?? 0)))
        guard minimumX <= maximumX, minimumY <= maximumY else { return 0 }
        var sum: Float = 0
        var count = 0
        for y in minimumY...maximumY {
            for x in minimumX...maximumX where pointInPolygon(
                PPOCRPoint(x: Double(x), y: Double(y)),
                polygon: box
            ) {
                sum += probabilities[y * mapSize.width + x]
                count += 1
            }
        }
        return count == 0 ? 0 : sum / Float(count)
    }

    private static func pointInPolygon(
        _ point: PPOCRPoint,
        polygon: [PPOCRPoint]
    ) -> Bool {
        var isInside = false
        var previous = polygon[polygon.count - 1]
        for current in polygon {
            if pointOnSegment(point, previous, current) { return true }
            let crosses = (current.y > point.y) != (previous.y > point.y)
                && point.x < (previous.x - current.x) * (point.y - current.y)
                    / (previous.y - current.y) + current.x
            if crosses { isInside.toggle() }
            previous = current
        }
        return isInside
    }

    private static func pointOnSegment(
        _ point: PPOCRPoint,
        _ start: PPOCRPoint,
        _ end: PPOCRPoint
    ) -> Bool {
        let cross = (point.y - start.y) * (end.x - start.x)
            - (point.x - start.x) * (end.y - start.y)
        guard abs(cross) < 0.000_001 else { return false }
        return point.x >= min(start.x, end.x) && point.x <= max(start.x, end.x)
            && point.y >= min(start.y, end.y) && point.y <= max(start.y, end.y)
    }

    private static func expandedRectangle(
        _ rectangle: PPOCRMinimumAreaRectangle,
        ratio: Double
    ) -> PPOCRMinimumAreaRectangle {
        let distance = rectangle.area * ratio / max(rectangle.perimeter, 0.000_001)
        let halfWidth = rectangle.width / 2 + distance
        let halfHeight = rectangle.height / 2 + distance
        let horizontal = PPOCRPoint(
            x: rectangle.horizontalAxis.x * halfWidth,
            y: rectangle.horizontalAxis.y * halfWidth
        )
        let vertical = PPOCRPoint(
            x: rectangle.verticalAxis.x * halfHeight,
            y: rectangle.verticalAxis.y * halfHeight
        )
        let points = [
            rectangle.center - horizontal - vertical,
            rectangle.center + horizontal - vertical,
            rectangle.center + horizontal + vertical,
            rectangle.center - horizontal + vertical
        ]
        return PPOCRMinimumAreaRectangle(
            points: orderClockwise(points),
            center: rectangle.center,
            horizontalAxis: rectangle.horizontalAxis,
            verticalAxis: rectangle.verticalAxis,
            width: halfWidth * 2,
            height: halfHeight * 2
        )
    }

    private static func minimumAreaRectangle(
        _ contour: [PPOCRPoint]
    ) -> PPOCRMinimumAreaRectangle? {
        let hull = convexHull(contour)
        guard hull.count >= 3 else { return nil }
        var best: PPOCRMinimumAreaRectangle?
        var bestArea = Double.greatestFiniteMagnitude
        for index in hull.indices {
            let next = hull[(index + 1) % hull.count]
            let edge = next - hull[index]
            let length = hypot(edge.x, edge.y)
            guard length > 0.000_001 else { continue }
            let horizontal = PPOCRPoint(x: edge.x / length, y: edge.y / length)
            let vertical = PPOCRPoint(x: -horizontal.y, y: horizontal.x)
            let horizontalValues = hull.map { dot($0, horizontal) }
            let verticalValues = hull.map { dot($0, vertical) }
            guard let minH = horizontalValues.min(), let maxH = horizontalValues.max(),
                  let minV = verticalValues.min(), let maxV = verticalValues.max() else {
                continue
            }
            let width = maxH - minH
            let height = maxV - minV
            let area = width * height
            guard area < bestArea else { continue }
            let center = horizontal * ((minH + maxH) / 2)
                + vertical * ((minV + maxV) / 2)
            let halfHorizontal = horizontal * (width / 2)
            let halfVertical = vertical * (height / 2)
            let points = orderClockwise([
                center - halfHorizontal - halfVertical,
                center + halfHorizontal - halfVertical,
                center + halfHorizontal + halfVertical,
                center - halfHorizontal + halfVertical
            ])
            bestArea = area
            best = PPOCRMinimumAreaRectangle(
                points: points,
                center: center,
                horizontalAxis: horizontal,
                verticalAxis: vertical,
                width: width,
                height: height
            )
        }
        return best
    }

    private static func convexHull(_ points: [PPOCRPoint]) -> [PPOCRPoint] {
        let hashablePoints: [PPOCRHashablePoint] = points.map { PPOCRHashablePoint($0) }
        let uniquePoints: Set<PPOCRHashablePoint> = Set(hashablePoints)
        let unique: [PPOCRPoint] = uniquePoints.map { $0.point }
        let sorted: [PPOCRPoint] = unique.sorted {
            $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x
        }
        guard sorted.count > 2 else { return sorted }
        var lower: [PPOCRPoint] = []
        for point in sorted {
            while lower.count >= 2,
                  cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }
        var upper: [PPOCRPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2,
                  cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    private static func orderClockwise(_ points: [PPOCRPoint]) -> [PPOCRPoint] {
        guard points.count == 4 else { return points }
        let xSorted = points.sorted { lhs, rhs in
            lhs.x == rhs.x ? lhs.y < rhs.y : lhs.x < rhs.x
        }
        let left = Array(xSorted.prefix(2)).sorted { $0.y < $1.y }
        let right = Array(xSorted.suffix(2)).sorted { $0.y < $1.y }
        return [left[0], right[0], right[1], left[1]]
    }

    private static func cross(
        _ origin: PPOCRPoint,
        _ lhs: PPOCRPoint,
        _ rhs: PPOCRPoint
    ) -> Double {
        (lhs.x - origin.x) * (rhs.y - origin.y)
            - (lhs.y - origin.y) * (rhs.x - origin.x)
    }

    private static func dot(_ lhs: PPOCRPoint, _ rhs: PPOCRPoint) -> Double {
        lhs.x * rhs.x + lhs.y * rhs.y
    }

    private static func distance(_ lhs: PPOCRPoint, _ rhs: PPOCRPoint) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}

private struct PPOCRMinimumAreaRectangle {
    let points: [PPOCRPoint]
    let center: PPOCRPoint
    let horizontalAxis: PPOCRPoint
    let verticalAxis: PPOCRPoint
    let width: Double
    let height: Double

    var minimumSide: Double { min(width, height) }
    var area: Double { width * height }
    var perimeter: Double { 2 * (width + height) }
}

private struct PPOCRHashablePoint: Hashable {
    let x: Double
    let y: Double

    init(_ point: PPOCRPoint) {
        x = point.x
        y = point.y
    }

    var point: PPOCRPoint { PPOCRPoint(x: x, y: y) }
}

private extension PPOCRPoint {
    static func + (lhs: PPOCRPoint, rhs: PPOCRPoint) -> PPOCRPoint {
        PPOCRPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: PPOCRPoint, rhs: PPOCRPoint) -> PPOCRPoint {
        PPOCRPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: PPOCRPoint, rhs: Double) -> PPOCRPoint {
        PPOCRPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

enum PPOCRBoxSorter {
    static func sorted(_ boxes: [PPOCRDetectedBox]) -> [PPOCRDetectedBox] {
        guard boxes.count > 1 else { return boxes }
        let ySorted = boxes.enumerated().sorted { lhs, rhs in
            let leftY = lhs.element.points.first?.y ?? 0
            let rightY = rhs.element.points.first?.y ?? 0
            return leftY == rightY ? lhs.offset < rhs.offset : leftY < rightY
        }
        var lineID = 0
        var previousY = ySorted[0].element.points.first?.y ?? 0
        var identified: [(line: Int, index: Int, box: PPOCRDetectedBox)] = []
        for item in ySorted {
            let y = item.element.points.first?.y ?? 0
            if !identified.isEmpty, y - previousY >= 10 { lineID += 1 }
            identified.append((lineID, item.offset, item.element))
            previousY = y
        }
        return identified.sorted { lhs, rhs in
            if lhs.line != rhs.line { return lhs.line < rhs.line }
            let leftX = lhs.box.points.first?.x ?? 0
            let rightX = rhs.box.points.first?.x ?? 0
            return leftX == rightX ? lhs.index < rhs.index : leftX < rightX
        }.map(\.box)
    }
}
