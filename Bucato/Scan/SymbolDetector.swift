import CoreGraphics
import Foundation

/// Finds care symbols in a photo of a label and works out what each one says.
///
/// There is no model file here and nothing to train: the symbols are a small,
/// rigid alphabet of outlines, so the detector measures geometry. It finds the
/// blobs of ink, keeps the ones shaped like one of the five outlines, then reads
/// the marks inside and under each one — dots, bars, lines, a cross.
enum SymbolDetector {

    /// Reads the text inside a region of the straightened image, given in
    /// normalised coordinates with the origin at the top left. Injected so the
    /// detector stays testable without Vision.
    typealias TextReader = (CGImage, CGRect) -> String?

    struct Result {
        var symbols: [DetectedSymbol]
        /// The image the boxes refer to: the one handed in, straightened.
        var image: CGImage
    }

    static func detect(in image: CGImage, readText: TextReader? = nil) -> Result {
        guard var binary = BinaryImage.make(from: image) else {
            return Result(symbols: [], image: image)
        }
        var straightened = image
        let angle = Deskew.estimate(binary)
        if angle != 0, let rotated = Deskew.straighten(image, by: angle),
           let rotatedBinary = BinaryImage.make(from: rotated) {
            straightened = rotated
            binary = rotatedBinary
        }
        let symbols = detect(in: binary, image: straightened, readText: readText)
        return Result(symbols: symbols, image: straightened)
    }

    static func detect(in binary: BinaryImage, image: CGImage, readText: TextReader? = nil) -> [DetectedSymbol] {
        let components = binary.components(minPixels: 30)
        guard !components.isEmpty else { return [] }

        let shortSide = Double(min(binary.width, binary.height))
        let longSide = Double(max(binary.width, binary.height))
        let minSide = max(14.0, shortSide * 0.022)
        // A tight crop of the symbol row and a photo of the whole label are both
        // normal, so the ceiling follows whichever side has room.
        let maxSide = max(shortSide * 0.85, longSide * 0.30)

        var found: [(symbol: DetectedSymbol, component: BinaryImage.Component)] = []

        for component in components {
            let width = Double(component.width), height = Double(component.height)
            guard width >= minSide, height >= minSide, width <= maxSide, height <= maxSide else { continue }
            guard component.aspect > 0.38, component.aspect < 2.6 else { continue }
            // Outlines are hollow: a solid blob of that size is a logo, not a symbol.
            guard Double(component.pixels) < width * height * 0.72 else { continue }
            guard component.minX > 0, component.minY > 0,
                  component.maxX < binary.width - 1, component.maxY < binary.height - 1 else { continue }

            let crossed = isCrossed(binary, component)
            guard let silhouette = binary.silhouette(of: component),
                  let descriptor = ShapeDescriptor.make(filled: silhouette.filled,
                                                        width: silhouette.width,
                                                        height: silhouette.height,
                                                        trimArms: crossed),
                  let match = ShapeTemplates.classify(descriptor, crossed: crossed),
                  match.distance < 0.30
            else { continue }

            let children = components.filter { child in
                component.contains(child) && child.pixels < component.pixels
                    && !(child.minX == component.minX && child.minY == component.minY
                         && child.maxX == component.maxX && child.maxY == component.maxY)
            }

            var spec = GlyphSpec(base: match.base)
            spec.crossed = crossed
            spec.bars = barCount(below: component, in: components)

            var marks = innerMarks(of: component, children: children, base: match.base)
            // A crossed tumble-dry symbol joins the circle to the square, so nothing
            // is left inside to find. Look for the ring along the path it would take.
            if match.base == .square, marks.inner == nil, hasInscribedRing(binary, component) {
                marks.inner = .tumbleCircle
            }
            // The corner stroke that means "in the shade" usually runs into the
            // square it sits in, so it is looked for along the line it would take.
            if match.base == .square, !crossed, hasShadeCorner(binary, component) {
                marks.shaded = true
            }
            if match.base == .iron, marks.inner == nil, hasSteamMark(component, in: components) {
                marks.inner = .steamCrossed
                marks.dots = 0
            }
            // A hand drawn into the tub often touches its rim and comes back as one
            // blob. An outline that carries this much ink is not an empty tub.
            if match.base == .washtub, marks.inner == nil, children.isEmpty, !crossed,
               Double(component.pixels) > width * height * 0.26 {
                marks.inner = .hand
            }
            spec.inner = marks.inner
            spec.dots = marks.dots
            spec.shaded = marks.shaded

            if match.base == .washtub || match.base == .circle {
                spec.text = readLegend(component, base: match.base, binary: binary,
                                       image: image, readText: readText)
            }
            // Old labels print pallini instead of the number.
            if match.base == .washtub, spec.text == nil, spec.inner == nil,
               let celsius = CareSymbolCatalog.washTemperature(forDots: marks.dots) {
                spec.text = "\(celsius)"
                spec.dots = 0
            }
            if match.base == .washtub, spec.crossed { spec.text = nil; spec.dots = 0 }

            guard let symbol = CareSymbolCatalog.match(spec) else { continue }

            let confidence = confidence(match: match, spec: spec, matched: symbol)
            let box = CGRect(x: Double(component.minX) / Double(binary.width),
                             y: Double(component.minY) / Double(binary.height),
                             width: width / Double(binary.width),
                             height: height / Double(binary.height))
            found.append((DetectedSymbol(symbol: symbol, confidence: confidence, source: .immagine, box: box), component))
        }

        return prune(found)
    }

