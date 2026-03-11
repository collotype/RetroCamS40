import Foundation
import AVFoundation

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
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(.failure(VideoExporterError.exportSessionUnavailable))
            return
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("retro_export_\(UUID().uuidString).mov")

        try? FileManager.default.removeItem(at: outputURL)

        let composition = AVVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                let source = request.sourceImage.clampedToExtent()
                let filtered = RetroFilter
                    .applyToVideoFrame(source, preset: preset)
                    .cropped(to: request.sourceImage.extent)

                request.finish(with: filtered, context: nil)
            }
        )

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
}
