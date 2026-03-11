import SwiftUI
import Photos
import AVKit

struct LegacyGalleryScreen: View {
    @Binding var selectedAssetID: String?
    @Binding var presentViewer: Bool

    @StateObject private var model = LegacyGalleryViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LegacySectionTitle(title: "Галерея")

            LegacyCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(headerTitle)
                            .font(.system(size: 15, weight: .bold))

                        Text(headerSubtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.black.opacity(0.68))
                    }

                    Spacer()

                    Button {
                        model.reloadAssets()
                    } label: {
                        Text("Обновить")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(LegacyPalette.softStrong)
                            .foregroundStyle(LegacyPalette.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            content
        }
        .onAppear {
            model.requestAccessIfNeeded()
        }
        .onChange(of: model.assets) { assets in
            guard !assets.isEmpty else {
                selectedAssetID = nil
                return
            }

            if let selectedAssetID,
               assets.contains(where: { $0.localIdentifier == selectedAssetID }) {
                return
            }

            self.selectedAssetID = assets.first?.localIdentifier
        }
        .sheet(isPresented: $presentViewer) {
            if let asset = model.asset(for: selectedAssetID) {
                LegacyAssetViewer(asset: asset)
            }
        }
    }

    private var headerTitle: String {
        switch model.accessState {
        case .idle, .loading:
            return "Загрузка галереи"
        case .denied:
            return "Нет доступа к медиатеке"
        case .authorized, .limited:
            return "Медиафайлов: \(model.assets.count)"
        }
    }

    private var headerSubtitle: String {
        switch model.accessState {
        case .idle, .loading:
            return "Проверяем разрешение и загружаем последние фото и видео"
        case .denied:
            return "Добавь разрешение на чтение Photo Library в настройках iOS"
        case .limited:
            return selectedAssetID == nil
                ? "Ограниченный доступ, файл не выбран"
                : "Ограниченный доступ, выбран 1 файл"
        case .authorized:
            return selectedAssetID == nil
                ? "Ничего не выбрано"
                : "Файл выбран, можно открыть просмотр"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.accessState {
        case .idle, .loading:
            VStack(spacing: 16) {
                Spacer()

                ProgressView()
                    .tint(.black)

                Text("Читаем медиатеку...")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))

                Spacer()
            }

        case .denied:
            LegacyCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Доступ к галерее выключен.")
                        .font(.system(size: 16, weight: .bold))

                    Text("Добавь в Info.plist ключ NSPhotoLibraryUsageDescription и выдай приложению доступ к Photo Library.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.75))

                    Button {
                        model.requestAccessIfNeeded(forcePrompt: true)
                    } label: {
                        Text("Повторить запрос")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.black)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

        case .authorized, .limited:
            if model.assets.isEmpty {
                LegacyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Пока пусто")
                            .font(.system(size: 16, weight: .bold))

                        Text("Сделай фото или видео, затем вернись сюда.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.black.opacity(0.75))
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(model.assets, id: \.localIdentifier) { asset in
                            LegacyGalleryTile(
                                model: model,
                                asset: asset,
                                isSelected: selectedAssetID == asset.localIdentifier
                            ) {
                                selectedAssetID = asset.localIdentifier
                            } openAction: {
                                selectedAssetID = asset.localIdentifier
                                presentViewer = true
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }
}

@MainActor
final class LegacyGalleryViewModel: ObservableObject {
    enum AccessState {
        case idle
        case loading
        case denied
        case limited
        case authorized
    }

    @Published var accessState: AccessState = .idle
    @Published var assets: [PHAsset] = []

    private let imageManager = PHCachingImageManager()

    func requestAccessIfNeeded(forcePrompt: Bool = false) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized:
            accessState = .authorized
            reloadAssets()

        case .limited:
            accessState = .limited
            reloadAssets()

        case .notDetermined:
            requestAuthorization()

        case .denied, .restricted:
            accessState = .denied
            if forcePrompt {
                requestAuthorization()
            }

        @unknown default:
            accessState = .denied
        }
    }

    func reloadAssets() {
        accessState = currentResolvedAccessState()
        assets = fetchAssets()
    }

    func asset(for localIdentifier: String?) -> PHAsset? {
        guard let localIdentifier else { return nil }
        return assets.first(where: { $0.localIdentifier == localIdentifier })
    }

    func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    func requestFullImage(
        for asset: PHAsset,
        completion: @escaping (UIImage?) -> Void
    ) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    func requestPlayer(
        for asset: PHAsset,
        completion: @escaping (AVPlayer?) -> Void
    ) {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true

        imageManager.requestPlayerItem(forVideo: asset, options: options) { item, _ in
            let player = item.map { AVPlayer(playerItem: $0) }
            DispatchQueue.main.async {
                completion(player)
            }
        }
    }

    private func requestAuthorization() {
        accessState = .loading

        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            Task { @MainActor in
                guard let self else { return }

                switch status {
                case .authorized:
                    self.accessState = .authorized
                    self.reloadAssets()

                case .limited:
                    self.accessState = .limited
                    self.reloadAssets()

                case .denied, .restricted:
                    self.accessState = .denied
                    self.assets = []

                case .notDetermined:
                    self.accessState = .idle
                    self.assets = []

                @unknown default:
                    self.accessState = .denied
                    self.assets = []
                }
            }
        }
    }

    private func currentResolvedAccessState() -> AccessState {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .idle
        @unknown default:
            return .denied
        }
    }

    private func fetchAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        let result = PHAsset.fetchAssets(with: options)
        var items: [PHAsset] = []
        items.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            guard asset.mediaType == .image || asset.mediaType == .video else { return }
            items.append(asset)
        }

        return items
    }
}

