import Foundation
import AVFoundation
import CoreImage
import CoreMedia
import UIKit

enum VideoExporterError: Error {
    case exportSessionUnavailable
    case noVideoTrack
    case exportFailed
}

enum VideoExporter {
    private static let ciContext = CIContext(options: nil)

    static func exportRetroVideo(
        inputURL: URL,
        preset: RetroPreset,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let asset = AVAsset(url: inputURL)

        guard asset.tracks(withMediaType: .video).first != nil else {
            completion(.failure(VideoExporterError.noVideoTrack))
            return
        }

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(.failure(VideoExporterError.exportSessionUnavailable))
            return
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("retro_export_\(UUID().uuidString).mov")

        try? FileManager.default.removeItem(at: outputURL)

        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                let source = request.sourceImage.clampedToExtent()
                let filtered = applyVideoLook(to: source, preset: preset)
                    .cropped(to: request.sourceImage.extent)
                request.finish(with: filtered, context: ciContext)
            }
        )

        composition.frameDuration = frameDuration(for: asset, preset: preset)
        composition.renderSize = renderSize(for: asset, preset: preset)

        exportSession.videoComposition = composition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = false

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(outputURL))
            case .failed:
                completion(.failure(exportSession.error ?? VideoExporterError.exportFailed))
            case .cancelled:
                completion(.failure(exportSession.error ?? VideoExporterError.exportFailed))
            default:
                completion(.failure(exportSession.error ?? VideoExporterError.exportFailed))
            }
        }
    }

    // MARK: - Export geometry

    private static func renderSize(for asset: AVAsset, preset: RetroPreset) -> CGSize {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return CGSize(width: 640, height: 480)
        }

        let targetLandscape = targetLandscapeRenderSize(for: preset)
        let oriented = orientedNaturalSize(for: track)
        let isPortrait = oriented.height > oriented.width

        if isPortrait {
            return CGSize(width: targetLandscape.height, height: targetLandscape.width)
        } else {
            return targetLandscape
        }
    }

    private static func targetLandscapeRenderSize(for preset: RetroPreset) -> CGSize {
        switch preset {
        case .oldPhone, .vhs:
            return CGSize(width: 640, height: 480)
        case .pointAndShoot, .nokia6230i:
            return CGSize(width: 640, height: 480)
        case .n73:
            return CGSize(width: 720, height: 540)
        }
    }

    private static func orientedNaturalSize(for track: AVAssetTrack) -> CGSize {
        let transformed = CGRect(origin: .zero, size: track.naturalSize)
            .applying(track.preferredTransform)
            .standardized
            .integral

        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }

    private static func frameDuration(for asset: AVAsset, preset: RetroPreset) -> CMTime {
        let targetFPS = targetFPS(for: preset)

        guard let track = asset.tracks(withMediaType: .video).first else {
            return CMTime(value: 1, timescale: targetFPS)
        }

        let sourceFPS = track.nominalFrameRate
        if sourceFPS > 0 {
            let source = Int32(max(1, min(Int(sourceFPS.rounded()), 60)))
            let finalFPS = min(source, targetFPS)
            return CMTime(value: 1, timescale: finalFPS)
        }

        return CMTime(value: 1, timescale: targetFPS)
    }

    private static func targetFPS(for preset: RetroPreset) -> CMTimeScale {
        switch preset {
        case .oldPhone:
            return 15
        case .vhs:
            return 25
        case .pointAndShoot:
            return 24
        case .nokia6230i:
            return 20
        case .n73:
            return 24
        }
    }

    // MARK: - Filter pipeline

    private static func applyVideoLook(to image: CIImage, preset: RetroPreset) -> CIImage {
        let profile = RetroFilter.profile(for: preset)

        var output = applySensorScale(to: image, profile: profile)
        output = applyTone(to: output, profile: profile)
        output = applyColorSignature(to: output, preset: preset)
        output = applyProcessorAccent(to: output, profile: profile)

        if profile.bandingOpacity > 0.001 {
            output = addBandNoise(to: output, amount: profile.bandingOpacity)
        }

        if profile.scanlineOpacity > 0.001 {
            output = addScanlines(to: output, opacity: profile.scanlineOpacity)
        }

        if profile.fringeOpacity > 0.001 {
            output = addChromaticOffset(to: output, amount: profile.fringeOpacity)
        }

        if profile.noiseOpacity > 0.001 {
            output = addNoise(to: output, amount: profile.noiseOpacity, monochrome: false)
        }

        if profile.vignette > 0.001 {
            output = addVignette(to: output, intensity: profile.vignette)
        }

        output = applyCompressionPass(to: output, quality: profile.imageQuality)
        return output
    }

    private static func applySensorScale(to image: CIImage, profile: RetroCameraProfile) -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return image }

        let targetWidth = max(profile.sensorSampleSize.width, 1)
        let scaleDown = min(max(targetWidth / max(extent.width, 1), 0.18), 1.0)
        let pixelScale = pixelScale(for: profile)

        let reduced = image.transformed(by: CGAffineTransform(scaleX: scaleDown, y: scaleDown))
        let pixelated = reduced.applyingFilter("CIPixellate", parameters: [
            kCIInputScaleKey: pixelScale
        ])

        let backScale = 1.0 / scaleDown
        return pixelated
            .transformed(by: CGAffineTransform(scaleX: backScale, y: backScale))
            .cropped(to: extent)
    }

    private static func pixelScale(for profile: RetroCameraProfile) -> CGFloat {
        switch profile.processorMode {
        case .realistic:
            return 2.5
        case .balanced:
            return 1.8
        case .enhanced:
            return 1.25
        }
    }

    private static func applyTone(to image: CIImage, profile: RetroCameraProfile) -> CIImage {
        var output = image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: profile.saturation,
                kCIInputContrastKey: profile.contrast,
                kCIInputBrightnessKey: profile.brightness
            ])
            .applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": profile.highlightRollOff,
                "inputShadowAmount": profile.shadowLift
            ])

        let softnessRadius = max(profile.softness * 0.9, 0)
        if softnessRadius > 0.001 {
            output = output
                .applyingFilter("CIGaussianBlur", parameters: [
                    kCIInputRadiusKey: softnessRadius
                ])
                .cropped(to: image.extent)
        }

        let sharpness = max(profile.sharpen * 0.85, 0)
        if sharpness > 0.001 {
            output = output.applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: sharpness
            ])
        }

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

    private static func applyProcessorAccent(to image: CIImage, profile: RetroCameraProfile) -> CIImage {
        switch profile.processorMode {
        case .realistic:
            return image
                .applyingFilter("CIUnsharpMask", parameters: [
                    kCIInputRadiusKey: 0.6,
                    kCIInputIntensityKey: 0.22
                ])
                .cropped(to: image.extent)
        case .balanced:
            return image
                .applyingFilter("CIUnsharpMask", parameters: [
                    kCIInputRadiusKey: 0.8,
                    kCIInputIntensityKey: 0.34
                ])
                .cropped(to: image.extent)
        case .enhanced:
            return image
                .applyingFilter("CIUnsharpMask", parameters: [
                    kCIInputRadiusKey: 1.0,
                    kCIInputIntensityKey: 0.46
                ])
                .cropped(to: image.extent)
        }
    }

    private static func applyCompressionPass(to image: CIImage, quality: RetroImageQuality) -> CIImage {
        switch quality {
        case .economy:
            return image
                .applyingFilter("CIUnsharpMask", parameters: [
                    kCIInputRadiusKey: 0.4,
                    kCIInputIntensityKey: 0.10
                ])
                .cropped(to: image.extent)
        case .standard:
            return image
        case .fine:
            return image
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 1.01,
                    kCIInputContrastKey: 1.01,
                    kCIInputBrightnessKey: 0.0
                ])
        }
    }

    // MARK: - CI overlays

    private static func addNoise(to image: CIImage, amount: CGFloat, monochrome: Bool) -> CIImage {
        let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!
            .cropped(to: image.extent)

        let processedNoise: CIImage
        if monochrome {
            processedNoise = noise
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 1.15
                ])
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: amount)
                ])
        } else {
            processedNoise = noise
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.35,
                    kCIInputContrastKey: 1.08
                ])
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: amount)
                ])
        }

        return processedNoise.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: image
        ])
    }

    private static func addScanlines(to image: CIImage, opacity: CGFloat) -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return image }

        let stripes = CIFilter(name: "CIStripesGenerator", parameters: [
            "inputColor0": CIColor(red: 0, green: 0, blue: 0, alpha: opacity),
            "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0.0),
            "inputWidth": 2.0,
            "inputSharpness": 1.0,
            "inputCenter": CIVector(x: extent.midX, y: extent.midY)
        ])!.outputImage!
            .cropped(to: extent)
            .transformed(by: CGAffineTransform(rotationAngle: .pi / 2))
            .cropped(to: extent)

        return stripes.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: image
        ])
    }

    private static func addBandNoise(to image: CIImage, amount: CGFloat) -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return image }

        let bright = CIFilter(name: "CIStripesGenerator", parameters: [
            "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: amount * 0.55),
            "inputColor1": CIColor(red: 1, green: 1, blue: 1, alpha: 0.0),
            "inputWidth": 14.0,
            "inputSharpness": 0.20,
            "inputCenter": CIVector(x: extent.midX, y: extent.midY)
        ])!.outputImage!
            .cropped(to: extent)
            .transformed(by: CGAffineTransform(rotationAngle: .pi / 2))
            .cropped(to: extent)

        let dark = CIFilter(name: "CIStripesGenerator", parameters: [
            "inputColor0": CIColor(red: 0, green: 0, blue: 0, alpha: amount * 0.25),
            "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0.0),
            "inputWidth": 21.0,
            "inputSharpness": 0.14,
            "inputCenter": CIVector(x: extent.midX + 9, y: extent.midY)
        ])!.outputImage!
            .cropped(to: extent)
            .transformed(by: CGAffineTransform(rotationAngle: .pi / 2))
            .cropped(to: extent)

        let combined = bright.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: dark
        ])

        return combined.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: image
        ])
    }

    private static func addChromaticOffset(to image: CIImage, amount: CGFloat) -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return image }

        let shift = max(extent.width, extent.height) * amount * 0.006

        let red = image
            .transformed(by: CGAffineTransform(translationX: shift, y: 0))
            .cropped(to: extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
            ])

        let green = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])

        let blue = image
            .transformed(by: CGAffineTransform(translationX: -shift, y: 0))
            .cropped(to: extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0)
            ])

        let rg = red.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: green
        ])

        return blue.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: rg
        ])
    }

    private static func addVignette(to image: CIImage, intensity: CGFloat) -> CIImage {
        image.applyingFilter("CIVignette", parameters: [
            kCIInputIntensityKey: intensity,
            kCIInputRadiusKey: 1.2
        ])
    }
}
