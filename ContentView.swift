import SwiftUI
import Photos
import AVKit
import WebKit
import UIKit

struct ContentView: View {
    @StateObject private var camera = CameraService()
    @StateObject private var library = MediaLibraryStore()

    @AppStorage("retrocam.theme") private var storedThemeName: String = AppTheme.classic.rawValue
    @AppStorage("retrocam.language") private var storedLanguageCode: String = AppLanguage.ru.rawValue
    @AppStorage("retrocam.smiley.manual") private var storedManualSmileyName: String = ""

    @State private var route: AppRoute = .camera
    @State private var selectedMedia: MediaItem?
    @State private var now = Date()

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: storedThemeName) ?? .classic
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: storedLanguageCode) ?? .ru
    }

    private var hubEntries: [SettingsHubEntry] {
        [
            .mode,
            .camera,
            .themes,
            .smiley,
            .language,
            .importSection
        ]
    }

    private var effectiveSmiley: SmileyAsset? {
        let manualName = storedManualSmileyName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !manualName.isEmpty,
           let manual = SmileyAsset.find(named: manualName) {
            return manual
        }

        if let themed = SmileyAsset.find(named: selectedTheme.rawValue + "S") {
            return themed
        }

        let fallbackNames = ["clownS", "cupsizeS", "donutsepia", "cupsizeNS"]
        for name in fallbackNames {
            if let item = SmileyAsset.find(named: name) {
                return item
            }
        }

        return nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ThemeBackgroundView(theme: selectedTheme)
                    .ignoresSafeArea()

                switch route {
                case .camera:
                    cameraScreen(in: geo.size)

                case .gallery:
                    GalleryScreen(
                        theme: selectedTheme,
                        library: library,
                        onBack: { route = .camera },
                        onSelect: { item in
                            selectedMedia = item
                            route = .viewer
                        }
                    )

                case .viewer:
                    if let selectedMedia {
                        MediaViewerScreen(
                            theme: selectedTheme,
                            item: selectedMedia,
                            library: library,
                            onBack: { route = .gallery }
                        )
                    } else {
                        GalleryScreen(
                            theme: selectedTheme,
                            library: library,
                            onBack: { route = .camera },
                            onSelect: { item in
                                selectedMedia = item
                                route = .viewer
                            }
                        )
                    }

                case .settingsHub:
                    settingsHubScreen(in: geo.size)

                case .settingsDetail(let detail):
                    settingsDetailScreen(detail, in: geo.size)
                }
            }
        }
        .onAppear {
            camera.startIfNeeded()
            library.requestAndLoad()
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
        .onDisappear {
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
        .onReceive(clockTimer) { value in
            now = value
        }
    }
}

// MARK: - Main camera screen

private extension ContentView {
    func cameraScreen(in size: CGSize) -> some View {
        VStack(spacing: 10) {
            Spacer(minLength: 8)

            TopStatusBar(
                theme: selectedTheme,
                date: now,
                recordingDuration: camera.recordingDuration,
                isRecording: camera.isRecording,
                smiley: effectiveSmiley
            )
            .padding(.horizontal, 14)

            ZStack {
                DeviceShell(theme: selectedTheme) {
                    VStack(spacing: 0) {
                        cameraViewport(in: size)
                            .padding(.horizontal, 10)
                            .padding(.top, 10)

                        selectorStrip
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        BottomSoftKeyBar(
                            theme: selectedTheme,
                            leftAction: {
                                library.requestAndLoad()
                                route = .gallery
                            },
                            centerAction: {
                                camera.performPrimaryAction()
                            },
                            rightAction: {
                                route = .settingsHub
                            },
                            centerResourceName: centerButtonResourceName,
                            leftLabel: "GALLERY",
                            rightLabel: "SET"
                        )
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                    }
                }
            }
            .padding(.horizontal, 14)

            Spacer(minLength: 8)
        }
    }

    var selectorStrip: some View {
        HStack(spacing: 8) {
            CompactSelectorCapsule(
                title: "MODE",
                value: camera.captureMode == .photo ? "PHOTO" : "VIDEO",
                theme: selectedTheme,
                isActive: true,
                action: {
                    camera.toggleCaptureMode()
                }
            )

            CompactSelectorCapsule(
                title: "CAM",
                value: camera.selectedPreset.shortTitle.uppercased(),
                theme: selectedTheme,
                isActive: false,
                action: {
                    cyclePreset()
                }
            )

            CompactSelectorCapsule(
                title: "SIZE",
                value: shortImageSizeTitle(camera.selectedImageSize),
                theme: selectedTheme,
                isActive: false,
                action: {
                    cycleImageSize()
                }
            )
        }
    }

