import Foundation
import CoreImage
import UIKit

enum RetroFilter {
    private static let context = CIContext(options: nil)

    static func makeRetroPhoto(from image: UIImage, addDateStamp: Bool) -> UIImage {
        guard let input = CIImage(image: image) else { return image }

        let output = applyRetro(to: input)

        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        var result = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)

        // Пока вызов оставляем, но сам штамп даты у тебя ещё заглушка.
        if addDateStamp {
            result = result.withDateStamp()
        }

        return result
    }

    static func applyToVideoFrame(_ image: CIImage) -> CIImage {
        applyRetro(to: image)
    }

    private static func applyRetro(to image: CIImage) -> CIImage {
        let extent = image.extent
        var output = image

        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.65,
            kCIInputContrastKey: 1.15,
            kCIInputBrightnessKey: -0.03
        ])

        output = output.applyingFilter("CISepiaTone", parameters: [
            kCIInputIntensityKey: 0.25
        ])

        output = output.applyingFilter("CIColorPosterize", parameters: [
            "inputLevels": 18.0
        ])

        output = output.applyingFilter("CIPixellate", parameters: [
            kCIInputScaleKey: 2.0,
            kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY)
        ]).cropped(to: extent)

        return output
    }
}
