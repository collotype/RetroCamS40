import Foundation
import CoreImage
import UIKit

enum RetroPreset: String, CaseIterable, Identifiable {
    case pointAndShoot
    case vhs
    case oldPhone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pointAndShoot:
            return "Мыльница"
        case .vhs:
            return "VHS-камера"
        case .oldPhone:
            return "Старый телефон 0.3MP"
        }
    }

    var shortTitle: String {
        switch self {
        case .pointAndShoot:
            return "Мыльница"
        case .vhs:
            return "VHS"
        case .oldPhone:
            return "Nokia"
        }
    }
}

enum RetroFilter {
    private static let context = CIContext(options: nil)

    static func makeRetroPhoto(from image: UIImage,
                               preset: RetroPreset,
                               addDateStamp: Bool) -> UIImage {
        let prepared = prepareBase(image, preset: preset)

        guard let input = CIImage(image: prepared) else { return prepared }
        let output = applyRetro(to: input, preset: preset)

        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return prepared
        }

        var result = UIImage(cgImage: cgImage, scale: 1, orientation: .up)

        if addDateStamp {
            result = result.withDateStamp()
        }

        return result
    }

    static func makePreviewImage(from image: CIImage,
                                 preset: RetroPreset,
                                 useRetro: Bool,
                                 context: CIContext) -> UIImage? {
        let output: CIImage

        if useRetro {
            output = applyRetro(to: image, preset: preset)
        } else {
            output = image
        }

        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private static func prepareBase(_ image: UIImage, preset: RetroPreset) -> UIImage {
        let base = image.normalized().centerCroppedTo4by3()

        switch preset {
        case .pointAndShoot:
            return base.resized(to: CGSize(width: 1280, height: 960))
        case .vhs:
            return base.resized(to: CGSize(width: 720, height: 480))
        case .oldPhone:
            return base.resized(to: CGSize(width: 640, height: 480))
        }
    }

    private static func applyRetro(to image: CIImage, preset: RetroPreset) -> CIImage {
        switch preset {
        case .pointAndShoot:
            return applyPointAndShoot(to: image)
        case .vhs:
            return applyVHS(to: image)
        case .oldPhone:
            return applyOldPhone(to: image)
        }
    }

    private static func applyPointAndShoot(to image: CIImage) -> CIImage {
        let extent = image.extent
        var output = image

        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.95,
            kCIInputContrastKey: 1.08,
            kCIInputBrightnessKey: -0.01
        ])

        output = output.applyingFilter("CITemperatureAndTint", parameters: [
            "inputNeutral": CIVector(x: 6500, y: 0),
            "inputTargetNeutral": CIVector(x: 5600, y: 0)
        ])

        output = output.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 0.18
        ])

        output = output.applyingFilter("CIVignette", parameters: [
            kCIInputIntensityKey: 0.45,
            kCIInputRadiusKey: 1.2
        ])

        if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?.cropped(to: extent) {
            let grain = noise.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.025)
            ])
            output = grain.applyingFilter("CISoftLightBlendMode", parameters: [
                kCIInputBackgroundImageKey: output
            ]).cropped(to: extent)
        }

        return output
    }

    private static func applyVHS(to image: CIImage) -> CIImage {
        let extent = image.extent
        var output = image

        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.55,
            kCIInputContrastKey: 1.02,
            kCIInputBrightnessKey: -0.04
        ])

        output = output.applyingFilter("CIHueAdjust", parameters: [
            kCIInputAngleKey: 0.04
        ])

        output = output.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: 0.9
        ]).cropped(to: extent)

        output = output.applyingFilter("CIBloom", parameters: [
            kCIInputRadiusKey: 2.0,
            kCIInputIntensityKey: 0.3
        ]).cropped(to: extent)

        if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?.cropped(to: extent) {
            let grain = noise.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.05)
            ])
            output = grain.applyingFilter("CIOverlayBlendMode", parameters: [
                kCIInputBackgroundImageKey: output
            ]).cropped(to: extent)
        }

        return output
    }

    private static func applyOldPhone(to image: CIImage) -> CIImage {
        let extent = image.extent
        var output = image

        let downscaled = output.applyingFilter("CILanczosScaleTransform", parameters: [
            "inputScale": 0.18,
            "inputAspectRatio": 1.0
        ])

        output = downscaled.applyingFilter("CILanczosScaleTransform", parameters: [
            "inputScale": 5.55,
            "inputAspectRatio": 1.0
        ]).cropped(to: extent)

        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.35,
            kCIInputContrastKey: 1.28,
            kCIInputBrightnessKey: -0.05
        ])

        output = output.applyingFilter("CIColorPosterize", parameters: [
            "inputLevels": 10.0
        ])

        output = output.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 0.45
        ])

        output = output.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: 0.25
        ]).cropped(to: extent)

        if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?.cropped(to: extent) {
            let grain = noise.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.08)
            ])
            output = grain.applyingFilter("CIHardLightBlendMode", parameters: [
                kCIInputBackgroundImageKey: output
            ]).cropped(to: extent)
        }

        return output
    }
}