    func cameraViewport(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.72))

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selectedTheme.borderColor.opacity(0.95), lineWidth: 2)

            ZStack {
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let preview = camera.previewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if camera.captureMode == .video && camera.isRecording {
                    VStack {
                        HStack {
                            recordingPill
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(12)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if camera.addDateStamp {
                            DateOverlayStamp()
                                .padding(8)
                        }
                    }
                }
            }
            .padding(8)
        }
        .frame(height: min(size.height * 0.56, 460))
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
    }

    var recordingPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)

            Text("REC")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.white)

            Text(formatDuration(camera.recordingDuration))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.72))
        .clipShape(Capsule())
    }

    var centerButtonResourceName: String {
        switch camera.captureMode {
        case .photo:
            return "play"
        case .video:
            return camera.isRecording ? "play3" : "play2"
        }
    }

    func cyclePreset() {
        let available = RetroPreset.mainSelectableCases
        guard let currentIndex = available.firstIndex(of: camera.selectedPreset) else {
            camera.updatePreset(available.first ?? .oldPhone)
            return
        }
        let next = available[(currentIndex + 1) % available.count]
        camera.updatePreset(next)
    }

    func cycleImageSize() {
        let values = RetroImageSize.allCases
        guard let index = values.firstIndex(of: camera.selectedImageSize) else {
            camera.updateImageSize(.vga640x480)
            return
        }
        let next = values[(index + 1) % values.count]
        camera.updateImageSize(next)
    }

    func shortImageSizeTitle(_ size: RetroImageSize) -> String {
        switch size {
        case .vga640x480:
            return "VGA"
        case .sxga1280x960:
            return "SXGA"
        case .uxga1600x1200:
            return "UXGA"
        }
    }
}

// MARK: - Settings hub / detail

private extension ContentView {
    func settingsHubScreen(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            SettingsHeader(
                theme: selectedTheme,
                title: "SETTINGS",
                subtitle: "OLD DEVICE CONTROL",
                onBack: { route = .camera }
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if ResourceImageLoader.image(named: "mainphoto") != nil {
                        ResourceImageView(name: "mainphoto")
                            .scaledToFit()
                            .frame(width: 74, height: 74)
                            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                            .padding(.top, 6)
                    }

                    ForEach(makeHubRows(from: hubEntries).indices, id: \.self) { rowIndex in
                        let row = makeHubRows(from: hubEntries)[rowIndex]

                        HStack(spacing: 18) {
                            if row.count == 1 {
                                Spacer(minLength: 0)
                                bubble(for: row[0], large: true)
                                Spacer(minLength: 0)
                            } else {
                                ForEach(row, id: \.self) { entry in
                                    bubble(for: entry, large: false)
                                }
                            }
                        }
                    }

                    LargeBackButton(theme: selectedTheme, title: "BACK") {
                        route = .camera
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            }
        }
    }

