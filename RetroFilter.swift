import Foundation
import CoreImage
import UIKit

// MARK: - Core app-facing enums kept stable for compatibility

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

    /// Дальше в новом UI лучше использовать именно это, а не `allCases`.
    static var mainSelectableCases: [RetroPreset] {
        [.oldPhone, .nokia6230i, .n73]
    }
}

// MARK: - IPA-style camera settings model

enum RetroImageQuality: String, CaseIterable, Identifiable {
    case economy
    case standard
    case fine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .economy:
            return "Economy"
        case .standard:
            return "Standard"
        case .fine:
            return "Fine"
        }
    }

    var jpegCompression: CGFloat {
        switch self {
        case .economy:
            return 0.34
        case .standard:
            return 0.48
        case .fine:
            return 0.66
        }
    }

    var recompressionPasses: Int {
        switch self {
        case .economy:
            return 2
        case .standard:
            return 2
        case .fine:
            return 1
        }
    }

    var previewCompression: CGFloat {
        switch self {
        case .economy:
            return 0.42
        case .standard:
            return 0.56
        case .fine:
            return 0.72
        }
    }
}

enum RetroImageSize: String, CaseIterable, Identifiable {
    case vga640x480
    case sxga1280x960
    case uxga1600x1200

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vga640x480:
            return "640×480"
        case .sxga1280x960:
            return "1280×960"
        case .uxga1600x1200:
            return "1600×1200"
        }
    }

    var size: CGSize {
        switch self {
        case .vga640x480:
            return CGSize(width: 640, height: 480)
        case .sxga1280x960:
            return CGSize(width: 1280, height: 960)
        case .uxga1600x1200:
            return CGSize(width: 1600, height: 1200)
        }
    }
}

enum RetroProcessorMode: String, CaseIterable, Identifiable {
    case realistic
    case balanced
    case enhanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .realistic:
            return "Realistic"
        case .balanced:
            return "Balanced"
        case .enhanced:
            return "Enhanced"
        }
    }
}

struct RetroCameraProfile: Identifiable {
    let preset: RetroPreset
    let imageQuality: RetroImageQuality
    let imageSize: RetroImageSize
    let processorMode: RetroProcessorMode
    let previewBaseSize: CGSize
    let sensorSampleSize: CGSize
    let displayUpscaleSize: CGSize
    let saturation: CGFloat
    let contrast: CGFloat
    let brightness: CGFloat
    let highlightRollOff: CGFloat
    let shadowLift: CGFloat
    let sharpen: CGFloat
    let softness: CGFloat
    let noiseOpacity: CGFloat
    let bandingOpacity: CGFloat
    let fringeOpacity: CGFloat
    let scanlineOpacity: CGFloat
    let vignette: CGFloat
    let dateStampColor: UIColor

    var id: String { preset.rawValue }
}

enum RetroFilter {
    private static let context = CIContext(options: nil)

    // MARK: - Public profile access

