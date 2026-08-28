import CoreGraphics
import CoreText
import Foundation

/// Draws a care symbol into a bitmap, the way a label prints it. The app uses it
/// to build the detector's templates from its own drawings; the checks use it to
/// make test labels.
enum GlyphRaster {

    static func image(_ spec: GlyphSpec, side: Int = 160, margin: CGFloat = 0.16) -> CGImage? {
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let size = CGFloat(side)
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        // CareGlyphPath is written top-down, a bitmap context is bottom-up.
        context.translateBy(x: 0, y: size)
        context.scaleBy(x: 1, y: -1)
        let inset = size * margin
        draw(spec, in: CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
             context: context)
        return context.makeImage()
    }

    static func draw(_ spec: GlyphSpec, in rect: CGRect, context: CGContext) {
        let drawing = CareGlyphPath.drawing(for: spec, in: rect)
        context.setLineWidth(CareGlyphPath.lineWidth(for: rect.width))
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setStrokeColor(gray: 0, alpha: 1)
        context.setFillColor(gray: 0, alpha: 1)

        for path in drawing.strokes {
            context.addPath(path)
            context.strokePath()
        }
        for path in drawing.fills {
            context.addPath(path)
            context.fillPath()
        }
        if let text = drawing.text {
            drawText(text.string, in: text.rect, context: context)
        }
    }

    private static func drawText(_ string: String, in rect: CGRect, context: CGContext) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, rect.height, nil)
        let attributed = NSAttributedString(string: string, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0, alpha: 1),
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        guard bounds.width > 0, bounds.height > 0 else { return }
        let scale = min(rect.width / bounds.width, rect.height / bounds.height) * 0.94

        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -bounds.midX, y: -bounds.midY)
        context.textPosition = .zero
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