    @ViewBuilder
    func settingsDetailScreen(_ detail: SettingsDetail, in size: CGSize) -> some View {
        switch detail {
        case .mode:
            diagonalBubbleScreen(
                title: "MODE",
                subtitle: "PHOTO / VIDEO",
                bubbles: [
                    DiagonalBubbleItem(
                        title: "PHOTO",
                        subtitle: camera.captureMode == .photo ? "ACTIVE" : "SWITCH",
                        action: { camera.updateCaptureMode(.photo) }
                    ),
                    DiagonalBubbleItem(
                        title: "VIDEO",
                        subtitle: camera.captureMode == .video ? "ACTIVE" : "SWITCH",
                        action: { camera.updateCaptureMode(.video) }
                    )
                ]
            )

        case .camera:
            diagonalBubbleScreen(
                title: "CAMERA",
                subtitle: "PROFILE / QUALITY / SIZE",
                bubbles: [
                    DiagonalBubbleItem(
                        title: "PROFILE",
                        subtitle: camera.selectedPreset.shortTitle.uppercased(),
                        action: { cyclePreset() }
                    ),
                    DiagonalBubbleItem(
                        title: "QUALITY",
                        subtitle: camera.selectedImageQuality.title.uppercased(),
                        action: { cycleQuality() }
                    ),
                    DiagonalBubbleItem(
                        title: "SIZE",
                        subtitle: shortImageSizeTitle(camera.selectedImageSize),
                        action: { cycleImageSize() }
                    ),
                    DiagonalBubbleItem(
                        title: "PROC",
                        subtitle: camera.selectedProcessorMode.title.uppercased(),
                        action: { cycleProcessorMode() }
                    ),
                    DiagonalBubbleItem(
                        title: "FLASH",
                        subtitle: camera.photoFlashMode.title.uppercased(),
                        action: { cycleFlashMode() }
                    ),
                    DiagonalBubbleItem(
                        title: "STAMP",
                        subtitle: camera.addDateStamp ? "ON" : "OFF",
                        action: { camera.addDateStamp.toggle() }
                    ),
                    DiagonalBubbleItem(
                        title: "FILTER",
                        subtitle: camera.useRetroFilter ? "RETRO" : "RAW",
                        action: { camera.useRetroFilter.toggle() }
                    ),
                    DiagonalBubbleItem(
                        title: "CAMERA",
                        subtitle: "FRONT / BACK",
                        action: { camera.switchCamera() }
                    )
                ]
            )

        case .themes:
            diagonalBubbleScreen(
                title: "THEMES",
                subtitle: "BACKGROUND / VIBE",
                bubbles: AppTheme.allCases.map { theme in
                    DiagonalBubbleItem(
                        title: theme.displayName.uppercased(),
                        subtitle: selectedTheme == theme ? "ACTIVE" : "SET",
                        action: { storedThemeName = theme.rawValue }
                    )
                }
            )

        case .smiley:
            diagonalBubbleScreen(
                title: "SMILEY",
                subtitle: "PNG / JPG / GIF",
                bubbles: smileyBubbleItems()
            )

        case .language:
            diagonalBubbleScreen(
                title: "LANG",
                subtitle: "APP LANGUAGE",
                bubbles: AppLanguage.allCases.map { language in
                    DiagonalBubbleItem(
                        title: language.displayName.uppercased(),
                        subtitle: selectedLanguage == language ? "ACTIVE" : "SET",
                        action: { storedLanguageCode = language.rawValue }
                    )
                }
            )

        case .importSection:
            diagonalBubbleScreen(
                title: "IMPORT",
                subtitle: "FUTURE SLOT",
                bubbles: [
                    DiagonalBubbleItem(
                        title: "BUNDLE",
                        subtitle: "READY",
                        action: {}
                    ),
                    DiagonalBubbleItem(
                        title: "MEDIA",
                        subtitle: "GALLERY",
                        action: {
                            library.requestAndLoad()
                            route = .gallery
                        }
                    ),
                    DiagonalBubbleItem(
                        title: "BACKUP",
                        subtitle: "LATER",
                        action: {}
                    )
                ]
            )
        }
    }

