import AVFoundation
import SwiftUI

/// One tap and the label is read. The camera stays open until something is
/// recognised, so a bad shot costs a second, not a trip back through two screens.
struct CameraScannerView: View {
    var onRead: (LabelAnalyzer.Analysis) -> Void
    var onCancel: () -> Void

    @State private var camera = CameraController()
    @State private var isReading = false
    @State private var message: String?
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.state {
            case .running:
                CameraPreview(controller: camera)
                    .ignoresSafeArea()
                    .overlay { guide }
                    .onTapGesture { point in camera.focus(at: point) }
            case .denied:
                unavailable("Bucato non ha accesso alla fotocamera. Puoi darglielo da Impostazioni › Bucato.")
            case .unavailable:
                unavailable("Su questo dispositivo non c'è una fotocamera utilizzabile. Scegli una foto dalla libreria.")
            case .idle:
                ProgressView().tint(.white)
            }

            if flash { Color.white.ignoresSafeArea().transition(.opacity) }

            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    // MARK: - Pieces

    /// A frame to hold the label in. Nothing is cropped to it — the app finds the
    /// label by itself — but it tells you how close to get.
    private var guide: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 0.84
            let height = width * 0.62
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [9, 7]))
                .frame(width: width, height: height)
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.44)
                .allowsHitTesting(false)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                camera.stop()
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .accessibilityLabel("Chiudi")

            Spacer()

            if camera.hasTorch {
                Button { camera.toggleTorch() } label: {
                    Image(systemName: camera.isTorchOn ? "bolt.fill" : "bolt.slash")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(camera.isTorchOn ? .black : .white)
                        .frame(width: 44, height: 44)
                        .background(camera.isTorchOn ? AnyShapeStyle(.white) : AnyShapeStyle(.black.opacity(0.35)),
                                    in: Circle())
                }
                .accessibilityLabel("Torcia")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var bottomBar: some View {
        VStack(spacing: 18) {
            Text(message ?? "Inquadra l'etichetta e scatta. Più vicina è, meglio si legge.")
                .font(.footnote)
                .foregroundStyle(message == nil ? .white.opacity(0.85) : .white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.vertical, message == nil ? 0 : 10)
                .background(message == nil ? AnyShapeStyle(.clear) : AnyShapeStyle(.black.opacity(0.55)),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: shoot) {
                ZStack {
                    Circle().strokeBorder(.white, lineWidth: 4).frame(width: 76, height: 76)
                    if isReading {
                        ProgressView().tint(.black)
                            .frame(width: 62, height: 62)
                            .background(.white, in: Circle())
                    } else {
                        Circle().fill(.white).frame(width: 62, height: 62)
                    }
                }
            }
            .disabled(isReading || camera.state != .running)
            .accessibilityLabel("Scatta e leggi l'etichetta")
        }
        .padding(.bottom, 34)
    }

    private func unavailable(_ text: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.6))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Shutter

    private func shoot() {
        guard !isReading else { return }
        Haptics.tap()
        withAnimation(.linear(duration: 0.06)) { flash = true }
        isReading = true
        message = nil

        camera.capture { image in
            withAnimation(.easeOut(duration: 0.18)) { flash = false }
            guard let image else {
                isReading = false
                message = "Lo scatto non è riuscito. Riprova."
                return
            }
            Task {
                let analysis = await LabelAnalyzer.analyze(image)
                isReading = false
                guard let analysis, !analysis.reading.isEmpty else {
                    Haptics.warning()
                    message = "Non ho letto niente. Avvicinati, tieni l'etichetta distesa e accendi la torcia."
                    return
                }
                Haptics.success()
                camera.stop()
                onRead(analysis)
            }
        }
    }
}

/// The live preview layer, wrapped for SwiftUI.
private struct CameraPreview: UIViewRepresentable {
    let controller: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = controller.captureSession
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        controller.previewLayer = view.previewLayer
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if view.previewLayer.session == nil { view.previewLayer.session = controller.captureSession }
        controller.previewLayer = view.previewLayer
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
