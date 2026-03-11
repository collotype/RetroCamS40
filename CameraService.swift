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

    @Published var selectedPreviewFPS: Int = 30
    @Published var captureAspect: CaptureAspect = .full
    @Published var photoFlashMode: PhotoFlashMode = .off
    @Published var zoomFactor: CGFloat = 1.0
    @Published var manualFocusEnabled: Bool = false
    @Published var focusPosition: Float = 0.5
    @Published var manualExposureEnabled: Bool = false
    @Published var manualISOValue: Float = 0.2
    @Published var manualShutterValue: Float = 0.15

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
            guard !self.movieOutput.isRecording else { return }

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
                self.applyCurrentDeviceSettings()
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

            let settings = AVCapturePhotoSettings()

            if let device = self.activeVideoDevice, device.hasFlash {
                settings.flashMode = self.avFlashMode
            }

            if let connection = self.photoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func toggleRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isConfigured else { return }

            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            } else {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("retrocam_\(UUID().uuidString).mov")

                if let connection = self.movieOutput.connection(with: .video),
                   connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }

                self.movieOutput.startRecording(to: url, recordingDelegate: self)
            }
        }
    }

    // MARK: - Settings updates

    func updatePreviewFPS(_ fps: Int) {
        let safe = [24, 30, 60].contains(fps) ? fps : 30
        DispatchQueue.main.async {
            self.selectedPreviewFPS = safe
        }
        sessionQueue.async { [weak self] in
            self?.applyFrameRate()
        }
    }

    func updateCaptureAspect(_ aspect: CaptureAspect) {
        DispatchQueue.main.async {
            self.captureAspect = aspect
        }
    }

    func updateFlashMode(_ mode: PhotoFlashMode) {
        DispatchQueue.main.async {
            self.photoFlashMode = mode
        }
    }

    func updateZoom(_ zoom: CGFloat) {
        DispatchQueue.main.async {
            self.zoomFactor = zoom
        }
        sessionQueue.async { [weak self] in
            self?.applyZoom()
        }
    }

    func updateManualFocusEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.manualFocusEnabled = enabled
        }
        sessionQueue.async { [weak self] in
            self?.applyFocus()
        }
    }

    func updateFocusPosition(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        DispatchQueue.main.async {
            self.focusPosition = clamped
        }
        sessionQueue.async { [weak self] in
            self?.applyFocus()
        }
    }

    func updateManualExposureEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.manualExposureEnabled = enabled
        }
        sessionQueue.async { [weak self] in
            self?.applyExposure()
        }
    }

    func updateManualISOValue(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        DispatchQueue.main.async {
            self.manualISOValue = clamped
        }
        sessionQueue.async { [weak self] in
            self?.applyExposure()
        }
    }

    func updateManualShutterValue(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        DispatchQueue.main.async {
            self.manualShutterValue = clamped
        }
        sessionQueue.async { [weak self] in
            self?.applyExposure()
        }
    }

    // MARK: - Session setup

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                self.configureSession()
            }

            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }

            self.applyCurrentDeviceSettings()
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

    private func requestMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            hasMicrophoneAccess = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                guard let self else { return }
                self.hasMicrophoneAccess = granted
            }
        default:
            hasMicrophoneAccess = false
        }
    }

    private func configureSession() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        do {
            let camera = try makeCamera(position: currentPosition)
            let input = try AVCaptureDeviceInput(device: camera)

            if session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
            }

            if hasMicrophoneAccess, let mic = AVCaptureDevice.default(for: .audio) {
                let micInput = try AVCaptureDeviceInput(device: mic)
                if session.canAddInput(micInput) {
                    session.addInput(micInput)
                    audioInput = micInput
                }
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }

            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true

            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
                videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
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

        if let movieConnection = movieOutput.connection(with: .video),
           movieConnection.isVideoOrientationSupported {
            movieConnection.videoOrientation = .portrait
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

    // MARK: - Device controls

    private var activeVideoDevice: AVCaptureDevice? {
        videoInput?.device
    }

    private var avFlashMode: AVCaptureDevice.FlashMode {
        switch photoFlashMode {
        case .off: return .off
        case .auto: return .auto
        case .on: return .on
        }
    }

    private func applyCurrentDeviceSettings() {
        applyFrameRate()
        applyZoom()
        applyFocus()
        applyExposure()
    }

    private func applyFrameRate() {
        guard let device = activeVideoDevice else { return }

        let fps = Double(selectedPreviewFPS)
        let supported = device.activeFormat.videoSupportedFrameRateRanges.contains {
            fps >= $0.minFrameRate && fps <= $0.maxFrameRate
        }

        guard supported else { return }

        do {
            try device.lockForConfiguration()
            let duration = CMTime(value: 1, timescale: CMTimeScale(selectedPreviewFPS))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {
        }
    }

    private func applyZoom() {
        guard let device = activeVideoDevice else { return }

        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 6.0)
        let value = min(max(zoomFactor, 1.0), maxZoom)

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = value
            device.unlockForConfiguration()
        } catch {
        }
    }

    private func applyFocus() {
        guard let device = activeVideoDevice else { return }

        do {
            try device.lockForConfiguration()

            if manualFocusEnabled,
               device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: focusPosition, completionHandler: nil)
            } else if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            device.unlockForConfiguration()
        } catch {
        }
    }

    private func applyExposure() {
        guard let device = activeVideoDevice else { return }

        do {
            try device.lockForConfiguration()

            if manualExposureEnabled, device.isExposureModeSupported(.custom) {
                let minISO = device.activeFormat.minISO
                let maxISO = device.activeFormat.maxISO
                let iso = minISO + (maxISO - minISO) * manualISOValue

                let minDurationSeconds = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
                let maxDurationSeconds = min(
                    CMTimeGetSeconds(device.activeFormat.maxExposureDuration),
                    1.0 / 2.0
                )

                let seconds = minDurationSeconds + (maxDurationSeconds - minDurationSeconds) * Double(manualShutterValue)
                let duration = CMTimeMakeWithSeconds(seconds, preferredTimescale: 1_000_000_000)

                device.setExposureModeCustom(duration: duration, iso: iso, completionHandler: nil)
            } else if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
        } catch {
        }
    }

    private func saveVideoToLibrary(_ url: URL, cleanupURLs: [URL]) {
        guard hasPhotoAccess else { return }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { _, _ in
            for fileURL in cleanupURLs {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if error != nil { return }
        guard let data = photo.fileDataRepresentation() else { return }
        guard hasPhotoAccess else { return }
        guard let image = UIImage(data: data)?.normalized() else { return }

        let finalImage: UIImage
        if useRetroFilter {
            finalImage = RetroFilter.makeRetroPhoto(
                from: image,
                preset: selectedPreset,
                aspect: captureAspect,
                addDateStamp: addDateStamp
            )
        } else {
            finalImage = RetroFilter.normalizePhoto(
                from: image,
                aspect: captureAspect,
                addDateStamp: addDateStamp
            )
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
        let minInterval = 1.0 / Double(max(selectedPreviewFPS, 12))

        guard now - lastPreviewTimestamp >= minInterval else { return }
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

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
        }

        guard error == nil else {
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }

        let preset = selectedPreset

        VideoExporter.exportRetroVideo(inputURL: outputFileURL, preset: preset) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let exportedURL):
                self.saveVideoToLibrary(exportedURL, cleanupURLs: [outputFileURL, exportedURL])
            case .failure:
                self.saveVideoToLibrary(outputFileURL, cleanupURLs: [outputFileURL])
            }
        }
    }
}