    func diagonalBubbleScreen(title: String, subtitle: String, bubbles: [DiagonalBubbleItem]) -> some View {
        VStack(spacing: 0) {
            SettingsHeader(
                theme: selectedTheme,
                title: title,
                subtitle: subtitle,
                onBack: { route = .settingsHub }
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ForEach(Array(bubbles.enumerated()), id: \.offset) { index, item in
                        HStack {
                            if index.isMultiple(of: 2) {
                                bubbleView(item, xOffset: -22)
                                Spacer(minLength: 0)
                            } else {
                                Spacer(minLength: 0)
                                bubbleView(item, xOffset: 22)
                            }
                        }
                    }

                    LargeBackButton(theme: selectedTheme, title: "BACK") {
                        route = .settingsHub
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            }
        }
    }

    func bubble(for entry: SettingsHubEntry, large: Bool) -> some View {
        FloatingBubbleButton(
            theme: selectedTheme,
            title: entry.title,
            subtitle: entry.subtitle(for: camera, theme: selectedTheme, smiley: effectiveSmiley),
            size: large ? 150 : 132
        ) {
            route = .settingsDetail(entry.detail)
        }
    }

    func bubbleView(_ item: DiagonalBubbleItem, xOffset: CGFloat) -> some View {
        FloatingBubbleButton(
            theme: selectedTheme,
            title: item.title,
            subtitle: item.subtitle,
            size: 150
        ) {
            item.action()
        }
        .offset(x: xOffset)
    }

    func makeHubRows(from entries: [SettingsHubEntry]) -> [[SettingsHubEntry]] {
        var rows: [[SettingsHubEntry]] = []
        var index = 0
        var useTwo = true

        while index < entries.count {
            let count = useTwo ? min(2, entries.count - index) : 1
            rows.append(Array(entries[index ..< index + count]))
            index += count
            useTwo.toggle()
        }

        return rows
    }

    func cycleQuality() {
        let all = RetroImageQuality.allCases
        guard let index = all.firstIndex(of: camera.selectedImageQuality) else {
            camera.updateImageQuality(.economy)
            return
        }
        camera.updateImageQuality(all[(index + 1) % all.count])
    }

    func cycleProcessorMode() {
        let all = RetroProcessorMode.allCases
        guard let index = all.firstIndex(of: camera.selectedProcessorMode) else {
            camera.updateProcessorMode(.realistic)
            return
        }
        camera.updateProcessorMode(all[(index + 1) % all.count])
    }

    func cycleFlashMode() {
        let all = PhotoFlashMode.allCases
        guard let index = all.firstIndex(of: camera.photoFlashMode) else {
            camera.updateFlashMode(.off)
            return
        }
        camera.updateFlashMode(all[(index + 1) % all.count])
    }

    func smileyBubbleItems() -> [DiagonalBubbleItem] {
        let all = SmileyAsset.availableSmileys(themeNames: AppTheme.allCases.map(\.rawValue))

        var items: [DiagonalBubbleItem] = [
            DiagonalBubbleItem(
                title: "AUTO",
                subtitle: storedManualSmileyName.isEmpty ? "THEME LINK" : "ENABLE",
                action: { storedManualSmileyName = "" }
            )
        ]

        items.append(contentsOf: all.map { asset in
            DiagonalBubbleItem(
                title: asset.displayName.uppercased(),
                subtitle: storedManualSmileyName == asset.baseName ? "ACTIVE" : asset.kind.badgeText,
                action: { storedManualSmileyName = asset.baseName }
            )
        })

        return items
    }
}

// MARK: - Shared UI

private struct DeviceShell<Content: View>: View {
    let theme: AppTheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.panelGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(theme.borderColor.opacity(0.95), lineWidth: 2)
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.03))
                .padding(6)

            content()
        }
        .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
    }
}

private struct ThemeBackgroundView: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if theme.backgroundAssetName != nil {
                ResourceImageView(name: theme.backgroundAssetName!)
                    .scaledToFill()
                    .opacity(0.18)
                    .blur(radius: 0.2)
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.00),
                            Color.black.opacity(0.16)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

private struct TopStatusBar: View {
    let theme: AppTheme
    let date: Date
    let recordingDuration: TimeInterval
    let isRecording: Bool
    let smiley: SmileyAsset?

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                NetworkIndicator(theme: theme)
                BatteryIndicator(theme: theme)
            }

            Spacer(minLength: 8)

            Text(isRecording ? formatDuration(recordingDuration) : moscowTimeString(from: date))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.primaryTextColor)
                .lineLimit(1)

            Spacer(minLength: 8)

            SmileyCircleView(smiley: smiley, theme: theme)
                .frame(width: 34, height: 34)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.topBarFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.borderColor.opacity(0.9), lineWidth: 1.5)
                )
        )
    }
}

private struct CompactSelectorCapsule: View {
    let title: String
    let value: String
    let theme: AppTheme
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.secondaryTextColor)

                Text(value)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isActive ? theme.primaryTextColor : theme.primaryTextColor.opacity(0.92))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(theme.softCapsuleFill)
                    .overlay(
                        Capsule().stroke(theme.borderColor.opacity(0.65), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BottomSoftKeyBar: View {
    let theme: AppTheme
    let leftAction: () -> Void
    let centerAction: () -> Void
    let rightAction: () -> Void
    let centerResourceName: String
    let leftLabel: String
    let rightLabel: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            BottomCornerButton(
                theme: theme,
                title: leftLabel,
                resourceName: "icon",
                action: leftAction
            )

            Spacer(minLength: 0)

            CenterActionButton(
                theme: theme,
                resourceName: centerResourceName,
                action: centerAction
            )

            Spacer(minLength: 0)

            BottomCornerButton(
                theme: theme,
                title: rightLabel,
                resourceName: nil,
                systemSymbol: "gearshape.fill",
                action: rightAction
            )
        }
    }
}

private struct BottomCornerButton: View {
    let theme: AppTheme
    let title: String
    let resourceName: String?
    let systemSymbol: String?
    let action: () -> Void

    init(
        theme: AppTheme,
        title: String,
        resourceName: String?,
        systemSymbol: String? = nil,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.resourceName = resourceName
        self.systemSymbol = systemSymbol
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.softCapsuleFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(theme.borderColor.opacity(0.75), lineWidth: 1.2)
                        )
                        .frame(width: 66, height: 52)

