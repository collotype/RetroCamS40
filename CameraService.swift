import Foundation
import AVFoundation
import Photos

final class CameraService: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var useRetroFilter: Bool = true
    @Published var addDateStamp: Bool = true

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "retrocam.session.queue")
    private let photoOutput = AVCapturePhotoOutput()

    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var currentPosition: AVCaptureDevice.Position = .back
    private var hasCameraAccess = false
    private var hasPhotoAccess = false

    override init() {
        super.init()
        requestPermissions()
    }

    func startIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.hasCameraAccess else { return }

            if !self.isConfigured {
                self.configureSession()
            }

            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let currentInput = self.videoInput else { return }

            self.session.beginConfiguration()
            self.session.removeInput(currentInput)

            self.currentPosition = (self.currentPosition == .back) ? .front : .back

            do {
                let device = try self.makeCamera(position: self.currentPosition)
                let newInput = try AVCaptureDeviceInput(device: device)

                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoInput = newInput
                } else {
                    self.session.addInput(currentInput)
                    self.videoInput = currentInput
                }
            } catch {
                self.session.addInput(currentInput)
                self.videoInput = currentInput
            }

            self.session.commitConfiguration()
        }
    }

    func takePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isConfigured else { return }

            let settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [
                    AVVideoCodecKey: AVVideoCodecType.jpeg
                ])
            } else {
                settings = AVCapturePhotoSettings()
            }

            settings.isHighResolutionPhotoEnabled = false
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func toggleRecording() {
        // Пока оставляем пустым
    }

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            self.hasCameraAccess = granted

            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
                guard let self else { return }
                self.hasPhotoAccess = (status == .authorized || status == .limited)
            }
        }
    }

    private func configureSession() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        do {
            let camera = try makeCamera(position: currentPosition)
            let input = try AVCaptureDeviceInput(device: camera)

            if session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            session.commitConfiguration()
            isConfigured = true
        } catch {
            session.commitConfiguration()
            isConfigured = false
        }
    }

    private func makeCamera(position: AVCaptureDevice.Position) throws -> AVCaptureDevice {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            return device
        }

        if let fallback = AVCaptureDevice.default(for: .video) {
            return fallback
        }

        throw NSError(
            domain: "RetroCam",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Камера недоступна"]
        )
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if error != nil { return }
        guard let data = photo.fileDataRepresentation() else { return }
        guard hasPhotoAccess else { return }

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            request.addResource(with: .photo, data: data, options: options)
        })
    }
}
