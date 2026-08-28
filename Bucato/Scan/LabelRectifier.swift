import CoreGraphics
import CoreImage
import Foundation
import Vision

/// Finds the label in a hand-held photo and flattens it.
///
/// The system document scanner used to do this, at the cost of two extra taps.
/// Doing it here keeps the scan to a single shutter press: the label is a bright
/// quadrilateral against the garment, which is exactly what Vision's rectangle
/// detector is for, and a perspective correction turns it back into a rectangle.
enum LabelRectifier {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// The flattened label, or nil when nothing rectangular stood out — in which
    /// case the caller should just use the photo as it is.
    static func rectify(_ image: CGImage) -> CGImage? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.12   // labels are wide strips
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.22
        request.minimumConfidence = 0.5
        request.quadratureTolerance = 32
        request.maximumObservations = 6

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch { return nil }

        guard let best = (request.results ?? []).max(by: { area(of: $0) < area(of: $1) }),
              area(of: best) > 0.16
        else { return nil }

        let width = CGFloat(image.width), height = CGFloat(image.height)
        // Vision measures from the bottom left, and so does Core Image.
        let corners = expand([
            best.bottomLeft, best.bottomRight, best.topRight, best.topLeft,
        ], by: 0.02).map { CGPoint(x: $0.x * width, y: $0.y * height) }

        let filter = CIFilter(name: "CIPerspectiveCorrection")
        filter?.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgPoint: corners[0]), forKey: "inputBottomLeft")
        filter?.setValue(CIVector(cgPoint: corners[1]), forKey: "inputBottomRight")
        filter?.setValue(CIVector(cgPoint: corners[2]), forKey: "inputTopRight")
        filter?.setValue(CIVector(cgPoint: corners[3]), forKey: "inputTopLeft")

        guard let output = filter?.outputImage,
              output.extent.width > 120, output.extent.height > 60,
              let rendered = context.createCGImage(output, from: output.extent)
        else { return nil }
        return rendered
    }

    private static func area(of observation: VNRectangleObservation) -> CGFloat {
        observation.boundingBox.width * observation.boundingBox.height
    }

    /// Pushes the corners outwards a little: a symbol printed near the edge of the
    /// label should not be cut in half by the crop.
    private static func expand(_ corners: [CGPoint], by amount: CGFloat) -> [CGPoint] {
        let centreX = corners.reduce(0) { $0 + $1.x } / CGFloat(corners.count)
        let centreY = corners.reduce(0) { $0 + $1.y } / CGFloat(corners.count)
        return corners.map { corner in
            CGPoint(x: min(1, max(0, corner.x + (corner.x - centreX) * amount)),
                    y: min(1, max(0, corner.y + (corner.y - centreY) * amount)))
        }
    }
}
