import Foundation

// Portions derive from RapidOCR/PaddleOCR preprocessing (Apache-2.0).
// Modified and rewritten for Swift/iOS without OpenCV by TimeNest.

struct PPOCRTensor: Equatable, Sendable {
    let values: [Float]
    let shape: [Int]
}

struct PPOCRPixelRect: Equatable, Sendable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    var size: PPOCRImageSize { PPOCRImageSize(width: width, height: height) }
}

struct PPOCRTimeFocusedCrop: Equatable, Sendable {
    let boundingBox: CalendarOCRBoundingBox
    let pixelRect: PPOCRPixelRect
    let image: PPOCRBGRImage
}

enum PPOCRCellPixelRectConverter {
    // Mirrors CalendarVisionOCRService.pixelRect exactly. CalendarOCRBoundingBox
    // uses a lower-left normalized origin while CGImage cropping uses top-left pixels.
    static func pixelRect(
        for box: CalendarOCRBoundingBox,
        imageSize: PPOCRImageSize
    ) -> PPOCRPixelRect? {
        let imageWidth = Double(imageSize.width)
        let imageHeight = Double(imageSize.height)
        let minX = Int(ceil(box.minX * imageWidth))
        let maxX = Int(floor(box.maxX * imageWidth))
        let minY = Int(ceil((1 - box.maxY) * imageHeight))
        let maxY = Int(floor((1 - box.minY) * imageHeight))
        let clippedMinX = min(max(0, minX), imageSize.width)
        let clippedMaxX = min(max(0, maxX), imageSize.width)
        let clippedMinY = min(max(0, minY), imageSize.height)
        let clippedMaxY = min(max(0, maxY), imageSize.height)
        let width = clippedMaxX - clippedMinX
        let height = clippedMaxY - clippedMinY
        guard width >= 2, height >= 2 else { return nil }
        return PPOCRPixelRect(
            x: clippedMinX,
            y: clippedMinY,
            width: width,
            height: height
        )
    }
}

struct PPOCRBGRImage: Equatable, Sendable {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) throws {
        guard width > 0, height > 0, pixels.count == width * height * 3 else {
            throw PPOCRError.invalidImage
        }
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    var size: PPOCRImageSize { PPOCRImageSize(width: width, height: height) }

    func resized(to target: PPOCRImageSize) throws -> PPOCRBGRImage {
        guard target.width > 0, target.height > 0 else {
            throw PPOCRError.invalidImage
        }
        guard target != size else { return self }
        var output = [UInt8](repeating: 0, count: target.width * target.height * 3)
        let scaleX = Double(width) / Double(target.width)
        let scaleY = Double(height) / Double(target.height)
        for targetY in 0..<target.height {
            let sourceY = (Double(targetY) + 0.5) * scaleY - 0.5
            let y0 = clamped(Int(floor(sourceY)), upperBound: height)
            let y1 = clamped(y0 + 1, upperBound: height)
            let yWeight = Float(max(0, min(1, sourceY - Double(y0))))
            for targetX in 0..<target.width {
                let sourceX = (Double(targetX) + 0.5) * scaleX - 0.5
                let x0 = clamped(Int(floor(sourceX)), upperBound: width)
                let x1 = clamped(x0 + 1, upperBound: width)
                let xWeight = Float(max(0, min(1, sourceX - Double(x0))))
                for channel in 0..<3 {
                    let topLeft = Float(pixel(x: x0, y: y0, channel: channel))
                    let topRight = Float(pixel(x: x1, y: y0, channel: channel))
                    let bottomLeft = Float(pixel(x: x0, y: y1, channel: channel))
                    let bottomRight = Float(pixel(x: x1, y: y1, channel: channel))
                    let top = topLeft + (topRight - topLeft) * xWeight
                    let bottom = bottomLeft + (bottomRight - bottomLeft) * xWeight
                    let value = top + (bottom - top) * yWeight
                    output[(targetY * target.width + targetX) * 3 + channel] = UInt8(
                        max(0, min(255, Int(value.rounded())))
                    )
                }
            }
        }
        return try PPOCRBGRImage(width: target.width, height: target.height, pixels: output)
    }

