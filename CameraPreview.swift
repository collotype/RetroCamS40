import SwiftUI
import AVFoundation
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        view.previewLayer.connection?.videoOrientation = .portrait
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }

        uiView.previewLayer.videoGravity = .resizeAspectFill

        if let connection = uiView.previewLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        clipsToBounds = true
        backgroundColor = .black
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
