import CoreGraphics
import Foundation
import Vision

/// Vision, wrapped twice: once for the block of text on a label, once for the two
/// characters printed inside a symbol.
enum TextRecognizer {

    struct Line {
        let text: String
        /// Normalised to the image, origin top-left.
        let box: CGRect
        let confidence: Float
    }

    /// Every language a European care label is likely to repeat itself in.
    static let languages = ["it-IT", "en-US", "fr-FR", "de-DE", "es-ES", "pt-PT", "nl-NL"]

    static func lines(in image: CGImage) -> [Line] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Labels are lists of fibres and abbreviations; autocorrect only invents words.
        request.usesLanguageCorrection = false
        request.recognitionLanguages = languages
        request.minimumTextHeight = 0.008

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch { return [] }

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            // Vision measures from the bottom left; everything else here is top-down.
            let box = observation.boundingBox
            return Line(text: candidate.string,
                        box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height),
                        confidence: candidate.confidence)
        }
    }

    static func text(in image: CGImage) -> String {
        lines(in: image)
            .sorted { $0.box.minY < $1.box.minY }
            .map(\.text)
            .joined(separator: "\n")
    }

    /// The number in a washtub or the letter in a circle: a crop of a few dozen
    /// pixels, blown up, with the alphabet narrowed down to what a label can print.
    static func legend(in image: CGImage, region: CGRect) -> String? {
        let pixels = CGRect(x: region.minX * CGFloat(image.width),
                            y: region.minY * CGFloat(image.height),
                            width: region.width * CGFloat(image.width),
                            height: region.height * CGFloat(image.height)).integral
        guard pixels.width >= 6, pixels.height >= 6,
              let crop = image.cropping(to: pixels),
              let enlarged = scale(crop, by: max(2, 120 / max(pixels.width, pixels.height)))
        else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.customWords = ["30", "40", "50", "60", "70", "95", "P", "F", "W"]

        let handler = VNImageRequestHandler(cgImage: enlarged, options: [:])
        do { try handler.perform([request]) } catch { return nil }

        let candidates = (request.results ?? []).compactMap { $0.topCandidates(1).first }
        guard let best = candidates.max(by: { $0.confidence < $1.confidence }), best.confidence > 0.3 else { return nil }
        return best.string
    }

    private static func scale(_ image: CGImage, by factor: CGFloat) -> CGImage? {
        let width = Int((CGFloat(image.width) * factor).rounded())
        let height = Int((CGFloat(image.height) * factor).rounded())
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