                    if let resourceName {
                        ResourceImageView(name: resourceName)
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                    } else if let systemSymbol {
                        Image(systemName: systemSymbol)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(theme.primaryTextColor)
                    }
                }

                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.primaryTextColor)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CenterActionButton: View {
    let theme: AppTheme
    let resourceName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(theme.bubbleGradient)
                    .frame(width: 84, height: 84)
                    .overlay(
                        Circle()
                            .stroke(theme.borderColor.opacity(0.86), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 4)

                if ResourceImageLoader.image(named: resourceName) != nil {
                    ResourceImageView(name: resourceName)
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(theme.primaryTextColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DateOverlayStamp: View {
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        Text(dateString)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.24))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.42))
            .clipShape(Capsule())
    }
}

private struct SettingsHeader: View {
    let theme: AppTheme
    let title: String
    let subtitle: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                    Text("BACK")
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.primaryTextColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(theme.softCapsuleFill)
                        .overlay(
                            Capsule().stroke(theme.borderColor.opacity(0.72), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundStyle(theme.primaryTextColor)

                Text(subtitle)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.secondaryTextColor)
            }

            Spacer()

            if ResourceImageLoader.image(named: "mainphoto") != nil {
                ResourceImageView(name: "mainphoto")
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            } else {
                Circle()
                    .fill(theme.softCapsuleFill)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(theme.borderColor.opacity(0.72), lineWidth: 1)
                    )
            }
        }
    }
}

private struct FloatingBubbleButton: View {
    let theme: AppTheme
    let title: String
    let subtitle: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(theme.bubbleGradient)
                    .overlay(
                        Circle()
                            .stroke(theme.borderColor.opacity(0.9), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.34),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: size * 0.55
                        )
                    )
                    .scaleEffect(0.92)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: size > 140 ? 14 : 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(theme.primaryTextColor)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: size > 140 ? 9 : 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}

private struct LargeBackButton: View {
    let theme: AppTheme
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 14, weight: .black))

                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
            }
            .foregroundStyle(theme.primaryTextColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(theme.softCapsuleFill)
                    .overlay(
                        Capsule().stroke(theme.borderColor.opacity(0.78), lineWidth: 1.2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gallery

private struct GalleryScreen: View {
    let theme: AppTheme
    @ObservedObject var library: MediaLibraryStore
    let onBack: () -> Void
    let onSelect: (MediaItem) -> Void

    private let grid = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader(
                theme: theme,
                title: "GALLERY",
                subtitle: "LOCAL MEDIA",
                onBack: onBack
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)

            if library.items.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(theme.secondaryTextColor)

                    Text(emptyStateText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.primaryTextColor)
                        .multilineTextAlignment(.center)

                    Button("REFRESH") {
                        library.requestAndLoad()
                    }
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(theme.softCapsuleFill)
                            .overlay(
                                Capsule().stroke(theme.borderColor.opacity(0.72), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(theme.primaryTextColor)
                }
                .padding(.horizontal, 24)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: grid, spacing: 10) {
                        ForEach(library.items) { item in
                            AssetThumbnailView(item: item, library: library, theme: theme)
                                .onTapGesture {
                                    onSelect(item)
                                }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private var emptyStateText: String {
        switch library.authorizationStatus {
        case .denied, .restricted:
            return "PHOTO ACCESS DENIED"
        default:
            return "NO MEDIA YET"
        }
    }
}

private struct AssetThumbnailView: View {
    let item: MediaItem
    @ObservedObject var library: MediaLibraryStore
    let theme: AppTheme

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.softCapsuleFill)
                .frame(height: 112)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.borderColor.opacity(0.72), lineWidth: 1.2)
                )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ProgressView()
                    .tint(theme.primaryTextColor)
            }

            HStack(spacing: 5) {
                if item.mediaType == .video {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10, weight: .heavy))
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 10, weight: .heavy))
                }

                Text(item.bottomRightLabel)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.62))
            .clipShape(Capsule())
            .padding(7)
        }
        .onAppear {
            library.thumbnail(for: item, targetSize: CGSize(width: 240, height: 240)) { image in
                self.image = image
            }
        }
    }
}

// MARK: - Media Viewer