    func cropped(to rect: PPOCRPixelRect) throws -> PPOCRBGRImage {
        guard rect.x >= 0,
              rect.y >= 0,
              rect.width > 0,
              rect.height > 0,
              rect.x + rect.width <= width,
              rect.y + rect.height <= height else {
            throw PPOCRError.invalidCrop
        }
        var output = [UInt8](repeating: 0, count: rect.width * rect.height * 3)
        for targetY in 0..<rect.height {
            let sourceStart = ((rect.y + targetY) * width + rect.x) * 3
            let sourceEnd = sourceStart + rect.width * 3
            let targetStart = targetY * rect.width * 3
            output.replaceSubrange(
                targetStart..<(targetStart + rect.width * 3),
                with: pixels[sourceStart..<sourceEnd]
            )
        }
        return try PPOCRBGRImage(
            width: rect.width,
            height: rect.height,
            pixels: output
        )
    }

    func perspectiveCrop(points: [PPOCRPoint]) throws -> PPOCRBGRImage {
        guard points.count == 4 else { throw PPOCRError.invalidCrop }
        let cropWidth = Int(max(
            distance(points[0], points[1]),
            distance(points[2], points[3])
        ))
        let cropHeight = Int(max(
            distance(points[0], points[3]),
            distance(points[1], points[2])
        ))
        guard cropWidth > 0, cropHeight > 0 else { throw PPOCRError.invalidCrop }

        let transform = try PPOCRPerspectiveTransform(sourcePoints: points)
        var output = [UInt8](repeating: 0, count: cropWidth * cropHeight * 3)
        for targetY in 0..<cropHeight {
            let v = cropHeight == 1 ? 0 : Double(targetY) / Double(cropHeight)
            for targetX in 0..<cropWidth {
                let u = cropWidth == 1 ? 0 : Double(targetX) / Double(cropWidth)
                let source = transform.sourcePoint(u: u, v: v)
                for channel in 0..<3 {
                    let value = bicubicPixel(
                        x: source.x,
                        y: source.y,
                        channel: channel
                    )
                    output[(targetY * cropWidth + targetX) * 3 + channel] = UInt8(
                        max(0, min(255, Int(value.rounded())))
                    )
                }
            }
        }
        let cropped = try PPOCRBGRImage(
            width: cropWidth,
            height: cropHeight,
            pixels: output
        )
        return Double(cropHeight) / Double(cropWidth) >= 1.5
            ? try cropped.rotated90DegreesCounterClockwise()
            : cropped
    }

    func rotated180Degrees() throws -> PPOCRBGRImage {
        var output = [UInt8](repeating: 0, count: pixels.count)
        for y in 0..<height {
            for x in 0..<width {
                for channel in 0..<3 {
                    output[((height - 1 - y) * width + (width - 1 - x)) * 3 + channel]
                        = pixel(x: x, y: y, channel: channel)
                }
            }
        }
        return try PPOCRBGRImage(width: width, height: height, pixels: output)
    }

    func timeRecoveryEnhanced() throws -> PPOCRBGRImage {
        var output = [UInt8](repeating: 0, count: pixels.count)
        for index in 0..<(width * height) {
            let offset = index * 3
            let blue = Double(pixels[offset])
            let green = Double(pixels[offset + 1])
            let red = Double(pixels[offset + 2])
            let grayscale = 0.114 * blue + 0.587 * green + 0.299 * red
            let contrasted = (grayscale - 128) * 1.35 + 128
            let value = UInt8(max(0, min(255, Int(contrasted.rounded()))))
            output[offset] = value
            output[offset + 1] = value
            output[offset + 2] = value
        }
        let enhanced = try PPOCRBGRImage(width: width, height: height, pixels: output)
        guard height < 96 else { return enhanced }
        let scale = min(3, max(2, Int(ceil(96.0 / Double(height)))))
        return try enhanced.resized(to: PPOCRImageSize(
            width: width * scale,
            height: height * scale
        ))
    }