struct LegacyGalleryTile: View {
    @ObservedObject var model: LegacyGalleryViewModel

    let asset: PHAsset
    let isSelected: Bool
    let selectAction: () -> Void
    let openAction: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button {
            selectAction()
        } label: {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(LegacyPalette.softStrong)

                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    } else {
                        ProgressView()
                            .tint(.black)
                    }

                    HStack(spacing: 4) {
                        if asset.mediaType == .video {
                            Image(systemName: "video.fill")
                                .font(.system(size: 10, weight: .bold))
                        } else {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 10, weight: .bold))
                        }

                        Text(assetLabel)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.72))
                    .foregroundStyle(LegacyPalette.previewBadge)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(6)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(6)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.black : Color.black.opacity(0.15), lineWidth: isSelected ? 3 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                openAction()
            }
        )
        .onAppear {
            loadThumbnail()
        }
    }

    private var assetLabel: String {
        if asset.mediaType == .video {
            let total = Int(round(asset.duration))
            let minutes = total / 60
            let seconds = total % 60
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return "\(asset.pixelWidth)x\(asset.pixelHeight)"
        }
    }

    private func loadThumbnail() {
        let size = CGSize(width: 300, height: 300)
        model.requestThumbnail(for: asset, targetSize: size) { image in
            self.thumbnail = image
        }
    }
}

struct LegacyAssetViewer: View {
    let asset: PHAsset

    @Environment(\.dismiss) private var dismiss

    @StateObject private var model = LegacyGalleryViewModel()
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Назад")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text(asset.mediaType == .video ? "ВИДЕО" : "ФОТО")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(detailText)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color.black)

                ZStack {
                    Color.black

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else if asset.mediaType == .video, let player {
                        VideoPlayer(player: player)
                            .onAppear {
                                player.play()
                            }
                            .onDisappear {
                                player.pause()
                            }
                    } else if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    } else {
                        Text("Не удалось открыть файл")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                HStack {
                    Text(bottomInfoText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Color.black)
            }
        }
        .onAppear {
            load()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private var detailText: String {
        if asset.mediaType == .video {
            let total = Int(round(asset.duration))
            let minutes = total / 60
            let seconds = total % 60
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return "\(asset.pixelWidth)x\(asset.pixelHeight)"
        }
    }

    private var bottomInfoText: String {
        if let date = asset.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy HH:mm"
            return formatter.string(from: date)
        }
        return "Без даты"
    }

    private func load() {
        isLoading = true

        if asset.mediaType == .video {
            model.requestPlayer(for: asset) { player in
                self.player = player
                self.isLoading = false
            }
        } else {
            model.requestFullImage(for: asset) { image in
                self.image = image
                self.isLoading = false
            }
        }
    }
}