private struct MediaViewerScreen: View {
    let theme: AppTheme
    let item: MediaItem
    @ObservedObject var library: MediaLibraryStore
    let onBack: () -> Void

    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader(
                theme: theme,
                title: "VIEWER",
                subtitle: item.mediaType == .video ? "VIDEO WINDOW" : "PHOTO WINDOW",
                onBack: onBack
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Spacer(minLength: 10)

            viewerWindow

            Spacer(minLength: 10)

            BottomViewerBar(theme: theme, mediaType: item.mediaType, onBack: onBack)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
        }
        .onAppear {
            load()
        }
        .onDisappear {
            player?.pause()
        }
    }

    var viewerWindow: some View {
        ZStack {
            if ResourceImageLoader.image(named: "window") != nil {
    ResourceImageView(name: "window")
        .scaledToFit()
        .frame(maxWidth: 360)
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.panelGradient)
                    .frame(maxWidth: 360)
                    .aspectRatio(0.86, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(theme.borderColor.opacity(0.86), lineWidth: 2)
                    )
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.75))

                if isLoading {
                    ProgressView()
                        .tint(theme.primaryTextColor)
                } else if item.mediaType == .image, let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if item.mediaType == .video, let player {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onAppear {
                            player.play()
                        }
                } else {
                    Text("NO MEDIA")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.white)
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 48)
            .padding(.bottom, 80)
            .frame(maxWidth: 360)
            .aspectRatio(0.86, contentMode: .fit)
        }
        .padding(.horizontal, 18)
    }

    func load() {
        isLoading = true
        image = nil
        player = nil

        if item.mediaType == .image {
            library.fullImage(for: item) { image in
                self.image = image
                self.isLoading = false
            }
        } else {
            library.player(for: item) { player in
                self.player = player
                self.isLoading = false
            }
        }
    }
}

