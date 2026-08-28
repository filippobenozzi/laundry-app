import CoreGraphics
import Foundation

/// A photo of a label reduced to ink and paper. Everything the symbol detector
/// does — finding the drawings, filling them, measuring them — happens on this.
struct BinaryImage {
    let width: Int
    let height: Int
    /// 1 where there is ink, 0 where there is paper. Row-major.
    var ink: [UInt8]

    @inline(__always) func isInk(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, y >= 0, x < width, y < height else { return false }
        return ink[y * width + x] == 1
    }

    // MARK: - From a photo

    /// Renders the image to grey, then thresholds every pixel against the average
    /// of its neighbourhood (Bradley's method). A local threshold is what makes a
    /// crumpled label with a shadow across it still readable.
    static func make(from image: CGImage, maxDimension: Int = 1400) -> BinaryImage? {
        let scale = min(1.0, Double(maxDimension) / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))

        var grey = [UInt8](repeating: 0, count: width * height)
        let drawn: Bool = grey.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(data: base, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return false }
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        // Care labels are usually black on white, but a woven black label prints the
        // symbols in white. Flip the whole thing rather than teaching every later
        // step about polarity.
        let average = grey.reduce(0) { $0 + Int($1) } / max(1, grey.count)
        if average < 110 {
            for index in grey.indices { grey[index] = 255 &- grey[index] }
        }