    private func rotated90DegreesCounterClockwise() throws -> PPOCRBGRImage {
        let targetWidth = height
        let targetHeight = width
        var output = [UInt8](repeating: 0, count: pixels.count)
        for targetY in 0..<targetHeight {
            for targetX in 0..<targetWidth {
                let sourceX = width - 1 - targetY
                let sourceY = targetX
                for channel in 0..<3 {
                    output[(targetY * targetWidth + targetX) * 3 + channel]
                        = pixel(x: sourceX, y: sourceY, channel: channel)
                }
            }
        }
        return try PPOCRBGRImage(
            width: targetWidth,
            height: targetHeight,
            pixels: output
        )
    }

    private func bicubicPixel(x: Double, y: Double, channel: Int) -> Double {
        let baseX = Int(floor(x))
        let baseY = Int(floor(y))
        var weightedValue = 0.0
        var totalWeight = 0.0
        for offsetY in -1...2 {
            let sampleY = clamped(baseY + offsetY, upperBound: height)
            let yWeight = Self.cubicWeight(y - Double(baseY + offsetY))
            for offsetX in -1...2 {
                let sampleX = clamped(baseX + offsetX, upperBound: width)
                let weight = yWeight * Self.cubicWeight(x - Double(baseX + offsetX))
                weightedValue += Double(pixel(
                    x: sampleX,
                    y: sampleY,
                    channel: channel
                )) * weight
                totalWeight += weight
            }
        }
        guard totalWeight != 0 else { return 0 }
        return weightedValue / totalWeight
    }

    private static func cubicWeight(_ value: Double) -> Double {
        let x = abs(value)
        let a = -0.75
        if x <= 1 {
            return (a + 2) * x * x * x - (a + 3) * x * x + 1
        }
        if x < 2 {
            return a * x * x * x - 5 * a * x * x + 8 * a * x - 4 * a
        }
        return 0
    }

    private func pixel(x: Int, y: Int, channel: Int) -> UInt8 {
        pixels[(y * width + x) * 3 + channel]
    }

    private func clamped(_ value: Int, upperBound: Int) -> Int {
        min(max(0, value), upperBound - 1)
    }

    private func distance(_ lhs: PPOCRPoint, _ rhs: PPOCRPoint) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}

enum PPOCRDetectionCropper {
    static func expandedPoints(
        _ points: [PPOCRPoint],
        imageSize: PPOCRImageSize,
        marginRatio: Double = 0.06
    ) -> [PPOCRPoint] {
        guard points.count == 4,
              imageSize.width > 0,
              imageSize.height > 0 else {
            return points
        }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max(),
              maxX > minX, maxY > minY else {
            return points
        }
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let marginX = max(2, (maxX - minX) * marginRatio)
        let marginY = max(2, (maxY - minY) * marginRatio)
        let scaleX = (maxX - minX + marginX * 2) / (maxX - minX)
        let scaleY = (maxY - minY + marginY * 2) / (maxY - minY)
        return points.map { point in
            PPOCRPoint(
                x: min(
                    max(0, centerX + (point.x - centerX) * scaleX),
                    Double(imageSize.width - 1)
                ),
                y: min(
                    max(0, centerY + (point.y - centerY) * scaleY),
                    Double(imageSize.height - 1)
                )
            )
        }
    }
}

