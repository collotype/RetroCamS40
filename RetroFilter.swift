import Foundation
import CoreImage
import UIKit

enum RetroPreset: String, CaseIterable, Identifiable {
    case pointAndShoot
    case vhs
    case oldPhone
    case nokia6230i
    case n73

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pointAndShoot:
            return "Мыльница"
        case .vhs:
            return "VHS-камера"
        case .oldPhone:
            return "Nokia VGA 0.3MP"
        case .nokia6230i:
            return "Nokia 6230i 1.3MP"
        case .n73:
            return "Nokia N73 3.2MP"
        }
    }

    var shortTitle: String {
        switch self {
        case .pointAndShoot:
            return "Мыльница"
        case .vhs:
            return "VHS"
        case .oldPhone:
            return "0.3MP"
        case .nokia6230i:
            return "6230i"
        case .n73:
            return "N73"
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
        let output = useRetro ? applyRetro(to: image, preset: preset) : image

        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private static func prepareBase(_ image: UIImage, preset: RetroPreset) -> UIImage {
        let base = image.normalized().centerCroppedTo4by3()

        switch preset {
        case .pointAndShoot:
            // Типичная поздняя мыльница: визуально ещё норм, но дёшево
            return base.resized(to: CGSize(width: 1600, height: 1200))
        case .vhs:
            // Домашняя видеокамера / кассетный вайб
            return base.resized(to: CGSize(width: 720, height: 576))
        case .oldPhone:
            // VGA 0.3 MP
            return base.resized(to: CGSize(width: 640, height: 480))
        case .nokia6230i:
            // 1.3 MP вайб
            return base.resized(to: CGSize(width: 1280, height: 960))
        case .n73:
            // 3.2 MP камерофон получше
            return base.resized(to: CGSize(width: 2048, height: 1536))
        }
    }

    private static func applyRetro(to image: CIImage, preset: RetroPreset) -> CIImage {
        switch preset {
        case .pointAndShoot:
            return applyPointAndShoot(to: image)
        case .vhs:
            return applyVHS(to: image)
        case .oldPhone:
            return applyOldPhoneVGA(to: image)
        case .nokia6230i:
            return apply6230i(to: image)
        case .n73:
            return applyN73(to: image)
        }
    }

    // MARK: - Мыльница
    // Дешёвый бытовой цифровик: чуть тёплый, слегка контрастный,
    // немного перешарпленный, без сильной деградации.

    private static func applyPointAndShoot(to image: CIImage) -> CIImage {
        let extent = image.extent
        var output = image

        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 1.00,
            kCIInputContrastKey: 1.10,
            kCIInputBrightnessKey: 0.01
        ])

        output = output.applyingFilter("CITemperatureAndTint", parameters: [
            "inputNeutral": CIVector(x: 6500, y: 0),
            "inputTargetNeutral": CIVector(x: 5600, y: 0)
        ])

        output = output.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 0.28
        ])

        output = output.applyingFilter("CIVignette", parameters: [
            kCIInputIntensityKey: 0.28,
            kCIInputRadiusKey: 1.1
        ])

        if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?.cropped(to: extent) {
            let grain = noise.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.018)
            ])
            output = grain.applyingFilter("CISoftLightBlendMode", parameters: [
                kCIInputBackgroundImageKey: output
            ]).cropped(to: extent)
        }

        return output
    }

    // MARK: - VHS / Digital8 / Handycam
    // Мягко, грязновато, менее насыщенно, немного "плывёт".

    private static func applyVHS(to image: CIImage) -> CIImage {
        let extent = image.extent
        var output = image

        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.58,
            kCIInputContrastKey: 0.98,
            kCIInputBrightnessKey: -0.03
        ])

        output = output.applyingFilter("CIHueAdjust", parameters: [
            kCIInputAngleKey: 0.035
        ])

        output = output.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: 1.15
        ]).cropped(to: extent)

        output = output.applyingFilter("CIBloom", parameters: [
            kCIInputRadiusKey: 2.4,
            kCIInputIntensityKey: 0.28
        ]).cropped(to: extent)

        if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?.cropped(to: extent) {
            let grain = noise.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.045)
            ])
            output = grain.applyingFilter("CIOverlayBlendMode", parameters: [
                kCIInputBackgroundImageKey: output
            ]).cropped(to: extent)
        }

        return output
    }

    // MARK: - Nokia VGA / 0.3 MP
    // Главный пресет кнопочных телефонов: сильно убитая детализация,
    // грубый JPEG, бедные цвета, полосы/шум/цветение.

    private static func applyOldPhoneVGA(to image: CIImage) -> CIImage {
        let extent = image.extent
        var output = image

        // Сильная потеря деталей
        let downscaled = output.applyingFilter("CILanczosScaleTransform", parameters: [
            "inputScale": 0.16,
            "inputAspectRatio": 1.0
        ])

        output = downscaled.applyingFilter("CILanczosScaleTransform", parameters: [
            "inputScale": 6.25,
            "inputAspectRatio": 1.0
        ]).cropped(to: extent)

        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.40,
            kCIInputContrastKey: 1.22,
            kCIInputBrightnessKey: -0.04
        ])

        output = output.applyingFilter("CIColorPosterize", parameters: [
            "inputLevels": 9.0
        ])

        output = output.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 0.32
        ])

        output = output.applyingFilter("CIBloom", parameters: [
            kCIInputRadiusKey: 1.3,
            kCIInputIntensityKey: 0.18
        ]).cropped(to: extent)

        if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?.cropped(to: extent) {
            let grain = noise.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.075)
            ])
            output = grain.applyingFilter("CIHardLightBlendMode", parameters: [
                kCIInputBackgroundImageKey: output
            ]).cropped(to: extent)
        }

        return output
    }

    // MARK: - Nokia 6230i / 1.3 MP
    // Уже лучше VGA, но всё ещё телефонный и грубоватый.

    private static func apply6230i(to image: CIImage) -> CIImage {
        let extent = image.extent
        var output = image

        let downscaled = output.applyingFilter("CILanczosScaleTransform", parameters: [
            "inputScale": 0.36,
            "inputAspectRatio": 1.0
        ])

        output = downscaled.applyingFilter("CILanczosScaleTransform", parameters: [
            "inputScale": 2.78,
            "inputAspectRatio": 1.0
        ]).cropped(to: extent)

        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.65,
            kCIInputContrastKey: 1.14,
            kCIInputBrightnessKey: -0.02
        ])

        output = output.applyingFilter("CIColorPosterize", parameters: [
            "inputLevels": 14.0
        ])

        output = output.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 0.25
        ])

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

    // MARK: - Nokia N73 / 3.2 MP
    // Уже "камерофон получше": больше деталей, но всё равно старый мобильный вайб.

    private static func applyN73(to image: CIImage) -> CIImage {
        let extent = image.extent
        var output = image

        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.82,
            kCIInputContrastKey: 1.10,
            kCIInputBrightnessKey: -0.01
        ])

        output = output.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 0.22
        ])

        output = output.applyingFilter("CIVignette", parameters: [
            kCIInputIntensityKey: 0.18,
            kCIInputRadiusKey: 1.0
        ])

        if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?.cropped(to: extent) {
            let grain = noise.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.03)
            ])
            output = grain.applyingFilter("CISoftLightBlendMode", parameters: [
                kCIInputBackgroundImageKey: output
            ]).cropped(to: extent)
        }

        return output
    }
}