private struct BottomViewerBar: View {
    let theme: AppTheme
    let mediaType: MediaKind
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)

            Button(action: onBack) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                    Text("BACK")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(theme.primaryTextColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(theme.softCapsuleFill)
                        .overlay(
                            Capsule().stroke(theme.borderColor.opacity(0.75), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - App models

private enum AppRoute: Equatable {
    case camera
    case gallery
    case viewer
    case settingsHub
    case settingsDetail(SettingsDetail)
}

private enum SettingsDetail: Equatable {
    case mode
    case camera
    case themes
    case smiley
    case language
    case importSection
}

private enum SettingsHubEntry: String, CaseIterable, Hashable {
    case mode
    case camera
    case themes
    case smiley
    case language
    case importSection

    var title: String {
        switch self {
        case .mode:
            return "MODE"
        case .camera:
            return "CAMERA"
        case .themes:
            return "THEMES"
        case .smiley:
            return "SMILEY"
        case .language:
            return "LANG"
        case .importSection:
            return "IMPORT"
        }
    }

    var detail: SettingsDetail {
        switch self {
        case .mode:
            return .mode
        case .camera:
            return .camera
        case .themes:
            return .themes
        case .smiley:
            return .smiley
        case .language:
            return .language
        case .importSection:
            return .importSection
        }
    }

    func subtitle(for camera: CameraService, theme: AppTheme, smiley: SmileyAsset?) -> String {
        switch self {
        case .mode:
            return camera.captureMode == .photo ? "PHOTO / VIDEO" : "VIDEO / PHOTO"
        case .camera:
            return camera.selectedPreset.shortTitle.uppercased()
        case .themes:
            return theme.displayName.uppercased()
        case .smiley:
            return smiley?.displayName.uppercased() ?? "AUTO"
        case .language:
            return "RU / EN"
        case .importSection:
            return "MEDIA / BUNDLE"
        }
    }
}

private struct DiagonalBubbleItem {
    let title: String
    let subtitle: String
    let action: () -> Void
}

private enum AppLanguage: String, CaseIterable {
    case ru
    case en

    var displayName: String {
        switch self {
        case .ru:
            return "RU"
        case .en:
            return "EN"
        }
    }
}

private enum AppTheme: String, CaseIterable, Identifiable {
    case classic
    case minihui
    case backminihui

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:
            return "Classic"
        case .minihui:
            return "Minihui"
        case .backminihui:
            return "Back Minihui"
        }
    }

    var backgroundAssetName: String? {
        switch self {
        case .classic:
            return nil
        case .minihui:
            return "minihui"
        case .backminihui:
            return "backminihui"
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .classic:
            return [
                Color(red: 0.69, green: 0.73, blue: 0.66),
                Color(red: 0.54, green: 0.58, blue: 0.54),
                Color(red: 0.36, green: 0.40, blue: 0.38)
            ]
        case .minihui:
            return [
                Color(red: 0.78, green: 0.86, blue: 0.80),
                Color(red: 0.60, green: 0.68, blue: 0.62),
                Color(red: 0.38, green: 0.45, blue: 0.42)
            ]
        case .backminihui:
            return [
                Color(red: 0.85, green: 0.89, blue: 0.82),
                Color(red: 0.64, green: 0.70, blue: 0.64),
                Color(red: 0.40, green: 0.45, blue: 0.42)
            ]
        }
    }

    var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.28),
                Color.white.opacity(0.10),
                Color.black.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var bubbleGradient: LinearGradient {
        switch self {
        case .classic:
            return LinearGradient(
                colors: [
                    Color(red: 0.84, green: 0.96, blue: 1.0),
                    Color(red: 0.54, green: 0.72, blue: 0.85),
                    Color(red: 0.34, green: 0.48, blue: 0.63)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .minihui, .backminihui:
            return LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.98, blue: 1.0),
                    Color(red: 0.62, green: 0.80, blue: 0.90),
                    Color(red: 0.36, green: 0.54, blue: 0.67)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var borderColor: Color {
        Color(red: 0.17, green: 0.22, blue: 0.22)
    }

    var softCapsuleFill: Color {
        Color.white.opacity(0.20)
    }

    var primaryTextColor: Color {
        Color(red: 0.08, green: 0.10, blue: 0.10)
    }

    var secondaryTextColor: Color {
        Color(red: 0.22, green: 0.26, blue: 0.26)
    }

    var topBarFill: Color {
        Color.white.opacity(0.28)
    }
}

// MARK: - Static resource loading

private struct ResourceImageView: View {
    let name: String

    var body: some View {
        if let image = ResourceImageLoader.image(named: name) {
            Image(uiImage: image)
                .renderingMode(.original)
                .resizable()
        } else {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .padding(6)
        }
    }
}

private enum ResourceImageLoader {
    static func image(named name: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }

        let extensions = ["png", "jpg", "jpeg", "webp", "gif"]

        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }

        return nil
    }
}

// MARK: - Smiley support

private struct SmileyAsset: Identifiable, Hashable {
    enum Kind: Hashable {
        case image
        case gif

        var badgeText: String {
            switch self {
            case .image:
                return "IMG"
            case .gif:
                return "GIF"
            }
        }
    }

    let baseName: String
    let kind: Kind
    let fileURL: URL?
    let assetCatalogName: String?

    var id: String { baseName }

    var displayName: String {
        baseName
    }

    static func find(named name: String) -> SmileyAsset? {
        if let url = Bundle.main.url(forResource: name, withExtension: "gif") {
            return SmileyAsset(baseName: name, kind: .gif, fileURL: url, assetCatalogName: nil)
        }

        for ext in ["png", "jpg", "jpeg", "webp"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return SmileyAsset(baseName: name, kind: .image, fileURL: url, assetCatalogName: nil)
            }
        }

        if UIImage(named: name) != nil {
            return SmileyAsset(baseName: name, kind: .image, fileURL: nil, assetCatalogName: name)
        }

        return nil
    }

    static func availableSmileys(themeNames: [String]) -> [SmileyAsset] {
        let excluded = Set([
            "icon",
            "play",
            "play2",
            "play3",
            "window",
            "mainphoto",
            "minihui",
            "backminihui"
        ])

        var names = Set<String>()

        let defaults = [
            "clownS",
            "cupsizeS",
            "cupsizeNS",
            "donutsepia"
        ]
        defaults.forEach { names.insert($0) }

        themeNames.forEach {
            names.insert($0 + "S")
        }

        let extensions = ["png", "jpg", "jpeg", "gif", "webp"]
        for ext in extensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for url in urls {
                    let base = url.deletingPathExtension().lastPathComponent
                    guard !excluded.contains(base) else { continue }
                    names.insert(base)
                }
            }
        }

        let resolved = names.compactMap { name -> SmileyAsset? in
            guard !excluded.contains(name) else { return nil }
            return SmileyAsset.find(named: name)
        }

        return resolved.sorted { $0.baseName.localizedCaseInsensitiveCompare($1.baseName) == .orderedAscending }
    }
}

