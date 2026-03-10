import UIKit

extension UIImage {
    func normalized() -> UIImage {
        if imageOrientation == .up { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func centerCroppedTo4by3() -> UIImage {
        let image = normalized()
        guard let cgImage = image.cgImage else { return image }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let targetAspect: CGFloat = 4.0 / 3.0
        let currentAspect = width / height

        var cropRect = CGRect(x: 0, y: 0, width: width, height: height)

        if currentAspect > targetAspect {
            let newWidth = height * targetAspect
            cropRect.origin.x = (width - newWidth) / 2.0
            cropRect.size.width = newWidth
        } else if currentAspect < targetAspect {
            let newHeight = width / targetAspect
            cropRect.origin.y = (height - newHeight) / 2.0
            cropRect.size.height = newHeight
        }

        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    func resized(to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func withDateStamp() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let text = DateStampFormatter.shared.string(from: Date())

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))

            let padding: CGFloat = 10
            let font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .regular)

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(white: 1.0, alpha: 0.95),
                .shadow: {
                    let shadow = NSShadow()
                    shadow.shadowColor = UIColor.black.withAlphaComponent(0.8)
                    shadow.shadowBlurRadius = 2
                    shadow.shadowOffset = CGSize(width: 1, height: 1)
                    return shadow
                }()
            ]

            let string = NSAttributedString(string: text, attributes: attrs)
            let textSize = string.size()

            let rect = CGRect(
                x: max(padding, size.width - textSize.width - padding),
                y: max(padding, size.height - textSize.height - padding),
                width: textSize.width,
                height: textSize.height
            )

            string.draw(in: rect)
        }
    }
}

private final class DateStampFormatter {
    static let shared = DateStampFormatter()

    private let formatter: DateFormatter

    private init() {
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd/MM/yy HH:mm"
    }

    func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