    // MARK: - Marks

    private struct InnerMarks {
        var inner: GlyphInner?
        var dots: Int
        var shaded: Bool
    }

    private static func innerMarks(of component: BinaryImage.Component,
                                   children: [BinaryImage.Component],
                                   base: GlyphBase) -> InnerMarks {
        let parentWidth = Double(component.width), parentHeight = Double(component.height)
        var dots = 0
        var verticalLines = 0
        var horizontalLines = 0
        var ring = false
        var blob = false
        var stripes = 0
        var shaded = false

        for child in children {
            let relativeWidth = Double(child.width) / parentWidth
            let relativeHeight = Double(child.height) / parentHeight
            let solidity = Double(child.pixels) / Double(max(1, child.width * child.height))
            let aspect = child.aspect

            if relativeWidth > 0.42, relativeHeight > 0.42, aspect > 0.72, aspect < 1.4, solidity < 0.55 {
                ring = true
            } else if aspect < 0.42, relativeHeight > 0.35 {
                verticalLines += 1
            } else if aspect > 2.4, relativeWidth > 0.30 {
                horizontalLines += 1
            } else if relativeWidth < 0.26, relativeHeight < 0.26, aspect > 0.6, aspect < 1.7, solidity > 0.55 {
                dots += 1
            } else if base == .triangle, solidity < 0.55, relativeHeight > 0.18, relativeHeight < 0.6 {
                stripes += 1
            } else if relativeWidth > 0.32, relativeHeight > 0.28, solidity > 0.32 {
                blob = true
            }

            // The corner stroke that means "in the shade" sits in the top-left eighth.
            let centreX = (Double(child.minX + child.maxX) / 2 - Double(component.minX)) / parentWidth
            let centreY = (Double(child.minY + child.maxY) / 2 - Double(component.minY)) / parentHeight
            if base == .square, centreX < 0.42, centreY < 0.42, solidity < 0.55,
               relativeWidth > 0.14, relativeWidth < 0.5, aspect > 0.55, aspect < 1.8 {
                shaded = true
            }
        }

        var inner: GlyphInner?
        if ring {
            inner = .tumbleCircle
        } else if verticalLines >= 2 {
            inner = .lineVerticalDouble
        } else if verticalLines == 1 {
            inner = .lineVertical
        } else if horizontalLines >= 2 {
            inner = .lineHorizontalDouble
        } else if horizontalLines == 1 {
            inner = .lineHorizontal
        } else if base == .triangle, stripes >= 2 {
            inner = .bleachStripes
        } else if base == .washtub, blob {
            inner = .hand
        }
        return InnerMarks(inner: inner, dots: dots, shaded: shaded)
    }