enum PPOCRTimeFocusedCropper {
    // Vision reports lower-left normalized bounds. Convert those bounds back
    // into the enhanced detection image without inferring any missing text.
    static func crop(
        _ image: PPOCRBGRImage,
        around visionBoundingBox: CalendarOCRBoundingBox,
        marginRatio: Double = 0.08
    ) throws -> PPOCRTimeFocusedCrop? {
        guard marginRatio >= 0,
              visionBoundingBox.x.isFinite,
              visionBoundingBox.y.isFinite,
              visionBoundingBox.width.isFinite,
              visionBoundingBox.height.isFinite,
              visionBoundingBox.width > 0,
              visionBoundingBox.height > 0 else {
            return nil
        }
        let marginX = visionBoundingBox.width * marginRatio
        let marginY = visionBoundingBox.height * marginRatio
        let minX = max(0, visionBoundingBox.minX - marginX)
        let maxX = min(1, visionBoundingBox.maxX + marginX)
        let minY = max(0, visionBoundingBox.minY - marginY)
        let maxY = min(1, visionBoundingBox.maxY + marginY)
        guard maxX > minX, maxY > minY else { return nil }

        let padded = CalendarOCRBoundingBox(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
        guard let pixelRect = PPOCRCellPixelRectConverter.pixelRect(
            for: padded,
            imageSize: image.size
        ), pixelRect.width < image.width || pixelRect.height < image.height else {
            return nil
        }
        let normalized = CalendarOCRBoundingBox(
            x: Double(pixelRect.x) / Double(image.width),
            y: 1 - Double(pixelRect.y + pixelRect.height) / Double(image.height),
            width: Double(pixelRect.width) / Double(image.width),
            height: Double(pixelRect.height) / Double(image.height)
        )
        return PPOCRTimeFocusedCrop(
            boundingBox: normalized,
            pixelRect: pixelRect,
            image: try image.cropped(to: pixelRect)
        )
    }
}

private struct PPOCRPerspectiveTransform {
    let a: Double
    let b: Double
    let c: Double
    let d: Double
    let e: Double
    let f: Double
    let g: Double
    let h: Double

    init(sourcePoints points: [PPOCRPoint]) throws {
        guard points.count == 4 else { throw PPOCRError.invalidCrop }
        let topLeft = points[0]
        let topRight = points[1]
        let bottomRight = points[2]
        let bottomLeft = points[3]
        let dx1 = topRight.x - bottomRight.x
        let dx2 = bottomLeft.x - bottomRight.x
        let dx3 = topLeft.x - topRight.x + bottomRight.x - bottomLeft.x
        let dy1 = topRight.y - bottomRight.y
        let dy2 = bottomLeft.y - bottomRight.y
        let dy3 = topLeft.y - topRight.y + bottomRight.y - bottomLeft.y
        let denominator = dx1 * dy2 - dx2 * dy1
        let projectiveG: Double
        let projectiveH: Double
        if abs(denominator) < 0.000_001 {
            projectiveG = 0
            projectiveH = 0
        } else {
            projectiveG = (dx3 * dy2 - dx2 * dy3) / denominator
            projectiveH = (dx1 * dy3 - dx3 * dy1) / denominator
        }
        g = projectiveG
        h = projectiveH
        a = topRight.x - topLeft.x + projectiveG * topRight.x
        b = bottomLeft.x - topLeft.x + projectiveH * bottomLeft.x
        c = topLeft.x
        d = topRight.y - topLeft.y + projectiveG * topRight.y
        e = bottomLeft.y - topLeft.y + projectiveH * bottomLeft.y
        f = topLeft.y
    }

