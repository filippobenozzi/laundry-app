import CoreGraphics
import Foundation

/// The care symbols drawn as geometry rather than shipped as pictures: one
/// description of each shape, used both to render them in the app and to build the
/// templates the detector matches photographed labels against.
enum CareGlyphPath {

    struct Drawing {
        /// Outlines, to be stroked.
        var strokes: [CGPath] = []
        /// Solid marks — the temperature dots — to be filled.
        var fills: [CGPath] = []
        /// Text that belongs inside the shape, with the box it has to fit.
        var text: (string: String, rect: CGRect)?
    }

    /// Line thickness that keeps a symbol readable at any size.
    static func lineWidth(for size: CGFloat) -> CGFloat { max(1, size * 0.055) }

    /// How much of the height goes to what is drawn under the outline: the bars
    /// that mean "gentler", or the steam a crossed-out iron must not make.
    static func skirt(for spec: GlyphSpec) -> CGFloat {
        if spec.inner == .steamCrossed { return 0.30 }
        switch spec.bars {
        case 0: return 0
        case 1: return 0.18
        default: return 0.26
        }
    }

    /// The part of `rect` the outline itself occupies — always square, so a circle
    /// stays a circle whatever box it is asked to fill.
    static func baseRect(_ rect: CGRect, spec: GlyphSpec) -> CGRect {
        let reserved = rect.height * skirt(for: spec)
        let side = min(rect.width, rect.height - reserved)
        return CGRect(x: rect.midX - side / 2, y: rect.minY, width: side, height: side)
    }

    static func drawing(for spec: GlyphSpec, in rect: CGRect) -> Drawing {
        var drawing = Drawing()
        let base = baseRect(rect, spec: spec)
        drawing.strokes.append(shape(spec.base, in: base))

        switch spec.inner {
        case .tumbleCircle:
            let inset = base.width * 0.19
            drawing.strokes.append(CGPath(ellipseIn: base.insetBy(dx: inset, dy: inset), transform: nil))
        case .lineVertical:
            drawing.strokes.append(verticalLines(1, in: base))
        case .lineVerticalDouble:
            drawing.strokes.append(verticalLines(2, in: base))
        case .lineHorizontal:
            drawing.strokes.append(horizontalLines(1, in: base))
        case .lineHorizontalDouble:
            drawing.strokes.append(horizontalLines(2, in: base))
        case .bleachStripes:
            drawing.strokes.append(bleachStripes(in: base))
        case .hand:
            drawing.strokes.append(hand(in: base))
        case .steamCrossed:
            drawing.strokes.append(steam(under: base, in: rect))
        case .none:
            break
        }

        if spec.shaded { drawing.strokes.append(shadeCorner(in: base)) }
        if spec.dots > 0 { drawing.fills.append(dots(spec.dots, base: spec.base, in: base)) }
        if spec.bars > 0 { drawing.strokes.append(bars(spec.bars, under: base, in: rect)) }
        if spec.crossed { drawing.strokes.append(cross(over: base)) }

        if let text = spec.text {
            let box: CGRect
            switch spec.base {
            case .washtub:
                box = CGRect(x: base.minX + base.width * 0.18, y: base.minY + base.height * 0.34,
                             width: base.width * 0.64, height: base.height * 0.46)
            default:
                box = base.insetBy(dx: base.width * 0.29, dy: base.height * 0.29)
            }
            drawing.text = (text, box)
        }
        return drawing
    }

    // MARK: - The five outlines

    static func shape(_ base: GlyphBase, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        switch base {
        case .square:
            path.addRect(rect.insetBy(dx: rect.width * 0.02, dy: rect.height * 0.02))

        case .circle:
            path.addEllipse(in: rect.insetBy(dx: rect.width * 0.02, dy: rect.height * 0.02))

        case .triangle:
            path.move(to: point(0.5, 0.02))
            path.addLine(to: point(0.98, 0.96))
            path.addLine(to: point(0.02, 0.96))
            path.closeSubpath()

        case .washtub:
            // A vessel opening upwards, closed at the top by the wavy line that
            // stands for water.
            let top = 0.16
            path.move(to: point(0.02, top))
            path.addCurve(to: point(0.34, top), control1: point(0.12, top - 0.10), control2: point(0.24, top + 0.10))
            path.addCurve(to: point(0.66, top), control1: point(0.44, top - 0.10), control2: point(0.56, top + 0.10))
            path.addCurve(to: point(0.98, top), control1: point(0.76, top - 0.10), control2: point(0.88, top + 0.10))
            path.addLine(to: point(0.86, 0.74))
            path.addCurve(to: point(0.68, 0.96), control1: point(0.84, 0.90), control2: point(0.80, 0.96))
            path.addLine(to: point(0.32, 0.96))
            path.addCurve(to: point(0.14, 0.74), control1: point(0.20, 0.96), control2: point(0.16, 0.90))
            path.closeSubpath()

        case .iron:
            // Seen from the side, pointing left: flat sole, sloping nose.
            path.move(to: point(0.02, 0.88))
            path.addLine(to: point(0.98, 0.88))
            path.addLine(to: point(0.98, 0.44))
            path.addCurve(to: point(0.78, 0.14), control1: point(0.98, 0.24), control2: point(0.90, 0.14))
            path.addLine(to: point(0.46, 0.14))
            path.addLine(to: point(0.34, 0.24))
            path.addLine(to: point(0.02, 0.88))
            path.closeSubpath()
        }
        return path
    }

