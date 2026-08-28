import CoreGraphics
import Foundation
import UIKit

/// Puts the two readings of a label together: the drawings and the words.
enum LabelAnalyzer {

    struct Analysis {
        var reading: LabelReading
        /// The straightened photo the boxes refer to, for showing back what was seen.
        var image: CGImage
    }

    static func analyze(_ image: UIImage) async -> Analysis? {
        guard let cgImage = upright(image) else { return nil }
        return await analyze(cgImage)
    }

    static func analyze(_ cgImage: CGImage) async -> Analysis {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: perform(cgImage))
            }
        }
    }

    private static func perform(_ cgImage: CGImage) -> Analysis {
        // A photo taken by hand holds the label at an angle. Flatten it first: the
        // detector measures shapes, and perspective is the one distortion it cannot
        // measure its way out of.
        if let flattened = LabelRectifier.rectify(cgImage) {
            let analysis = read(flattened)
            // The crop can land on the wrong rectangle — a pocket, a seam. If it
            // came back with nothing, the whole photo deserves a look.
            if !analysis.reading.isEmpty { return analysis }
        }
        return read(cgImage)
    }

    private static func read(_ cgImage: CGImage) -> Analysis {
        let detection = SymbolDetector.detect(in: cgImage) { image, region in
            TextRecognizer.legend(in: image, region: region)
        }
        let text = TextRecognizer.text(in: detection.image)
        let composition = CompositionParser.parse(text)
        let symbols = merge(detected: detection.symbols, hints: CareTextHints.hints(in: text))

        return Analysis(
            reading: LabelReading(composition: composition, symbols: symbols, rawText: text),
            image: detection.image)
    }

    /// One instruction per family. A symbol read from the picture wins, unless the
    /// label also spells the instruction out in words and the drawing was a guess —
    /// words are the surer of the two.
    private static func merge(detected: [DetectedSymbol], hints: [DetectedSymbol]) -> [DetectedSymbol] {
        var byFamily: [CareFamily: DetectedSymbol] = [:]
        for symbol in detected {
            let family = symbol.symbol.family
            if let existing = byFamily[family], existing.confidence >= symbol.confidence { continue }
            byFamily[family] = symbol
        }
        for hint in hints {
            let family = hint.symbol.family
            guard let existing = byFamily[family] else {
                byFamily[family] = hint
                continue
            }
            if existing.symbol.id == hint.symbol.id {
                // Seen twice, two ways: that is as sure as this app gets.
                byFamily[family] = DetectedSymbol(symbol: existing.symbol, confidence: 0.99,
                                                  source: existing.source, box: existing.box)
            } else if existing.confidence < hint.confidence {
                byFamily[family] = hint
            }
        }
        return CareFamily.allCases.compactMap { byFamily[$0] }
    }

    /// Redraws the photo the right way up: Vision and CoreGraphics both ignore the
    /// orientation flag a camera leaves behind.
    static func upright(_ image: UIImage) -> CGImage? {
        guard image.imageOrientation != .up else { return image.cgImage }
        let format = UIGraphicsImageRendererFormat.default()
        // Redraw at the photo's own resolution: reading a label needs every pixel.
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let redrawn = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return redrawn.cgImage
    }
}