private struct SmileyCircleView: View {
    let smiley: SmileyAsset?
    let theme: AppTheme

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.softCapsuleFill)
                .overlay(
                    Circle().stroke(theme.borderColor.opacity(0.72), lineWidth: 1.2)
                )

            if let smiley {
                switch smiley.kind {
                case .image:
                    if let uiImage = resolvedImage(smiley) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                            .padding(2)
                    } else {
                        fallbackFace
                    }

                case .gif:
                    if let fileURL = smiley.fileURL {
                        GIFView(url: fileURL)
                            .clipShape(Circle())
                            .padding(2)
                    } else {
                        fallbackFace
                    }
                }
            } else {
                fallbackFace
            }
        }
    }

    private var fallbackFace: some View {
        Text(":)")
            .font(.system(size: 14, weight: .heavy, design: .monospaced))
            .foregroundStyle(theme.primaryTextColor)
    }

    private func resolvedImage(_ asset: SmileyAsset) -> UIImage? {
        if let assetCatalogName = asset.assetCatalogName {
            return UIImage(named: assetCatalogName)
        }
        if let fileURL = asset.fileURL {
            return UIImage(contentsOfFile: fileURL.path)
        }
        return nil
    }
}

private struct GIFView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.clipsToBounds = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <html>
        <head>
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0">
        <style>
        html,body{
            margin:0;padding:0;background:transparent;overflow:hidden;
            width:100%;height:100%;
            display:flex;align-items:center;justify-content:center;
        }
        img{
            width:100%;height:100%;object-fit:cover;border-radius:9999px;
        }
        </style>
        </head>
        <body>
            <img src="\(url.lastPathComponent)" />
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }
}

// MARK: - Status icons

private struct NetworkIndicator: View {
    let theme: AppTheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(theme.primaryTextColor)
                    .frame(width: 4, height: CGFloat(6 + index * 4))
            }
        }
    }
}

private struct BatteryIndicator: View {
    let theme: AppTheme

    private var level: CGFloat {
        let value = UIDevice.current.batteryLevel
        if value < 0 { return 0.72 }
        return CGFloat(value)
    }

    var body: some View {
        HStack(spacing: 3) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(theme.primaryTextColor, lineWidth: 1.2)
                    .frame(width: 24, height: 12)

                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(theme.primaryTextColor)
                    .frame(width: max(4, 20 * level), height: 8)
                    .padding(.leading, 2)
            }

            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(theme.primaryTextColor)
                .frame(width: 2.5, height: 6)
        }
    }
}

// MARK: - Media library

private enum MediaKind {
    case image
    case video
}

private struct MediaItem: Identifiable, Hashable {
    let asset: PHAsset

    var id: String { asset.localIdentifier }

    var mediaType: MediaKind {
        asset.mediaType == .video ? .video : .image
    }

    var bottomRightLabel: String {
        switch mediaType {
        case .image:
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM"
            return formatter.string(from: asset.creationDate ?? Date())
        case .video:
            return formatDuration(asset.duration)
        }
    }
}

private final class MediaLibraryStore: NSObject, ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    private let manager = PHCachingImageManager()
    private var thumbCache = NSCache<NSString, UIImage>()

    func requestAndLoad() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status

        switch status {
        case .authorized, .limited:
            loadAssets()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    if status == .authorized || status == .limited {
                        self?.loadAssets()
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                self.items = []
            }
        }
    }

    func loadAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: options)

        var collected: [MediaItem] = []
        result.enumerateObjects { asset, _, _ in
            if asset.mediaType == .image || asset.mediaType == .video {
                collected.append(MediaItem(asset: asset))
            }
        }

        DispatchQueue.main.async {
            self.items = collected
        }
    }

    func thumbnail(for item: MediaItem, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = "\(item.id)-\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
        if let cached = thumbCache.object(forKey: cacheKey) {
            completion(cached)
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        manager.requestImage(
            for: item.asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            if let image {
                self?.thumbCache.setObject(image, forKey: cacheKey)
            }
            completion(image)
        }
    }

    func fullImage(for item: MediaItem, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true

        manager.requestImageDataAndOrientation(for: item.asset, options: options) { data, _, _, _ in
            let image = data.flatMap { UIImage(data: $0) }
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    func player(for item: MediaItem, completion: @escaping (AVPlayer?) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic

        manager.requestAVAsset(forVideo: item.asset, options: options) { asset, _, _ in
            let player = asset.map { AVPlayer(playerItem: AVPlayerItem(asset: $0)) }
            DispatchQueue.main.async {
                completion(player)
            }
        }
    }
}

// MARK: - Helpers

private func moscowTimeString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(identifier: "Europe/Moscow")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date) + " MSK"
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let total = max(0, Int(duration.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60

    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
