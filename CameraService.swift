import Foundation
import AVFoundation

final class CameraService: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var useRetroFilter: Bool = true
    @Published var addDateStamp: Bool = true

    let session = AVCaptureSession()

    func startIfNeeded() {}
    func stop() {}
    func switchCamera() {}
    func takePhoto() {}
    func toggleRecording() {}
}
