import Foundation
import AVFoundation
import Photos
import UIKit
import CoreImage
import CoreMedia
import QuartzCore

final class CameraService: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var useRetroFilter: Bool = true
    @Published var addDateStamp: Bool = false
    @Published var selectedPreset: RetroPreset = .pointAndShoot
    @Published var previewImage: UIImage?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "retrocam.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext(options: nil)

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var currentPosition: AVCaptureDevice.Position = .back
    private var hasPhotoAccess = false
    private var hasMicrophoneAccess = false
    private var lastPreviewTimestamp: CFTimeInterval = 0

    override init() {
        super.init()
        requestPhotoPermission()
        requestMicrophonePermission()
    }

    func startIfNeeded() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.startSession()
                }
            }
        default:
            break
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

                self.configureConnections()
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

            if let connection = self.photoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func toggleRecording() {
        // Видео временно отключено специально.
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                self.configureSession()
            }

            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func requestPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            hasPhotoAccess = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] newStatus in
                guard let self else { return }
                self.hasPhotoAccess = (newStatus == .authorized || newStatus == .limited)
            }
        default:
            hasPhotoAccess = false
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

            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)

            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
            }

            configureConnections()

            session.commitConfiguration()
            isConfigured = true
        } catch {
            session.commitConfiguration()
            isConfigured = false
        }
    }

    private func configureConnections() {
        if let photoConnection = photoOutput.connection(with: .video),
           photoConnection.isVideoOrientationSupported {
            photoConnection.videoOrientation = .portrait
        }

        if let videoConnection = videoDataOutput.connection(with: .video) {
            if videoConnection.isVideoOrientationSupported {
                videoConnection.videoOrientation = .portrait
            }

            if videoConnection.isVideoMirroringSupported {
                videoConnection.isVideoMirrored = (currentPosition == .front)
            }
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
        guard let image = UIImage(data: data) else { return }

        let finalImage: UIImage
        if useRetroFilter {
            finalImage = RetroFilter.makeRetroPhoto(
                from: image,
                preset: selectedPreset,
                addDateStamp: addDateStamp
            )
        } else {
            finalImage = image
        }

        guard let finalData = finalImage.jpegData(compressionQuality: 0.88) else { return }

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            request.addResource(with: .photo, data: finalData, options: options)
        })
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastPreviewTimestamp > 0.10 else { return }
        lastPreviewTimestamp = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let image = RetroFilter.makePreviewImage(
            from: ciImage,
            preset: selectedPreset,
            useRetro: useRetroFilter,
            context: ciContext
        ) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.previewImage = image
        }
    }
}
