import CoreGraphics
import Foundation

/// Nobody holds a phone straight over a label sewn into a seam. The symbol
/// detector measures shapes against upright templates, so the picture is
/// straightened first: the angle that lines the ink up into the tidiest rows is
/// the angle the label was photographed at.
enum Deskew {

    /// Degrees the image is rotated by, positive clockwise. Zero when it is
    /// already straight enough to leave alone.
    static func estimate(_ binary: BinaryImage, limit: Double = 16) -> Double {
        // Work on a thumbnail: skew is a property of the layout, not of the detail.
        let step = max(1, max(binary.width, binary.height) / 420)
        var points: [(Double, Double)] = []
        points.reserveCapacity(20000)
        var y = 0
        while y < binary.height {
            var x = 0
            while x < binary.width {
                if binary.ink[y * binary.width + x] == 1 {
                    points.append((Double(x) / Double(step), Double(y) / Double(step)))
                }
                x += step
            }
            y += step
        }
        guard points.count > 200 else { return 0 }

        func score(_ degrees: Double) -> Double {
            let radians = degrees * .pi / 180
            let sinValue = sin(radians), cosValue = cos(radians)
            var histogram: [Int: Int] = [:]
            histogram.reserveCapacity(points.count / 4)
            for (x, y) in points {
                let projected = Int((-x * sinValue + y * cosValue).rounded())
                histogram[projected, default: 0] += 1
            }
            // Rows of ink concentrate the histogram; a crooked image spreads it.
            return histogram.values.reduce(0.0) { $0 + Double($1) * Double($1) }
        }

        var best = (angle: 0.0, score: score(0))
        var angle = -limit
        while angle <= limit {
            let value = score(angle)
            if value > best.score { best = (angle, value) }
            angle += 1
        }
        var fine = best.angle - 1
        while fine <= best.angle + 1 {
            let value = score(fine)
            if value > best.score { best = (fine, value) }
            fine += 0.25
        }
        return abs(best.angle) < 0.5 ? 0 : best.angle
    }

    /// Rotates by `-degrees`, on white, growing the canvas so nothing is clipped.
    static func straighten(_ image: CGImage, by degrees: Double) -> CGImage? {
        let radians = -degrees * .pi / 180
        let width = Double(image.width), height = Double(image.height)
        let rotatedWidth = Int((abs(width * cos(radians)) + abs(height * sin(radians))).rounded())
        let rotatedHeight = Int((abs(width * sin(radians)) + abs(height * cos(radians))).rounded())
        guard rotatedWidth > 0, rotatedHeight > 0,
              let context = CGContext(data: nil, width: rotatedWidth, height: rotatedHeight,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: Double(rotatedWidth), height: Double(rotatedHeight)))
        context.translateBy(x: Double(rotatedWidth) / 2, y: Double(rotatedHeight) / 2)
        // A bitmap context has y going up, the estimate is in screen terms.
        context.rotate(by: -radians)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        return context.makeImage()
    }
}
