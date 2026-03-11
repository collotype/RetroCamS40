import UIKit
import CoreGraphics

extension UIImage {
    func normalized() -> UIImage {
        if imageOrientation == .up { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resized(to targetSize: CGSize, interpolation: CGInterpolationQuality = .high) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            context.cgContext.interpolationQuality = interpolation
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func centerCropped(to aspectRatio: CGFloat) -> UIImage {
        guard let cgImage else { return self }

        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)
        let sourceAspect = sourceWidth / max(sourceHeight, 1)

        let cropRect: CGRect
        if sourceAspect > aspectRatio {
            let newWidth = sourceHeight * aspectRatio
            cropRect = CGRect(
                x: (sourceWidth - newWidth) / 2.0,
                y: 0,
                width: newWidth,
                height: sourceHeight
            )
        } else {
            let newHeight = sourceWidth / aspectRatio
            cropRect = CGRect(
                x: 0,
                y: (sourceHeight - newHeight) / 2.0,
                width: sourceWidth,
                height: newHeight
            )
        }

        guard let cropped = cgImage.cropping(to: cropRect.integral) else { return self }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

    func jpegRecompressed(_ quality: CGFloat) -> UIImage {
        guard let data = jpegData(compressionQuality: quality),
              let image = UIImage(data: data) else {
            return self
        }
        return image
    }

    func withStamp(
        text: String,
        at point: CGPoint,
        color: UIColor = UIColor(red: 1.0, green: 0.80, blue: 0.24, alpha: 1.0),
        fontSize: CGFloat? = nil
    ) -> UIImage {
        let resolvedFontSize = fontSize ?? max(12, min(size.width, size.height) * 0.035)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))

            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.82)
            shadow.shadowOffset = CGSize(width: 1, height: 1)
            shadow.shadowBlurRadius = 0

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: resolvedFontSize, weight: .bold),
                .foregroundColor: color,
                .shadow: shadow
            ]

            let attributed = NSAttributedString(string: text, attributes: attributes)
            attributed.draw(at: point)
        }
    }

    func nearestNeighborScaled(to targetSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .none
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