        return BinaryImage(grey: grey, width: width, height: height)
    }

    /// Adaptive threshold over an 8-bit grey buffer.
    init(grey: [UInt8], width: Int, height: Int) {
        self.width = width
        self.height = height

        // Integral image, one row and column of zeroes so the window maths has no
        // special cases at the edges.
        let stride = width + 1
        var integral = [Int32](repeating: 0, count: stride * (height + 1))
        for y in 0..<height {
            var rowSum: Int32 = 0
            for x in 0..<width {
                rowSum += Int32(grey[y * width + x])
                integral[(y + 1) * stride + (x + 1)] = integral[y * stride + (x + 1)] + rowSum
            }
        }

        let window = max(15, min(width, height) / 16) | 1
        let radius = window / 2
        let bias = 0.86   // ink is at least 14 % darker than its surroundings

        var ink = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            let y0 = max(0, y - radius), y1 = min(height - 1, y + radius)
            for x in 0..<width {
                let x0 = max(0, x - radius), x1 = min(width - 1, x + radius)
                let count = Int32((x1 - x0 + 1) * (y1 - y0 + 1))
                let sum = integral[(y1 + 1) * stride + (x1 + 1)]
                    - integral[y0 * stride + (x1 + 1)]
                    - integral[(y1 + 1) * stride + x0]
                    + integral[y0 * stride + x0]
                if Int32(grey[y * width + x]) * count < Int32(Double(sum) * bias) {
                    ink[y * width + x] = 1
                }
            }
        }
        self.ink = ink
    }

    // MARK: - Connected components

    struct Component {
        var minX: Int
        var minY: Int
        var maxX: Int
        var maxY: Int
        var pixels: Int

        var width: Int { maxX - minX + 1 }
        var height: Int { maxY - minY + 1 }
        var box: CGRect { CGRect(x: minX, y: minY, width: width, height: height) }
        var aspect: Double { Double(width) / Double(max(1, height)) }

        func contains(_ other: Component) -> Bool {
            other.minX >= minX && other.maxX <= maxX && other.minY >= minY && other.maxY <= maxY
        }
    }

    /// Eight-connected labelling with union-find. Returns one entry per blob of ink.
    func components(minPixels: Int = 24) -> [Component] {
        var labels = [Int32](repeating: 0, count: width * height)
        var parent: [Int32] = [0]

        func find(_ value: Int32) -> Int32 {
            var root = value
            while parent[Int(root)] != root { root = parent[Int(root)] }
            var walk = value
            while parent[Int(walk)] != root { let next = parent[Int(walk)]; parent[Int(walk)] = root; walk = next }
            return root
        }
        func union(_ a: Int32, _ b: Int32) {
            let rootA = find(a), rootB = find(b)
            if rootA != rootB { parent[Int(max(rootA, rootB))] = min(rootA, rootB) }
        }

        for y in 0..<height {
            for x in 0..<width where ink[y * width + x] == 1 {
                var neighbours: [Int32] = []
                if x > 0, labels[y * width + x - 1] != 0 { neighbours.append(labels[y * width + x - 1]) }
                if y > 0 {
                    if labels[(y - 1) * width + x] != 0 { neighbours.append(labels[(y - 1) * width + x]) }
                    if x > 0, labels[(y - 1) * width + x - 1] != 0 { neighbours.append(labels[(y - 1) * width + x - 1]) }
                    if x < width - 1, labels[(y - 1) * width + x + 1] != 0 { neighbours.append(labels[(y - 1) * width + x + 1]) }
                }
                if neighbours.isEmpty {
                    let next = Int32(parent.count)
                    parent.append(next)
                    labels[y * width + x] = next
                } else {
                    let smallest = neighbours.min()!
                    labels[y * width + x] = smallest
                    for neighbour in neighbours where neighbour != smallest { union(smallest, neighbour) }
                }
            }
        }

        var boxes: [Int32: Component] = [:]
        for y in 0..<height {
            for x in 0..<width where labels[y * width + x] != 0 {
                let root = find(labels[y * width + x])
                if var existing = boxes[root] {
                    existing.minX = min(existing.minX, x); existing.maxX = max(existing.maxX, x)
                    existing.minY = min(existing.minY, y); existing.maxY = max(existing.maxY, y)
                    existing.pixels += 1
                    boxes[root] = existing
                } else {
                    boxes[root] = Component(minX: x, minY: y, maxX: x, maxY: y, pixels: 1)
                }
            }
        }
        return boxes.values.filter { $0.pixels >= minPixels }.sorted { $0.minX < $1.minX }
    }

    // MARK: - Silhouette

    /// The solid shape an outline encloses: dilate a little so a broken stroke still
    /// closes, flood the outside, and call everything the flood never reached inside.
    /// Returns nil when the outline leaks, which is the honest answer for a smudge.
    func silhouette(of component: Component, padding: Int = 3) -> Silhouette? {
        let w = component.width + padding * 2
        let h = component.height + padding * 2
        guard w > 4, h > 4 else { return nil }

        var mask = [UInt8](repeating: 0, count: w * h)
        for y in 0..<component.height {
            for x in 0..<component.width where isInk(component.minX + x, component.minY + y) {
                mask[(y + padding) * w + (x + padding)] = 1
            }
        }

        // Close hairline gaps left by the threshold.
        var dilated = mask
        for y in 0..<h {
            for x in 0..<w where mask[y * w + x] == 1 {
                for dy in -1...1 {
                    for dx in -1...1 {
                        let ny = y + dy, nx = x + dx
                        if ny >= 0, ny < h, nx >= 0, nx < w { dilated[ny * w + nx] = 1 }
                    }
                }
            }
        }

        var outside = [UInt8](repeating: 0, count: w * h)
        var stack = [0]
        outside[0] = 1
        while let index = stack.popLast() {
            let x = index % w, y = index / w
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                let neighbour = ny * w + nx
                guard outside[neighbour] == 0, dilated[neighbour] == 0 else { continue }
                outside[neighbour] = 1
                stack.append(neighbour)
            }
        }

        var filled = [UInt8](repeating: 0, count: w * h)
        var filledCount = 0
        for index in 0..<(w * h) where outside[index] == 0 {
            filled[index] = 1
            filledCount += 1
        }
        // When an outline is broken the flood leaks inside and the "silhouette"
        // collapses onto the stroke itself. That is not a shape worth measuring.
        let strokeArea = dilated.reduce(0) { $0 + Int($1) }
        guard filledCount > strokeArea * 11 / 10 else { return nil }

        return Silhouette(width: w, height: h, padding: padding, filled: filled,
                          ink: mask, filledPixels: filledCount, inkPixels: component.pixels)
    }

    struct Silhouette {
        let width: Int
        let height: Int
        let padding: Int
        let filled: [UInt8]
        let ink: [UInt8]
        let filledPixels: Int
        let inkPixels: Int
    }
}