    static func profile(for preset: RetroPreset) -> RetroCameraProfile {
        switch preset {
        case .oldPhone:
            return RetroCameraProfile(
                preset: .oldPhone,
                imageQuality: .economy,
                imageSize: .vga640x480,
                processorMode: .realistic,
                previewBaseSize: CGSize(width: 320, height: 240),
                sensorSampleSize: CGSize(width: 240, height: 180),
                displayUpscaleSize: CGSize(width: 640, height: 480),
                saturation: 0.76,
                contrast: 1.20,
                brightness: -0.03,
                highlightRollOff: 0.77,
                shadowLift: 0.16,
                sharpen: 0.18,
                softness: 0.85,
                noiseOpacity: 0.075,
                bandingOpacity: 0.09,
                fringeOpacity: 0.06,
                scanlineOpacity: 0.05,
                vignette: 0.16,
                dateStampColor: UIColor(red: 1.0, green: 0.77, blue: 0.18, alpha: 1.0)
            )
        case .nokia6230i:
            return RetroCameraProfile(
                preset: .nokia6230i,
                imageQuality: .standard,
                imageSize: .sxga1280x960,
                processorMode: .balanced,
                previewBaseSize: CGSize(width: 360, height: 270),
                sensorSampleSize: CGSize(width: 420, height: 315),
                displayUpscaleSize: CGSize(width: 1280, height: 960),
                saturation: 0.92,
                contrast: 1.16,
                brightness: -0.015,
                highlightRollOff: 0.80,
                shadowLift: 0.22,
                sharpen: 0.40,
                softness: 0.40,
                noiseOpacity: 0.045,
                bandingOpacity: 0.045,
                fringeOpacity: 0.04,
                scanlineOpacity: 0.02,
                vignette: 0.10,
                dateStampColor: UIColor(red: 1.0, green: 0.78, blue: 0.24, alpha: 1.0)
            )
        case .n73:
            return RetroCameraProfile(
                preset: .n73,
                imageQuality: .fine,
                imageSize: .uxga1600x1200,
                processorMode: .enhanced,
                previewBaseSize: CGSize(width: 420, height: 315),
                sensorSampleSize: CGSize(width: 640, height: 480),
                displayUpscaleSize: CGSize(width: 1600, height: 1200),
                saturation: 1.02,
                contrast: 1.08,
                brightness: 0.01,
                highlightRollOff: 0.84,
                shadowLift: 0.28,
                sharpen: 0.48,
                softness: 0.22,
                noiseOpacity: 0.02,
                bandingOpacity: 0.015,
                fringeOpacity: 0.02,
                scanlineOpacity: 0.0,
                vignette: 0.05,
                dateStampColor: UIColor(red: 1.0, green: 0.80, blue: 0.28, alpha: 1.0)
            )
        case .pointAndShoot:
            // Оставлено только ради совместимости со старым кодом проекта.
            return RetroCameraProfile(
                preset: .pointAndShoot,
                imageQuality: .standard,
                imageSize: .sxga1280x960,
                processorMode: .balanced,
                previewBaseSize: CGSize(width: 360, height: 270),
                sensorSampleSize: CGSize(width: 520, height: 390),
                displayUpscaleSize: CGSize(width: 1280, height: 960),
                saturation: 0.96,
                contrast: 1.05,
                brightness: 0.01,
                highlightRollOff: 0.86,
                shadowLift: 0.26,
                sharpen: 0.34,
                softness: 0.28,
                noiseOpacity: 0.03,
                bandingOpacity: 0.01,
                fringeOpacity: 0.012,
                scanlineOpacity: 0.0,
                vignette: 0.07,
                dateStampColor: UIColor(red: 1.0, green: 0.72, blue: 0.20, alpha: 1.0)
            )
        case .vhs:
            // Оставлено только ради совместимости со старым кодом проекта.
            return RetroCameraProfile(
                preset: .vhs,
                imageQuality: .economy,
                imageSize: .vga640x480,
                processorMode: .realistic,
                previewBaseSize: CGSize(width: 320, height: 240),
                sensorSampleSize: CGSize(width: 280, height: 210),
                displayUpscaleSize: CGSize(width: 640, height: 480),
                saturation: 0.72,
                contrast: 0.96,
                brightness: 0.01,
                highlightRollOff: 0.82,
                shadowLift: 0.22,
                sharpen: 0.05,
                softness: 1.10,
                noiseOpacity: 0.08,
                bandingOpacity: 0.11,
                fringeOpacity: 0.04,
                scanlineOpacity: 0.16,
                vignette: 0.12,
                dateStampColor: UIColor(red: 1.0, green: 0.92, blue: 0.66, alpha: 1.0)
            )
        }
    }

    static func makeRetroPhoto(
        from image: UIImage,
        preset: RetroPreset,
        aspect: CaptureAspect,
        addDateStamp: Bool
    ) -> UIImage {
        let profile = profile(for: preset)
        let base = preparePhotoBase(image, profile: profile, aspect: aspect)
        let processed = processStillImage(base, profile: profile)

        if addDateStamp {
            return addOldDateStamp(to: processed, color: profile.dateStampColor)
        }
        return processed
    }

    static func normalizePhoto(
        from image: UIImage,
        aspect: CaptureAspect,
        addDateStamp: Bool
    ) -> UIImage {
        let base = prepareNormalizedPhoto(image, aspect: aspect)
        if addDateStamp {
            return addOldDateStamp(
                to: base,
                color: UIColor(red: 1.0, green: 0.77, blue: 0.18, alpha: 1.0)
            )
        }
        return base
    }

    static func makePreviewImage(
        from image: CIImage,
        preset: RetroPreset,
        useRetro: Bool,
        context: CIContext
    ) -> UIImage? {
        let profile = profile(for: preset)
        let prepared = previewBase(from: image, profile: profile)

        let ciOutput: CIImage
        if useRetro {
            ciOutput = applyCoreImageLook(to: prepared, profile: profile, forPreview: true)
        } else {
            ciOutput = prepared
        }

        guard let cg = context.createCGImage(ciOutput, from: ciOutput.extent) else {
            return nil
        }

        var preview = UIImage(cgImage: cg)
        if useRetro {
            preview = postPreviewPass(preview, profile: profile)
        }
        return preview
    }

    // MARK: - Photo pipeline