    /// Bars are drawn under the symbol, detached from it, and mean "go gentler".
    private static func barCount(below component: BinaryImage.Component,
                                 in components: [BinaryImage.Component]) -> Int {
        let band = Double(component.height) * 0.5
        let centre = Double(component.minX + component.maxX) / 2
        var count = 0
        for candidate in components {
            guard candidate.minY > component.maxY,
                  Double(candidate.minY) < Double(component.maxY) + band else { continue }
            guard Double(candidate.width) > Double(component.width) * 0.32,
                  Double(candidate.width) < Double(component.width) * 1.15,
                  candidate.height < max(4, component.height / 5) else { continue }
            let candidateCentre = Double(candidate.minX + candidate.maxX) / 2
            guard abs(candidateCentre - centre) < Double(component.width) * 0.3 else { continue }
            count += 1
        }
        return min(count, 2)
    }

    /// True when two strokes run corner to corner: the universal "don't". Each of
    /// the four arms is checked on its own, near the corner where nothing else is
    /// drawn, so a number inside the tub cannot pass for a cross.
    private static func isCrossed(_ binary: BinaryImage, _ component: BinaryImage.Component) -> Bool {
        let tolerance = max(1, component.height / 50)
        let corners = [(0.0, 0.0, 1.0, 1.0), (1.0, 0.0, -1.0, 1.0),
                       (0.0, 1.0, 1.0, -1.0), (1.0, 1.0, -1.0, -1.0)]
        var armsFound = 0
        for (startX, startY, stepX, stepY) in corners {
            var hits = 0, total = 0
            // Only the stretch just inside the corner, where the shape itself never
            // reaches but a prohibition stroke always does.
            var t = 0.04
            while t <= 0.25 {
                let x = component.minX + Int((startX + stepX * t) * Double(component.width - 1))
                let y = component.minY + Int((startY + stepY * t) * Double(component.height - 1))
                total += 1
                var hit = false
                for offsetY in -tolerance...tolerance where !hit {
                    for offsetX in -tolerance...tolerance where !hit {
                        if binary.isInk(x + offsetX, y + offsetY) { hit = true }
                    }
                }
                if hit { hits += 1 }
                t += 0.03
            }
            if total > 0, Double(hits) / Double(total) >= 0.85 { armsFound += 1 }
        }
        return armsFound >= 3
    }

    /// True when a ring is drawn inside the square, whether or not it survived as a
    /// component of its own.
    private static func hasInscribedRing(_ binary: BinaryImage, _ component: BinaryImage.Component) -> Bool {
        let centreX = Double(component.minX + component.maxX) / 2
        let centreY = Double(component.minY + component.maxY) / 2
        let tolerance = max(1, component.height / 40)
        for scale in [0.29, 0.32, 0.35] {
            let radiusX = Double(component.width) * scale
            let radiusY = Double(component.height) * scale
            var hits = 0
            let samples = 32
            for index in 0..<samples {
                let angle = Double(index) / Double(samples) * 2 * Double.pi
                let x = Int(centreX + cos(angle) * radiusX)
                let y = Int(centreY + sin(angle) * radiusY)
                var hit = false
                for offsetY in -tolerance...tolerance where !hit {
                    for offsetX in -tolerance...tolerance where !hit {
                        if binary.isInk(x + offsetX, y + offsetY) { hit = true }
                    }
                }
                if hit { hits += 1 }
            }
            if Double(hits) / Double(samples) >= 0.72 { return true }
        }
        return false
    }

    /// A stroke across the top-left corner: dry it out of the sun.
    private static func hasShadeCorner(_ binary: BinaryImage, _ component: BinaryImage.Component) -> Bool {
        let tolerance = max(1, component.height / 40)
        var hits = 0, total = 0
        var t = 0.12
        while t <= 0.40 {
            let x = component.minX + Int(t * Double(component.width - 1))
            let y = component.minY + Int((0.52 - t) * Double(component.height - 1))
            guard y >= component.minY else { break }
            total += 1
            var hit = false
            for offsetY in -tolerance...tolerance where !hit {
                for offsetX in -tolerance...tolerance where !hit {
                    if binary.isInk(x + offsetX, y + offsetY) { hit = true }
                }
            }
            if hit { hits += 1 }
            t += 0.04
        }
        return total > 0 && Double(hits) / Double(total) >= 0.8
    }

