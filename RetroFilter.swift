import Foundation
import CoreImage
import UIKit

enum CaptureAspect: String, CaseIterable, Identifiable {
    case full
    case fourThree

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full:
            return "Обычный"
        case .fourThree:
            return "4:3"
        }
    }
}

enum PhotoFlashMode: String, CaseIterable, Identifiable {
    case off
    case auto
    case on

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "Выкл"
        case .auto:
            return "Авто"
        case .on:
            return "Вкл"
        }
    }
}

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

    static func makeRetroPhoto(
        from image: UIImage,
        preset: RetroPreset,
        aspect: CaptureAspect,
        addDateStamp: Bool
    ) -> UIImage {
        let base = preparePhotoBase(image, preset: preset, aspect: aspect)
        let processed = processStillImage(base, preset: preset)

        if addDateStamp {
            return addOldDateStamp(to: processed, preset: preset)
        } else {
            return processed
        }
    }

    static func normalizePhoto(
        from image: UIImage,
        aspect: CaptureAspect,
        addDateStamp: Bool
    ) -> UIImage {
        let base = prepareNormalizedPhoto(image, aspect: aspect)
        if addDateStamp {
            return addOldDateStamp(to: base, preset: .oldPhone)
        } else {
            return base
        }
    }

    static func makePreviewImage(
        from image: CIImage,
        preset: RetroPreset,
        useRetro: Bool,
        context: CIContext
    ) -> UIImage? {
        let prepared = previewBase(from: image)

        let output: CIImage
        if useRetro {
            output = applyCoreImageLook(to: prepared, preset: preset, forPreview: true)
        } else {
            output = prepared
        }

        guard let cg = context.createCGImage(output, from: output.extent) else {
            return nil
        }

        var ui = UIImage(cgImage: cg)

        if useRetro {
            ui = postPreviewPass(ui, preset: preset)
        }

        return ui
    }

    // MARK: - Photo pipeline

    private static func preparePhotoBase(
        _ image: UIImage,
        preset: RetroPreset,
        aspect: CaptureAspect
    ) -> UIImage {
        let normalized = normalizedImage(image)

        let cropped: UIImage
        switch aspect {
        case .full:
            cropped = centerCrop(normalized, targetAspect: normalized.size.width / max(normalized.size.height, 1))
        case .fourThree:
            cropped = centerCrop(normalized, targetAspect: 4.0 / 3.0)
        }

        let targetSize = targetPhotoSize(for: preset)
        return resize(cropped, to: targetSize, quality: .medium)
    }

    private static func prepareNormalizedPhoto(
        _ image: UIImage,
        aspect: CaptureAspect
    ) -> UIImage {
        let normalized = normalizedImage(image)

        let cropped: UIImage
        switch aspect {
        case .full:
            cropped = normalized
        case .fourThree:
            cropped = centerCrop(normalized, targetAspect: 4.0 / 3.0)
        }

        return resize(cropped, to: CGSize(width: 640, height: 480), quality: .high)
    }

    private static func targetPhotoSize(for preset: RetroPreset) -> CGSize {
        switch preset {
        case .oldPhone:
            return CGSize(width: 640, height: 480)
        case .pointAndShoot:
            return CGSize(width: 960, height: 720)
        case .vhs:
            return CGSize(width: 640, height: 480)
        case .nokia6230i:
            return CGSize(width: 1280, height: 960)
        case .n73:
            return CGSize(width: 1600, height: 1200)
        }
    }

    private static func processStillImage(_ image: UIImage, preset: RetroPreset) -> UIImage {
        guard let input = CIImage(image: image) else { return image }

        let ci = applyCoreImageLook(to: input, preset: preset, forPreview: false)
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return image }

        var ui = UIImage(cgImage: cg)

        switch preset {
        case .oldPhone:
            ui = emulateOldPhone(ui)
        case .vhs:
            ui = emulateVHS(ui)
        case .pointAndShoot:
            ui = emulatePointAndShoot(ui)
        case .nokia6230i:
            ui = emulate6230i(ui)
        case .n73:
            ui = emulateN73(ui)
        }

        return ui
    }

    // MARK: - Preview pipeline

    private static func previewBase(from image: CIImage) -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return image }

        let targetWidth: CGFloat = 360
        let scale = targetWidth / extent.width
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private static func postPreviewPass(_ image: UIImage, preset: RetroPreset) -> UIImage {
        switch preset {
        case .oldPhone:
            return resizeWithNearestNeighbor(
                resize(image, to: CGSize(width: 240, height: 180), quality: .low),
                to: CGSize(width: 360, height: 270)
            )
        case .vhs:
            return overlayScanlines(on: image, opacity: 0.16, lineSpacing: 4)
        case .pointAndShoot:
            return recompressJPEG(image, quality: 0.72)
        case .nokia6230i:
            return recompressJPEG(image, quality: 0.78)
        case .n73:
            return recompressJPEG(image, quality: 0.86)
        }
    }

    // MARK: - CI look

    private static func applyCoreImageLook(
        to image: CIImage,
        preset: RetroPreset,
        forPreview: Bool
    ) -> CIImage {
        switch preset {
        case .oldPhone:
            return oldPhoneLook(image, forPreview: forPreview)
        case .vhs:
            return vhsLook(image, forPreview: forPreview)
        case .pointAndShoot:
            return pointAndShootLook(image, forPreview: forPreview)
        case .nokia6230i:
            return nokia6230iLook(image, forPreview: forPreview)
        case .n73:
            return n73Look(image, forPreview: forPreview)
        }
    }

    private static func oldPhoneLook(_ image: CIImage, forPreview: Bool) -> CIImage {
        let saturation: CGFloat = forPreview ? 0.80 : 0.72
        let contrast: CGFloat = forPreview ? 1.12 : 1.18
        let brightness: CGFloat = forPreview ? -0.01 : -0.03

        var output = image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: saturation,
                kCIInputContrastKey: contrast,
                kCIInputBrightnessKey: brightness
            ])
            .applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 0.75,
                "inputShadowAmount": 0.18
            ])
            .applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: 0.22
            ])

        output = output.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1.02, y: 0.00, z: 0.00, w: 0.0),
            "inputGVector": CIVector(x: 0.00, y: 1.00, z: 0.00, w: 0.0),
            "inputBVector": CIVector(x: 0.00, y: 0.02, z: 0.93, w: 0.0)
        ])

        return output
    }

    private static func vhsLook(_ image: CIImage, forPreview: Bool) -> CIImage {
        let blurRadius: CGFloat = forPreview ? 0.7 : 1.2
        let saturation: CGFloat = forPreview ? 0.78 : 0.70

        var output = image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: saturation,
                kCIInputContrastKey: 0.95,
                kCIInputBrightnessKey: 0.01
            ])
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: blurRadius
            ])

        output = cropToExtent(output, extent: image.extent)

        output = output.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.96, y: 0.01, z: 0.00, w: 0.0),
            "inputGVector": CIVector(x: 0.01, y: 0.97, z: 0.01, w: 0.0),
            "inputBVector": CIVector(x: 0.01, y: 0.02, z: 0.90, w: 0.0)
        ])

        return output
    }

    private static func pointAndShootLook(_ image: CIImage, forPreview: Bool) -> CIImage {
        image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: forPreview ? 1.00 : 0.95,
                kCIInputContrastKey: 1.03,
                kCIInputBrightnessKey: 0.01
            ])
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: forPreview ? 1.0 : 1.4,
                kCIInputIntensityKey: forPreview ? 0.35 : 0.50
            ])
    }

    private static func nokia6230iLook(_ image: CIImage, forPreview: Bool) -> CIImage {
        image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: forPreview ? 1.02 : 1.06,
                kCIInputContrastKey: forPreview ? 1.10 : 1.15,
                kCIInputBrightnessKey: -0.01
            ])
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: forPreview ? 1.2 : 1.8,
                kCIInputIntensityKey: forPreview ? 0.55 : 0.85
            ])
    }

    private static func n73Look(_ image: CIImage, forPreview: Bool) -> CIImage {
        image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: forPreview ? 1.02 : 1.08,
                kCIInputContrastKey: forPreview ? 1.03 : 1.06,
                kCIInputBrightnessKey: 0.01
            ])
            .applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 0.82,
                "inputShadowAmount": 0.30
            ])
            .applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: forPreview ? 0.18 : 0.26
            ])
    }

    // MARK: - Preset post-processing

    private static func emulateOldPhone(_ image: UIImage) -> UIImage {
        let down = resize(image, to: CGSize(width: 320, height: 240), quality: .low)
        var up = resizeWithNearestNeighbor(down, to: CGSize(width: 640, height: 480))
        up = recompressJPEG(up, quality: 0.38)
        up = overlayNoise(on: up, opacity: 0.06, monochrome: false)
        up = addVignette(on: up, amount: 0.18)
        return up
    }

    private static func emulateVHS(_ image: UIImage) -> UIImage {
        var out = resize(image, to: CGSize(width: 640, height: 480), quality: .low)
        out = recompressJPEG(out, quality: 0.42)
        out = overlayScanlines(on: out, opacity: 0.18, lineSpacing: 4)
        out = overlayNoise(on: out, opacity: 0.07, monochrome: true)
        out = addVignette(on: out, amount: 0.14)
        return out
    }

    private static func emulatePointAndShoot(_ image: UIImage) -> UIImage {
        var out = recompressJPEG(image, quality: 0.72)
        out = overlayNoise(on: out, opacity: 0.025, monochrome: false)
        out = addVignette(on: out, amount: 0.08)
        return out
    }

    private static func emulate6230i(_ image: UIImage) -> UIImage {
        var out = recompressJPEG(image, quality: 0.60)
        out = overlayNoise(on: out, opacity: 0.035, monochrome: false)
        out = addVignette(on: out, amount: 0.10)
        return out
    }

    private static func emulateN73(_ image: UIImage) -> UIImage {
        var out = recompressJPEG(image, quality: 0.82)
        out = overlayNoise(on: out, opacity: 0.015, monochrome: false)
        out = addVignette(on: out, amount: 0.05)
        return out
    }

    // MARK: - Date stamp

    private static func addOldDateStamp(to image: UIImage, preset: RetroPreset) -> UIImage {
        let format = DateFormatter()
        format.dateFormat = "dd.MM.yyyy HH:mm"
        let text = format.string(from: Date())

        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))

            let baseSize = max(12, min(image.size.width, image.size.height) * 0.035)
            let font = UIFont.monospacedDigitSystemFont(
                ofSize: baseSize,
                weight: .bold
            )

            let foreground: UIColor
            switch preset {
            case .oldPhone:
                foreground = UIColor(red: 1.00, green: 0.74, blue: 0.18, alpha: 1.0)
            case .vhs:
                foreground = UIColor(red: 1.00, green: 0.92, blue: 0.65, alpha: 1.0)
            case .pointAndShoot:
                foreground = UIColor(red: 1.00, green: 0.70, blue: 0.20, alpha: 1.0)
            case .nokia6230i:
                foreground = UIColor(red: 1.00, green: 0.76, blue: 0.22, alpha: 1.0)
            case .n73:
                foreground = UIColor(red: 1.00, green: 0.78, blue: 0.28, alpha: 1.0)
            }

            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.8)
            shadow.shadowOffset = CGSize(width: 1, height: 1)
            shadow.shadowBlurRadius = 0

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: foreground,
                .shadow: shadow
            ]

            let attributed = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributed.size()

            let inset = max(10, baseSize * 0.55)
            let rect = CGRect(
                x: image.size.width - textSize.width - inset,
                y: image.size.height - textSize.height - inset,
                width: textSize.width,
                height: textSize.height
            )

            attributed.draw(in: rect)
        }
    }

    // MARK: - Image helpers

    private static func normalizedImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func centerCrop(_ image: UIImage, targetAspect: CGFloat) -> UIImage {
        guard let cg = image.cgImage else { return image }

        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        let sourceAspect = width / max(height, 1)

        var cropRect: CGRect

        if sourceAspect > targetAspect {
            let newWidth = height * targetAspect
            cropRect = CGRect(
                x: (width - newWidth) / 2.0,
                y: 0,
                width: newWidth,
                height: height
            )
        } else {
            let newHeight = width / targetAspect
            cropRect = CGRect(
                x: 0,
                y: (height - newHeight) / 2.0,
                width: width,
                height: newHeight
            )
        }

        cropRect = cropRect.integral

        guard let cropped = cg.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    private enum ResizeQuality {
        case low
        case medium
        case high

        var interpolation: CGInterpolationQuality {
            switch self {
            case .low: return .low
            case .medium: return .medium
            case .high: return .high
            }
        }
    }

    private static func resize(_ image: UIImage, to size: CGSize, quality: ResizeQuality) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            context.cgContext.interpolationQuality = quality.interpolation
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func resizeWithNearestNeighbor(_ image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            context.cgContext.interpolationQuality = .none
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func recompressJPEG(_ image: UIImage, quality: CGFloat) -> UIImage {
        guard let data = image.jpegData(compressionQuality: quality),
              let out = UIImage(data: data) else {
            return image
        }
        return out
    }

    private static func overlayNoise(
        on image: UIImage,
        opacity: CGFloat,
        monochrome: Bool
    ) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))

            let cg = context.cgContext
            let count = Int((size.width * size.height) / 180.0)

            for _ in 0..<count {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let alpha = CGFloat.random(in: 0.02...opacity)

                let color: UIColor
                if monochrome {
                    let v = CGFloat.random(in: 0.75...1.0)
                    color = UIColor(white: v, alpha: alpha)
                } else {
                    color = UIColor(
                        red: CGFloat.random(in: 0.75...1.0),
                        green: CGFloat.random(in: 0.75...1.0),
                        blue: CGFloat.random(in: 0.75...1.0),
                        alpha: alpha
                    )
                }

                cg.setFillColor(color.cgColor)
                cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
    }

    private static func overlayScanlines(
        on image: UIImage,
        opacity: CGFloat,
        lineSpacing: Int
    ) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))

            let cg = context.cgContext
            cg.setStrokeColor(UIColor.black.withAlphaComponent(opacity).cgColor)
            cg.setLineWidth(1)

            stride(from: 0, to: Int(size.height), by: max(lineSpacing, 2)).forEach { y in
                cg.move(to: CGPoint(x: 0, y: CGFloat(y)))
                cg.addLine(to: CGPoint(x: size.width, y: CGFloat(y)))
                cg.strokePath()
            }
        }
    }

    private static func addVignette(on image: UIImage, amount: CGFloat) -> UIImage {
        guard let input = CIImage(image: image) else { return image }

        let radius = min(input.extent.width, input.extent.height) * 0.9
        let center = CIVector(x: input.extent.midX, y: input.extent.midY)

        let output = input.applyingFilter("CIVignetteEffect", parameters: [
            kCIInputCenterKey: center,
            kCIInputRadiusKey: radius,
            kCIInputIntensityKey: amount
        ])

        guard let cg = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cg)
    }

    private static func cropToExtent(_ image: CIImage, extent: CGRect) -> CIImage {
        image.cropped(to: extent)
    }
}
