import SwiftUI

/// A care symbol, drawn rather than shipped: the same geometry the detector
/// matches against, so what the app shows is exactly what it looked for.
struct CareGlyphView: View {
    let spec: GlyphSpec
    var size: CGFloat = 44
    var weight: CGFloat = 1

    var body: some View {
        Canvas { context, canvasSize in
            let lineWidth = CareGlyphPath.lineWidth(for: canvasSize.width) * weight
            let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: lineWidth, dy: lineWidth)
            let drawing = CareGlyphPath.drawing(for: spec, in: rect)
            let shading = GraphicsContext.Shading.color(.primary)

            for path in drawing.strokes {
                context.stroke(Path(path), with: shading,
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
            for path in drawing.fills {
                context.fill(Path(path), with: shading)
            }
            if let text = drawing.text {
                let font = Font.system(size: text.rect.height * 0.98, weight: .semibold, design: .rounded)
                let resolved = context.resolve(Text(text.string).font(font).foregroundStyle(.primary))
                let measured = resolved.measure(in: canvasSize)
                let scale = min(text.rect.width / max(measured.width, 1), 1)
                context.drawLayer { layer in
                    layer.translateBy(x: text.rect.midX, y: text.rect.midY)
                    layer.scaleBy(x: scale, y: scale)
                    layer.draw(resolved, at: .zero, anchor: .center)
                }
            }
        }
        .frame(width: size, height: size * (1 + CareGlyphPath.skirt(for: spec)))
        .accessibilityHidden(true)
    }
}

/// Symbol plus its name, the pairing used everywhere a symbol is listed.
struct CareSymbolRow: View {
    let symbol: CareSymbol
    var footnote: String?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            CareGlyphView(spec: symbol.glyph, size: 40)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(symbol.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text(symbol.meaning)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let footnote {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(symbol.title). \(symbol.meaning)")
    }
}