    func sourcePoint(u: Double, v: Double) -> PPOCRPoint {
        let denominator = g * u + h * v + 1
        guard abs(denominator) > 0.000_001 else {
            return PPOCRPoint(x: c, y: f)
        }
        return PPOCRPoint(
            x: (a * u + b * v + c) / denominator,
            y: (d * u + e * v + f) / denominator
        )
    }
}

enum PPOCRPreprocessor {
    static func detectionInputSize(for imageSize: PPOCRImageSize) throws -> PPOCRImageSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            throw PPOCRError.invalidImage
        }
        let minimumSide = min(imageSize.width, imageSize.height)
        let ratio = minimumSide < PPOCRConfiguration.detectionLimitSideLength
            ? Double(PPOCRConfiguration.detectionLimitSideLength) / Double(minimumSide)
            : 1
        // RapidOCR truncates the scaled dimensions before rounding each one
        // to the closest multiple of 32.
        let scaledWidth = Int(Double(imageSize.width) * ratio)
        let scaledHeight = Int(Double(imageSize.height) * ratio)
        let width = max(
            32,
            Int((Double(scaledWidth) / 32).rounded(.toNearestOrEven)) * 32
        )
        let height = max(
            32,
            Int((Double(scaledHeight) / 32).rounded(.toNearestOrEven)) * 32
        )
        return PPOCRImageSize(width: width, height: height)
    }

    static func detectionTensor(from image: PPOCRBGRImage) throws -> PPOCRTensor {
        let target = try detectionInputSize(for: image.size)
        let resized = try image.resized(to: target)
        return normalizedCHWTensor(
            from: resized,
            targetWidth: target.width,
            targetHeight: target.height,
            paddedWidth: target.width
        )
    }

    static func classificationTensor(from image: PPOCRBGRImage) throws -> PPOCRTensor {
        let targetHeight = PPOCRConfiguration.classificationImageShape[1]
        let targetWidth = PPOCRConfiguration.classificationImageShape[2]
        let resizedWidth = min(
            targetWidth,
            Int(ceil(Double(targetHeight) * Double(image.width) / Double(image.height)))
        )
        let resized = try image.resized(to: PPOCRImageSize(
            width: max(1, resizedWidth),
            height: targetHeight
        ))
        return normalizedCHWTensor(
            from: resized,
            targetWidth: resized.width,
            targetHeight: targetHeight,
            paddedWidth: targetWidth
        )
    }

    static func recognitionTensor(from image: PPOCRBGRImage) throws -> PPOCRTensor {
        let targetHeight = PPOCRConfiguration.recognitionImageShape[1]
        let configuredWidth = PPOCRConfiguration.recognitionImageShape[2]
        let configuredRatio = Double(configuredWidth) / Double(targetHeight)
        let imageRatio = Double(image.width) / Double(image.height)
        let maximumRatio = max(configuredRatio, imageRatio)
        let dynamicWidth = max(1, Int(Double(targetHeight) * maximumRatio))
        let resizedWidth = min(
            dynamicWidth,
            Int(ceil(Double(targetHeight) * imageRatio))
        )
        let resized = try image.resized(to: PPOCRImageSize(
            width: max(1, resizedWidth),
            height: targetHeight
        ))
        return normalizedCHWTensor(
            from: resized,
            targetWidth: resized.width,
            targetHeight: targetHeight,
            paddedWidth: dynamicWidth
        )
    }

    private static func normalizedCHWTensor(
        from image: PPOCRBGRImage,
        targetWidth: Int,
        targetHeight: Int,
        paddedWidth: Int
    ) -> PPOCRTensor {
        var values = [Float](
            repeating: 0,
            count: 3 * targetHeight * paddedWidth
        )
        for channel in 0..<3 {
            let channelOffset = channel * targetHeight * paddedWidth
            for y in 0..<targetHeight {
                for x in 0..<targetWidth {
                    let byte = image.pixels[(y * targetWidth + x) * 3 + channel]
                    values[channelOffset + y * paddedWidth + x]
                        = (Float(byte) / 255 - 0.5) / 0.5
                }
            }
        }
        return PPOCRTensor(
            values: values,
            shape: [1, 3, targetHeight, paddedWidth]
        )
    }
}

enum PPOCRBoxCoordinateConverter {
    static func convert(
        points: [PPOCRPoint],
        mapSize: PPOCRImageSize,
        destinationSize: PPOCRImageSize
    ) -> [PPOCRPoint] {
        guard mapSize.width > 0, mapSize.height > 0 else { return [] }
        return points.map { point in
            let x = (point.x / Double(mapSize.width) * Double(destinationSize.width))
                .rounded(.toNearestOrEven)
            let y = (point.y / Double(mapSize.height) * Double(destinationSize.height))
                .rounded(.toNearestOrEven)
            return PPOCRPoint(
                x: min(max(0, x), Double(destinationSize.width - 1)),
                y: min(max(0, y), Double(destinationSize.height - 1))
            )
        }
    }
}