    private static func preparePhotoBase(
        _ image: UIImage,
        profile: RetroCameraProfile,
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

        let sensorSized = resize(cropped, to: profile.imageSize.size, quality: .medium)
        return sensorSized
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

    private static func processStillImage(_ image: UIImage, profile: RetroCameraProfile) -> UIImage {
        guard let input = CIImage(image: image) else { return image }

        let filtered = applyCoreImageLook(to: input, profile: profile, forPreview: false)
        guard let cg = context.createCGImage(filtered, from: filtered.extent) else {
            return image
        }

        var output = UIImage(cgImage: cg)
        output = emulateSensorPipeline(output, profile: profile)
        output = applyJPEGProfile(output, quality: profile.imageQuality)
        return output
    }

    // MARK: - Preview pipeline

    private static func previewBase(from image: CIImage, profile: RetroCameraProfile) -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return image }

        let targetWidth = max(profile.previewBaseSize.width, 1)
        let scale = targetWidth / max(extent.width, 1)
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private static func postPreviewPass(_ image: UIImage, profile: RetroCameraProfile) -> UIImage {
        var output = image

        let downsampled = resize(output, to: profile.sensorSampleSize, quality: .low)
        output = resizeWithNearestNeighbor(downsampled, to: profile.previewBaseSize)

        if profile.scanlineOpacity > 0.001 {
            output = overlayScanlines(on: output, opacity: profile.scanlineOpacity, lineSpacing: 4)
        }

        output = addBandNoise(on: output, opacity: profile.bandingOpacity * 0.7)
        output = addChromaticFringe(on: output, amount: profile.fringeOpacity * 0.85)
        output = overlayNoise(on: output, opacity: profile.noiseOpacity * 0.7, monochrome: false)
        output = applyJPEGPreviewPass(output, quality: profile.imageQuality)
        return output
    }

    // MARK: - CoreImage tone shaping

