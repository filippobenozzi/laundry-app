import AVFoundation
import Foundation
import UIKit

/// The camera behind the one-tap scan: a live preview, a shutter, a torch. No
/// review screen, no "keep scan" — the photo goes straight to the reader.
@Observable
final class CameraController: NSObject {

    enum State: Equatable {
        case idle
        case running
        case denied
        case unavailable
    }

    private(set) var state: State = .idle
    private(set) var isTorchOn = false

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "im.filippo.bucato.camera")
    private var device: AVCaptureDevice?
    private var configured = false
    private var pending: ((UIImage?) -> Void)?

    weak var previewLayer: AVCaptureVideoPreviewLayer?

    var captureSession: AVCaptureSession { session }

    // MARK: - Lifecycle

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                state = .denied
                return
            }
        default:
            state = .denied
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            if !configured { configure() }
            guard configured else {
                DispatchQueue.main.async { self.state = .unavailable }
                return
            }
            if !session.isRunning { session.startRunning() }
            DispatchQueue.main.async { self.state = .running }
        }
    }

    func stop() {
        setTorch(on: false)
        queue.async { [weak self] in
            guard let self, session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input), session.canAddOutput(output)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.addOutput(output)
        output.maxPhotoQualityPrioritization = .quality
        device = camera

        // A care label is held a few centimetres away: tell the lens to look there.
        if (try? camera.lockForConfiguration()) != nil {
            if camera.isFocusModeSupported(.continuousAutoFocus) { camera.focusMode = .continuousAutoFocus }
            if camera.isAutoFocusRangeRestrictionSupported { camera.autoFocusRangeRestriction = .near }
            if camera.isExposureModeSupported(.continuousAutoExposure) { camera.exposureMode = .continuousAutoExposure }
            camera.unlockForConfiguration()
        }

        session.commitConfiguration()
        configured = true
    }

    // MARK: - Controls

    func focus(at point: CGPoint) {
        guard let device, let previewLayer else { return }
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        queue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        }
    }

    var hasTorch: Bool { device?.hasTorch ?? false }

    func toggleTorch() { setTorch(on: !isTorchOn) }

    private func setTorch(on: Bool) {
        guard let device, device.hasTorch else { return }
        queue.async { [weak self] in
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            DispatchQueue.main.async { self?.isTorchOn = on }
        }
    }

    // MARK: - Shutter

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        guard state == .running else { return completion(nil) }
        pending = completion
        queue.async { [weak self] in
            guard let self else { return }
            let settings = output.availablePhotoCodecTypes.contains(.jpeg)
                ? AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                : AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            settings.flashMode = .off
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            output.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        DispatchQueue.main.async { [weak self] in
            let completion = self?.pending
            self?.pending = nil
            completion?(image)
        }
    }
}
