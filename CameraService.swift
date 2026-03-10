import Foundation
import AVFoundation

final class CameraService: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var useRetroFilter: Bool = true
    @Published var addDateStamp: Bool = true

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "retrocam.session.queue")
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var currentPosition: AVCaptureDevice.Position = .back

    override init() {
        super.init()
        requestCameraAccess()
    }

    func startIfNeeded() {
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
        // Пока специально пусто.
        // Следующим шагом добавим реальный снимок.
    }

    func toggleRecording() {
        // Пока специально пусто.
        // Видео добавим позже.
    }

    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { _ in
            // Ничего не делаем здесь специально.
            // Камера стартует в startIfNeeded().
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
