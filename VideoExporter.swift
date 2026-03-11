import Foundation
import AVFoundation
import CoreImage
import UIKit

enum VideoExporterError: Error {
    case exportSessionUnavailable
    case exportFailed
}

enum VideoExporter {
    static func exportRetroVideo(
        inputURL: URL,
        preset: RetroPreset,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let asset = AVAsset(url: inputURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: exportPresetName(for: preset)
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
                let filtered = applyVideoLook(
                    to: source,
                    preset: preset
                ).cropped(to: request.sourceImage.extent)

                request.finish(with: filtered, context: nil)
            }
        )

        composition.frameDuration = frameDuration(for: asset)
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

    private static func exportPresetName(for preset: RetroPreset) -> String {
        switch preset {
        case .oldPhone, .vhs:
            return AVAssetExportPreset640x480
        case .pointAndShoot, .nokia6230i:
            return AVAssetExportPreset960x540
        case .n73:
            return AVAssetExportPreset1280x720
        }
    }

    private static func frameDuration(for asset: AVAsset) -> CMTime {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return CMTime(value: 1, timescale: 30)
        }

        let fps = track.nominalFrameRate
        if fps > 0 {
            return CMTime(value: 1, timescale: CMTimeScale(max(24, min(Int32(fps.rounded()), 60))))
        } else {
            return CMTime(value: 1, timescale: 30)
        }
    }

    private static func applyVideoLook(to image: CIImage, preset: RetroPreset) -> CIImage {
        switch preset {
        case .oldPhone:
            return oldPhoneVideoLook(image)
        case .vhs:
            return vhsVideoLook(image)
        case .pointAndShoot:
            return pointAndShootVideoLook(image)
        case .nokia6230i:
            return nokia6230iVideoLook(image)
        case .n73:
            return n73VideoLook(image)
        }
    }

    private static func oldPhoneVideoLook(_ image: CIImage) -> CIImage {
        let downscaled = pixelateAndResize(
            image,
            scaleDown: 0.42,
            pixelScale: 2.3
        )

        var output = downscaled
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.72,
                kCIInputContrastKey: 1.20,
                kCIInputBrightnessKey: -0.03
            ])
            .applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 0.75,
                "inputShadowAmount": 0.18
            ])
            .applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: 0.20
            ])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.02, y: 0.00, z: 0.00, w: 0.0),
                "inputGVector": CIVector(x: 0.00, y: 1.00, z: 0.00, w: 0.0),
                "inputBVector": CIVector(x: 0.00, y: 0.02, z: 0.92, w: 0.0)
            ])

        output = addNoise(to: output, amount: 0.020, monochrome: false)
        output = addVignette(to: output, intensity: 0.20)
        return output
    }

    private static func vhsVideoLook(_ image: CIImage) -> CIImage {
        var output = image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.70,
                kCIInputContrastKey: 0.94,
                kCIInputBrightnessKey: 0.01
            ])
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: 1.0
            ])
            .cropped(to: image.extent)

        output = output.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.96, y: 0.01, z: 0.00, w: 0.0),
            "inputGVector": CIVector(x: 0.01, y: 0.97, z: 0.01, w: 0.0),
            "inputBVector": CIVector(x: 0.01, y: 0.02, z: 0.88, w: 0.0)
        ])

        output = addScanlines(to: output, spacing: 4, opacity: 0.14)
        output = addNoise(to: output, amount: 0.018, monochrome: true)
        output = addVignette(to: output, intensity: 0.15)
        output = horizontalSmear(output, offset: 1.4)
        return output
    }

    private static func pointAndShootVideoLook(_ image: CIImage) -> CIImage {
        var output = image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.96,
                kCIInputContrastKey: 1.03,
                kCIInputBrightnessKey: 0.01
            ])
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.3,
                kCIInputIntensityKey: 0.45
            ])

        output = addNoise(to: output, amount: 0.010, monochrome: false)
        output = addVignette(to: output, intensity: 0.07)
        return output
    }

    private static func nokia6230iVideoLook(_ image: CIImage) -> CIImage {
        var output = image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.03,
                kCIInputContrastKey: 1.14,
                kCIInputBrightnessKey: -0.01
            ])
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.7,
                kCIInputIntensityKey: 0.85
            ])

        output = addNoise(to: output, amount: 0.012, monochrome: false)
        output = addVignette(to: output, intensity: 0.10)
        return output
    }

    private static func n73VideoLook(_ image: CIImage) -> CIImage {
        var output = image
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.06,
                kCIInputContrastKey: 1.06,
                kCIInputBrightnessKey: 0.01
            ])
            .applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 0.82,
                "inputShadowAmount": 0.28
            ])
            .applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: 0.24
            ])

        output = addNoise(to: output, amount: 0.006, monochrome: false)
        output = addVignette(to: output, intensity: 0.05)
        return output
    }

    private static func pixelateAndResize(
        _ image: CIImage,
        scaleDown: CGFloat,
        pixelScale: CGFloat
    ) -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return image }

        let small = image.transformed(by: CGAffineTransform(scaleX: scaleDown, y: scaleDown))

        let pixelated = small.applyingFilter("CIPixellate", parameters: [
            kCIInputScaleKey: pixelScale
        ])

        let backScale = 1.0 / scaleDown
        return pixelated
            .transformed(by: CGAffineTransform(scaleX: backScale, y: backScale))
            .cropped(to: extent)
    }

    private static func addNoise(
        to image: CIImage,
        amount: CGFloat,
        monochrome: Bool
    ) -> CIImage {
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
                    kCIInputContrastKey: 1.10
                ])
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: amount)
                ])
        }

        return processedNoise.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: image
        ])
    }

    private static func addScanlines(
        to image: CIImage,
        spacing: Int,
        opacity: CGFloat
    ) -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return image }

        let lineHeight = max(1, spacing / 2)
        let stripeBase = CIImage(color: CIColor.black)
            .cropped(to: CGRect(x: 0, y: 0, width: extent.width, height: CGFloat(lineHeight)))

        var stripes: CIImage?
        var y: CGFloat = 0

        while y < extent.height {
            let line = stripeBase.transformed(by: CGAffineTransform(translationX: 0, y: y))
            if let existing = stripes {
                stripes = line.applyingFilter("CISourceOverCompositing", parameters: [
                    kCIInputBackgroundImageKey: existing
                ])
            } else {
                stripes = line
            }
            y += CGFloat(max(spacing, 2))
        }

        guard let stripes else { return image }

        let alphaStripes = stripes
            .cropped(to: extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)
            ])

        return alphaStripes.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: image
        ])
    }

    private static func addVignette(
        to image: CIImage,
        intensity: CGFloat
    ) -> CIImage {
        image.applyingFilter("CIVignette", parameters: [
            kCIInputIntensityKey: intensity,
            kCIInputRadiusKey: 1.2
        ])
    }

    private static func horizontalSmear(_ image: CIImage, offset: CGFloat) -> CIImage {
        let shiftedR = image
            .applyingFilter("CIAffineTransform", parameters: [
                kCIInputTransformKey: CGAffineTransform(translationX: offset, y: 0)
            ])
            .cropped(to: image.extent)

        let shiftedB = image
            .applyingFilter("CIAffineTransform", parameters: [
                kCIInputTransformKey: CGAffineTransform(translationX: -offset, y: 0)
            ])
            .cropped(to: image.extent)

        let red = shiftedR.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])

        let green = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])

        let blue = shiftedB.applyingFilter("CIColorMatrix", parameters: [
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
}
