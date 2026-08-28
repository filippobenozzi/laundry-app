import CoreGraphics
import CoreText
import Foundation

/// Draws care symbols into a bitmap, the way a label prints them, so the detector
/// can be tested against pictures instead of against its own assumptions.
enum GlyphRasterizer {

    struct Sheet {
        let image: CGImage
        /// Where each symbol landed, in image coordinates with the origin top-left.
        let boxes: [CGRect]
        let specs: [GlyphSpec]
    }

    static func sheet(_ specs: [GlyphSpec], symbolSize: CGFloat = 92, spacing: CGFloat = 34,
                      margin: CGFloat = 40, noise: Bool = false) -> Sheet {
        let width = margin * 2 + symbolSize * CGFloat(specs.count) + spacing * CGFloat(max(0, specs.count - 1))
        let height = margin * 2 + symbolSize * 1.25
        let pixelWidth = Int(width.rounded()), pixelHeight = Int(height.rounded())

        let context = CGContext(data: nil, width: pixelWidth, height: pixelHeight,
                                bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw top-down, like everything else that touches CareGlyphPath.
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)

        var boxes: [CGRect] = []
        for (index, spec) in specs.enumerated() {
            let origin = CGPoint(x: margin + (symbolSize + spacing) * CGFloat(index), y: margin)
            let rect = CGRect(origin: origin, size: CGSize(width: symbolSize, height: symbolSize * 1.25))
            boxes.append(rect)
            GlyphRaster.draw(spec, in: rect, context: context)
        }

        if noise {
            // A little grey grain, the way a woven label photographs.
            context.setFillColor(gray: 0.62, alpha: 0.5)
            var seed: UInt64 = 12345
            for _ in 0..<(pixelWidth * pixelHeight / 260) {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let x = CGFloat((seed >> 16) % UInt64(pixelWidth))
                let y = CGFloat((seed >> 33) % UInt64(pixelHeight))
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

        return Sheet(image: context.makeImage()!, boxes: boxes, specs: specs)
    }

    /// A whole care label: the printed lines first, the row of symbols underneath.
    /// The text matters — its letters are what the detector has to resist reading
    /// as symbols.
    static func labelSheet(text: [String], specs: [GlyphSpec], width: CGFloat = 900) -> Sheet {
        let symbolSize: CGFloat = 96
        let height = 60 + CGFloat(text.count) * 46 + symbolSize * 1.4 + 50
        let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)

        var y: CGFloat = 40
        for line in text {
            let font = CTFontCreateWithName("Helvetica" as CFString, 30, nil)
            let attributed = NSAttributedString(string: line, attributes: [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0, alpha: 1)])
            let drawn = CTLineCreateWithAttributedString(attributed)
            context.saveGState()
            context.translateBy(x: 44, y: y + 30)
            context.scaleBy(x: 1, y: -1)
            context.textPosition = .zero
            CTLineDraw(drawn, context)
            context.restoreGState()
            y += 46
        }

        let spacing: CGFloat = 40
        let total = CGFloat(specs.count) * symbolSize + CGFloat(max(0, specs.count - 1)) * spacing
        var x = (width - total) / 2
        var boxes: [CGRect] = []
        for spec in specs {
            let rect = CGRect(x: x, y: y + 16, width: symbolSize, height: symbolSize * 1.35)
            boxes.append(rect)
            GlyphRaster.draw(spec, in: rect, context: context)
            x += symbolSize + spacing
        }
        return Sheet(image: context.makeImage()!, boxes: boxes, specs: specs)
    }

    /// Tilts a sheet, the way a label photographed in a hurry is tilted.
    static func tilt(_ image: CGImage, degrees: Double) -> CGImage {
        let width = Double(image.width), height = Double(image.height)
        let radians = degrees * .pi / 180
        let tiltedWidth = Int(abs(width * cos(radians)) + abs(height * sin(radians)))
        let tiltedHeight = Int(abs(width * sin(radians)) + abs(height * cos(radians)))
        let context = CGContext(data: nil, width: tiltedWidth, height: tiltedHeight,
                                bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: Double(tiltedWidth), height: Double(tiltedHeight)))
        context.translateBy(x: Double(tiltedWidth) / 2, y: Double(tiltedHeight) / 2)
        context.rotate(by: radians)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        return context.makeImage()!
    }

}