    // MARK: - Marks

    private static func verticalLines(_ count: Int, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let top = rect.minY + rect.height * 0.14
        let bottom = rect.maxY - rect.height * 0.14
        let spacing = rect.width * 0.13
        let centre = rect.midX - (count == 2 ? spacing / 2 : 0)
        for index in 0..<count {
            let x = centre + CGFloat(index) * spacing
            path.move(to: CGPoint(x: x, y: top))
            path.addLine(to: CGPoint(x: x, y: bottom))
        }
        return path
    }

    private static func horizontalLines(_ count: Int, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let left = rect.minX + rect.width * 0.18
        let right = rect.maxX - rect.width * 0.18
        let spacing = rect.height * 0.16
        let centre = rect.midY - (count == 2 ? spacing / 2 : 0)
        for index in 0..<count {
            let y = centre + CGFloat(index) * spacing
            path.move(to: CGPoint(x: left, y: y))
            path.addLine(to: CGPoint(x: right, y: y))
        }
        return path
    }

    private static func bleachStripes(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        for offset in [0.32, 0.50] {
            path.move(to: CGPoint(x: rect.minX + rect.width * offset, y: rect.maxY - rect.height * 0.16))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * (offset + 0.14), y: rect.maxY - rect.height * 0.46))
        }
        return path
    }

    private static func hand(in rect: CGRect) -> CGPath {
        // A schematic hand dipping into the tub: palm plus three fingers and a thumb.
        let path = CGMutablePath()
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        path.move(to: point(0.28, 0.84))
        path.addLine(to: point(0.28, 0.62))
        path.addCurve(to: point(0.38, 0.52), control1: point(0.28, 0.55), control2: point(0.32, 0.52))
        path.addCurve(to: point(0.46, 0.62), control1: point(0.44, 0.52), control2: point(0.46, 0.55))
        path.addLine(to: point(0.46, 0.50))
        path.addCurve(to: point(0.56, 0.40), control1: point(0.46, 0.43), control2: point(0.50, 0.40))
        path.addCurve(to: point(0.64, 0.50), control1: point(0.62, 0.40), control2: point(0.64, 0.43))
        path.addLine(to: point(0.64, 0.56))
        path.addCurve(to: point(0.74, 0.46), control1: point(0.64, 0.49), control2: point(0.68, 0.46))
        path.addCurve(to: point(0.80, 0.56), control1: point(0.78, 0.46), control2: point(0.80, 0.49))
        path.addLine(to: point(0.80, 0.84))
        path.closeSubpath()
        return path
    }

    private static func steam(under base: CGRect, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let top = base.maxY + rect.height * 0.07
        let bottom = min(rect.maxY - rect.height * 0.01, top + rect.height * 0.17)
        for offset in [0.36, 0.64] {
            let x = base.minX + base.width * offset
            path.move(to: CGPoint(x: x, y: top))
            path.addLine(to: CGPoint(x: x, y: bottom))
        }
        path.move(to: CGPoint(x: base.minX + base.width * 0.26, y: bottom))
        path.addLine(to: CGPoint(x: base.minX + base.width * 0.74, y: top))
        return path
    }

    private static func shadeCorner(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.40))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.04))
        return path
    }

    private static func dots(_ count: Int, base: GlyphBase, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let radius = rect.width * 0.055
        let spacing = rect.width * (base == .iron ? 0.17 : 0.19)
        let centreY: CGFloat
        switch base {
        case .iron: centreY = rect.minY + rect.height * 0.58
        default: centreY = rect.midY
        }
        let start = rect.midX - spacing * CGFloat(count - 1) / 2
        for index in 0..<count {
            let centre = CGPoint(x: start + spacing * CGFloat(index), y: centreY)
            path.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                       width: radius * 2, height: radius * 2))
        }
        return path
    }

    private static func bars(_ count: Int, under base: CGRect, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let left = rect.minX + rect.width * 0.22
        let right = rect.maxX - rect.width * 0.22
        let gap = (rect.maxY - base.maxY) / CGFloat(count + 1)
        for index in 1...count {
            let y = base.maxY + gap * CGFloat(index)
            path.move(to: CGPoint(x: left, y: y))
            path.addLine(to: CGPoint(x: right, y: y))
        }
        return path
    }

    private static func cross(over rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let box = rect.insetBy(dx: -rect.width * 0.04, dy: -rect.height * 0.04)
        path.move(to: CGPoint(x: box.minX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
        path.move(to: CGPoint(x: box.maxX, y: box.minY))
        path.addLine(to: CGPoint(x: box.minX, y: box.maxY))
        return path
    }
}