    /// Two puffs of steam with a line through them, drawn under the iron.
    private static func hasSteamMark(_ component: BinaryImage.Component,
                                     in components: [BinaryImage.Component]) -> Bool {
        let centre = Double(component.minX + component.maxX) / 2
        for candidate in components {
            guard candidate.minY > component.maxY,
                  Double(candidate.minY) < Double(component.maxY) + Double(component.height) * 0.35 else { continue }
            let relativeWidth = Double(candidate.width) / Double(component.width)
            let relativeHeight = Double(candidate.height) / Double(component.height)
            let solidity = Double(candidate.pixels) / Double(max(1, candidate.width * candidate.height))
            if relativeWidth > 0.35, relativeHeight > 0.14, relativeHeight < 0.5, solidity < 0.5 {
                return true
            }
        }
        return false
    }

    /// The number in the tub or the letter in the circle.
    private static func readLegend(_ component: BinaryImage.Component,
                                   base: GlyphBase,
                                   binary: BinaryImage,
                                   image: CGImage,
                                   readText: TextReader?) -> String? {
        guard let readText else { return nil }
        let insetX = Double(component.width) * (base == .washtub ? 0.16 : 0.14)
        let top = Double(component.minY) + Double(component.height) * (base == .washtub ? 0.30 : 0.14)
        let bottom = Double(component.maxY) - Double(component.height) * (base == .washtub ? 0.08 : 0.14)
        let region = CGRect(x: (Double(component.minX) + insetX) / Double(binary.width),
                            y: top / Double(binary.height),
                            width: (Double(component.width) - insetX * 2) / Double(binary.width),
                            height: (bottom - top) / Double(binary.height))
        guard region.width > 0, region.height > 0, let raw = readText(image, region) else { return nil }

        let cleaned = raw.uppercased().filter { $0.isNumber || "PFW".contains($0) }
        guard !cleaned.isEmpty else { return nil }
        if base == .circle {
            for letter in ["P", "F", "W"] where cleaned.contains(letter) { return letter }
            return nil
        }
        let digits = cleaned.filter(\.isNumber)
        guard let value = Int(digits.prefix(2)) else { return nil }
        let known = [30, 40, 50, 60, 70, 95]
        if known.contains(value) { return "\(value)" }
        if value == 90 { return "95" }
        return nil
    }

    // MARK: - Scoring and clean-up

    private static func confidence(match: (base: GlyphBase, distance: Double, margin: Double),
                                   spec: GlyphSpec, matched: CareSymbol) -> Double {
        let fit = 1 - min(1, match.distance / 0.30)
        let separation = min(1, match.margin / 0.25)
        var score = 0.45 + 0.35 * fit + 0.25 * separation
        if matched.glyph != spec { score -= 0.18 }      // the lookup had to approximate
        return min(0.99, max(0.2, score))
    }

    /// Drops the frame printed around a row of symbols, anything sitting inside an
    /// accepted symbol, and the odd blob that is nowhere near the others in size.
    private static func prune(_ found: [(symbol: DetectedSymbol, component: BinaryImage.Component)]) -> [DetectedSymbol] {
        guard !found.isEmpty else { return [] }

        var kept = found.filter { candidate in
            let enclosed = found.filter { $0.component.minX != candidate.component.minX
                && candidate.component.contains($0.component) }
            return enclosed.count < 2
        }
        kept = kept.filter { candidate in
            !kept.contains { other in
                other.component.pixels > candidate.component.pixels && other.component.contains(candidate.component)
            }
        }
        guard kept.count > 2 else { return kept.map(\.symbol) }

        let heights = kept.map { Double($0.component.height) }.sorted()
        let median = heights[heights.count / 2]
        return kept
            .filter { abs(Double($0.component.height) - median) < median * 0.6 }
            .sorted { $0.component.minX < $1.component.minX }
            .map(\.symbol)
    }
}
