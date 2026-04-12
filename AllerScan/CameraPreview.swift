import AVFoundation
import Combine
import ImageIO
import SwiftUI
import UIKit

@MainActor
final class CameraCaptureModel: NSObject, ObservableObject {
    @Published var statusMessage = "Initializing camera..."
    @Published var isConfigured = false

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<UIImage, Error>?
    private let maxCaptureDimension: CGFloat = 2200

    func configureIfNeeded() async {
        guard !isConfigured else { return }

        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        guard authorization == .authorized else {
            statusMessage = "Camera access is required to scan labels."
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput)
        else {
            statusMessage = "This device cannot configure the camera."
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = false
        session.commitConfiguration()
        session.startRunning()
        statusMessage = "Align the ingredient label inside the frame."
        isConfigured = true
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraCaptureModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                continuation?.resume(throwing: error)
                continuation = nil
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = downsampleImage(from: data, maxDimension: maxCaptureDimension)
            else {
                continuation?.resume(throwing: ScanError.imageEncodingFailed)
                continuation = nil
                return
            }

            continuation?.resume(returning: image)
            continuation = nil
        }
    }
}

private func downsampleImage(from data: Data, maxDimension: CGFloat) -> UIImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
        return nil
    }

    let downsampleOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: false,
        kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
        kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
    ] as CFDictionary

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
        return nil
    }

    return UIImage(cgImage: cgImage)
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