    private static func applyCoreImageLook(
        to image: CIImage,
        profile: RetroCameraProfile,
        forPreview: Bool
    ) -> CIImage {
        let saturation = forPreview ? profile.saturation + 0.04 : profile.saturation
        let contrast = forPreview ? profile.contrast - 0.03 : profile.contrast
        let brightness = forPreview ? profile.brightness + 0.01 : profile.brightness
        let sharpen = forPreview ? max(profile.sharpen - 0.06, 0) : profile.sharpen
        let softness = forPreview ? max(profile.softness - 0.15, 0) : profile.softness

        var output = image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: saturation,
                kCIInputContrastKey: contrast,
                kCIInputBrightnessKey: brightness
            ])
            .applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": profile.highlightRollOff,
                "inputShadowAmount": profile.shadowLift
            ])

        if sharpen > 0.001 {
            output = output.applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: sharpen
            ])
        }

        if softness > 0.001 {
            output = output
                .applyingFilter("CIGaussianBlur", parameters: [
                    kCIInputRadiusKey: softness
                ])
            output = cropToExtent(output, extent: image.extent)
        }

        output = applyColorSignature(to: output, preset: profile.preset)
        return output
    }

    private static func applyColorSignature(to image: CIImage, preset: RetroPreset) -> CIImage {
        switch preset {
        case .oldPhone:
            return image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.01, y: 0.00, z: 0.00, w: 0.0),
                "inputGVector": CIVector(x: 0.01, y: 0.98, z: 0.00, w: 0.0),
                "inputBVector": CIVector(x: 0.00, y: 0.03, z: 0.91, w: 0.0)
            ])
        case .nokia6230i:
            return image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.02, y: 0.01, z: 0.00, w: 0.0),
                "inputGVector": CIVector(x: 0.00, y: 1.00, z: 0.00, w: 0.0),
                "inputBVector": CIVector(x: 0.00, y: 0.01, z: 0.95, w: 0.0)
            ])
        case .n73:
            return image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.01, y: 0.00, z: 0.00, w: 0.0),
                "inputGVector": CIVector(x: 0.00, y: 1.01, z: 0.00, w: 0.0),
                "inputBVector": CIVector(x: 0.00, y: 0.01, z: 0.98, w: 0.0)
            ])
        case .pointAndShoot:
            return image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.00, y: 0.00, z: 0.00, w: 0.0),
                "inputGVector": CIVector(x: 0.00, y: 1.00, z: 0.00, w: 0.0),
                "inputBVector": CIVector(x: 0.00, y: 0.01, z: 0.97, w: 0.0)
            ])
        case .vhs:
            return image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.97, y: 0.01, z: 0.00, w: 0.0),
                "inputGVector": CIVector(x: 0.01, y: 0.97, z: 0.01, w: 0.0),
                "inputBVector": CIVector(x: 0.01, y: 0.03, z: 0.88, w: 0.0)
            ])
        }
    }

    // MARK: - Sensor / processor emulation

    private static func emulateSensorPipeline(_ image: UIImage, profile: RetroCameraProfile) -> UIImage {
        var output = image

        let sampled = resize(output, to: profile.sensorSampleSize, quality: .low)
        output = resizeWithNearestNeighbor(sampled, to: profile.displayUpscaleSize)

        output = softenEdges(on: output, amount: profile.softness * 0.65)
        output = addChromaticFringe(on: output, amount: profile.fringeOpacity)
        output = addBandNoise(on: output, opacity: profile.bandingOpacity)

        if profile.scanlineOpacity > 0.001 {
            output = overlayScanlines(on: output, opacity: profile.scanlineOpacity, lineSpacing: 3)
        }

        output = overlayNoise(on: output, opacity: profile.noiseOpacity, monochrome: false)

        if profile.vignette > 0.001 {
            output = addVignette(on: output, amount: profile.vignette)
        }

        return output
    }

    private static func applyJPEGProfile(_ image: UIImage, quality: RetroImageQuality) -> UIImage {
        var output = image
        for _ in 0..<quality.recompressionPasses {
            output = recompressJPEG(output, quality: quality.jpegCompression)
        }
        return output
    }

    private static func applyJPEGPreviewPass(_ image: UIImage, quality: RetroImageQuality) -> UIImage {
        recompressJPEG(image, quality: quality.previewCompression)
    }

    // MARK: - Date stamp

    private static func addOldDateStamp(to image: UIImage, color: UIColor) -> UIImage {
        let format = DateFormatter()
        format.dateFormat = "dd.MM.yyyy"
        let text = format.string(from: Date())

        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))

            let baseSize = max(12, min(image.size.width, image.size.height) * 0.036)
            let font = UIFont.monospacedDigitSystemFont(ofSize: baseSize, weight: .bold)

            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.86)
            shadow.shadowOffset = CGSize(width: 1, height: 1)
            shadow.shadowBlurRadius = 0

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .shadow: shadow
            ]

            let attributed = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributed.size()
            let inset = max(10, baseSize * 0.55)

            let rect = CGRect(
                x: inset,
                y: inset,
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
            let count = max(Int((size.width * size.height) / 210.0), 700)

            for _ in 0..<count {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let alpha = CGFloat.random(in: 0.01...max(opacity, 0.011))

                let color: UIColor
                if monochrome {
                    let value = CGFloat.random(in: 0.75...1.0)
                    color = UIColor(white: value, alpha: alpha)
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

    private static func addBandNoise(on image: UIImage, opacity: CGFloat) -> UIImage {
        guard opacity > 0.001 else { return image }

        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let bandCount = max(Int(size.height / 24), 8)

        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
            let cg = context.cgContext

            for index in 0..<bandCount {
                let bandHeight = CGFloat.random(in: 2...7)
                let y = (CGFloat(index) / CGFloat(max(bandCount, 1))) * size.height + CGFloat.random(in: -3...3)
                let alpha = CGFloat.random(in: 0.01...opacity)
                let white = CGFloat.random(in: 0.82...1.0)

                cg.setFillColor(UIColor(white: white, alpha: alpha).cgColor)
                cg.fill(CGRect(x: 0, y: y, width: size.width, height: bandHeight))
            }
        }
    }

    private static func addChromaticFringe(on image: UIImage, amount: CGFloat) -> UIImage {
        guard amount > 0.001 else { return image }

        let size = image.size
        let offset = max(1, Int(ceil(max(size.width, size.height) * amount * 0.006)))
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))

            UIColor.systemPink.withAlphaComponent(amount * 0.45).setFill()
            UIRectFillUsingBlendMode(
                CGRect(x: 0, y: 0, width: size.width, height: size.height),
                .color
            )

            image.draw(
                in: CGRect(x: CGFloat(offset), y: 0, width: size.width, height: size.height),
                blendMode: .screen,
                alpha: amount * 0.30
            )
            image.draw(
                in: CGRect(x: -CGFloat(offset), y: 0, width: size.width, height: size.height),
                blendMode: .plusLighter,
                alpha: amount * 0.18
            )
        }
    }

    private static func softenEdges(on image: UIImage, amount: CGFloat) -> UIImage {
        guard amount > 0.001, let input = CIImage(image: image) else { return image }

        let blurred = input
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: amount])
            .cropped(to: input.extent)

        guard let cg = context.createCGImage(blurred, from: blurred.extent) else { return image }
        return UIImage(cgImage: cg)
    }

    private static func addVignette(on image: UIImage, amount: CGFloat) -> UIImage {
        guard let input = CIImage(image: image) else { return image }

        let radius = min(input.extent.width, input.extent.height) * 0.90
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
