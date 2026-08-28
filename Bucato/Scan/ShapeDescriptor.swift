import CoreGraphics
import Foundation

/// A silhouette reduced to numbers: how much ink each of sixteen rows carries, how
/// far the middle of that row drifts sideways, and how much of the box is filled. Enough to tell
/// a washtub from a triangle, an iron from a circle — and blind to line thickness,
/// scale and the state of the printing.
struct ShapeDescriptor {
    static let samples = 16

    var widths: [Double]
    var centres: [Double]
    var fill: Double

    /// A cross stretches the bounding box past the shape it forbids: the two extra
    /// strips at the ends hold nothing but a stroke each. `trimArms` throws those
    /// away, capped so a triangle never loses its apex.
    static func make(filled: [UInt8], width: Int, height: Int, trimArms: Bool = false) -> ShapeDescriptor? {
        var minX = width, maxX = -1, minY = height, maxY = -1  // trimmed in place below
        var count = 0
        for y in 0..<height {
            for x in 0..<width where filled[y * width + x] == 1 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
                count += 1
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }

        if trimArms {
            var rowCounts = [Int](repeating: 0, count: maxY - minY + 1)
            var columnCounts = [Int](repeating: 0, count: maxX - minX + 1)
            for y in minY...maxY {
                for x in minX...maxX where filled[y * width + x] == 1 {
                    rowCounts[y - minY] += 1
                    columnCounts[x - minX] += 1
                }
            }
            func trim(_ counts: [Int]) -> (Int, Int) {
                let threshold = Double(counts.max() ?? 0) * 0.28
                let cap = max(1, counts.count * 15 / 100)
                var low = 0, high = counts.count - 1
                while low < cap, Double(counts[low]) < threshold { low += 1 }
                while high > counts.count - 1 - cap, Double(counts[high]) < threshold { high -= 1 }
                return (low, high)
            }
            let (rowLow, rowHigh) = trim(rowCounts)
            let (columnLow, columnHigh) = trim(columnCounts)
            minY += rowLow; maxY -= (rowCounts.count - 1 - rowHigh)
            minX += columnLow; maxX -= (columnCounts.count - 1 - columnHigh)
            guard maxX > minX, maxY > minY else { return nil }
            count = 0
            for y in minY...maxY {
                for x in minX...maxX where filled[y * width + x] == 1 { count += 1 }
            }
        }

        let boxWidth = Double(maxX - minX + 1)
        let boxHeight = Double(maxY - minY + 1)
        guard boxWidth >= 4, boxHeight >= 4 else { return nil }

        var widths = [Double](repeating: 0, count: samples)
        var centres = [Double](repeating: 0.5, count: samples)
        for index in 0..<samples {
            let y = minY + Int((Double(index) + 0.5) / Double(samples) * boxHeight)
            guard y >= 0, y < height else { continue }
            var pixels = 0, sum = 0
            for x in minX...maxX where filled[y * width + x] == 1 {
                pixels += 1
                sum += x
            }
            guard pixels > 0 else { continue }
            widths[index] = Double(pixels) / boxWidth
            centres[index] = (Double(sum) / Double(pixels) - Double(minX)) / boxWidth
        }

        return ShapeDescriptor(widths: widths, centres: centres, fill: Double(count) / (boxWidth * boxHeight))
    }

    /// Zero means identical. Sideways drift counts double: it is the only thing
    /// that separates the iron from every other symmetric shape.
    func distance(to other: ShapeDescriptor) -> Double {
        var widthError = 0.0, centreError = 0.0
        for index in 0..<Self.samples {
            widthError += pow(widths[index] - other.widths[index], 2)
            centreError += pow(centres[index] - other.centres[index], 2)
        }
        let profile = (widthError / Double(Self.samples)) + 2 * (centreError / Double(Self.samples))
        return sqrt(profile) + 0.6 * abs(fill - other.fill)
    }
}

/// The reference descriptors, obtained by drawing each outline exactly as the app
/// draws it and then measuring it exactly as a photographed one is measured. A
/// forbidden symbol is matched against a forbidden template: the cross changes the
/// shape too much to pretend otherwise.
enum ShapeTemplates {

    private static let bases: [GlyphBase] = [.washtub, .triangle, .square, .iron, .circle]

    private static let plain: [(base: GlyphBase, descriptor: ShapeDescriptor)] = build(crossed: false)
    private static let struck: [(base: GlyphBase, descriptor: ShapeDescriptor)] = build(crossed: true)

    /// Best matching outline, with both the distance and how far ahead of the
    /// runner-up it is — being close to one template matters less than being
    /// clearly closer to it than to the other four.
    static func classify(_ descriptor: ShapeDescriptor, crossed: Bool = false)
        -> (base: GlyphBase, distance: Double, margin: Double)? {
        var scored = (crossed ? struck : plain)
            .map { (base: $0.base, distance: descriptor.distance(to: $0.descriptor)) }
        scored.sort { $0.distance < $1.distance }
        guard let best = scored.first else { return nil }
        let runnerUp = scored.count > 1 ? scored[1].distance : best.distance + 1
        return (best.base, best.distance, runnerUp - best.distance)
    }

    private static func build(crossed: Bool) -> [(base: GlyphBase, descriptor: ShapeDescriptor)] {
        bases.compactMap { base in
            guard let descriptor = measure(GlyphSpec(base: base, crossed: crossed)) else { return nil }
            return (base, descriptor)
        }
    }

    /// Renders one symbol and runs it through the same steps a photograph goes
    /// through, so template and observation are measured by identical code.
    private static func measure(_ spec: GlyphSpec) -> ShapeDescriptor? {
        guard let image = GlyphRaster.image(spec, side: 220),
              let binary = BinaryImage.make(from: image),
              let component = binary.components(minPixels: 20).max(by: { $0.pixels < $1.pixels }),
              let silhouette = binary.silhouette(of: component)
        else { return nil }
        return ShapeDescriptor.make(filled: silhouette.filled, width: silhouette.width,
                                    height: silhouette.height, trimArms: spec.crossed)
    }
}
