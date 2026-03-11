import SwiftUI
import AVFoundation
import Photos
import AVKit

struct ContentView: View {
    enum Screen: String, CaseIterable {
        case camera = "Камера"
        case cameraSelector = "Выбор камеры"
        case options = "Опции"
        case settings = "Настройки"
        case gallery = "Галерея"
        case editor = "Редактор"
        case themes = "Темы"
    }

    enum CaptureMode: String, CaseIterable, Identifiable {
        case photo = "Фото"
        case video = "Видео"

        var id: String { rawValue }
    }

    @StateObject private var camera = CameraService()

    @State private var currentScreen: Screen = .camera
    @State private var captureMode: CaptureMode = .photo

    @State private var gallerySelectedAssetID: String?
    @State private var galleryViewerPresented = false

    var body: some View {
        LegacyShell {
            LegacyHeaderBar(
                title: currentScreen.rawValue,
                status: headerStatus
            )

            LegacyScreenPanel {
                screenBody
            }

            LegacySoftKeyBar(
                leftTitle: leftSoftKeyTitle,
                centerTitle: centerSoftKeyTitle,
                rightTitle: rightSoftKeyTitle,
                leftAction: leftSoftKeyAction,
                centerAction: centerSoftKeyAction,
                rightAction: rightSoftKeyAction
            )
        }
        .onAppear { camera.startIfNeeded() }
        .onDisappear { camera.stop() }
    }

    private var headerStatus: String {
        if captureMode == .video && camera.isRecording {
            return "REC"
        }
        return "READY"
    }

    @ViewBuilder
    private var screenBody: some View {
        switch currentScreen {
        case .camera:
            cameraScreen

        case .cameraSelector:
            cameraSelectorScreen

        case .options:
            optionsScreen

        case .settings:
            settingsScreen

        case .gallery:
            LegacyGalleryScreen(
                selectedAssetID: $gallerySelectedAssetID,
                presentViewer: $galleryViewerPresented
            )

        case .editor:
            placeholderScreen(
                title: "Редактор",
                lines: [
                    "Сюда потом перенесём логику редактирования фото.",
                    "Отдельным экраном, как в старом приложении."
                ]
            )

        case .themes:
            themesScreen
        }
    }

    private var cameraScreen: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                legacyTab(title: "CAM", isActive: true) { }
                legacyTab(title: "OPT", isActive: false) { currentScreen = .options }
                legacyTab(title: "GAL", isActive: false) { currentScreen = .gallery }
                legacyTab(title: "THM", isActive: false) { currentScreen = .themes }
            }

            previewBlock
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .background(LegacyPalette.previewFrame)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(LegacyPalette.frameBorder, lineWidth: 3)
                )

            HStack(spacing: 8) {
                LegacyValueTile(title: "РЕЖИМ", value: captureMode.rawValue) {
                    guard !camera.isRecording else { return }
                    cycleCaptureMode()
                }

                LegacyValueTile(title: "ПРОФИЛЬ", value: camera.selectedPreset.shortTitle) {
                    currentScreen = .cameraSelector
                }

                LegacyValueTile(title: "ОПЦИИ", value: "ОТКРЫТЬ") {
                    currentScreen = .options
                }
            }

            HStack(spacing: 8) {
                LegacyToggleTile(title: "RETRO", isOn: $camera.useRetroFilter)
                LegacyToggleTile(title: "ДАТА", isOn: $camera.addDateStamp)
            }

            HStack(spacing: 8) {
                Button {
                    camera.switchCamera()
                } label: {
                    LegacyActionButtonLabel(
                        titleTop: "СМЕНА",
                        titleBottom: "КАМЕРЫ",
                        dark: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(camera.isRecording)

                Button {
                    if captureMode == .photo {
                        camera.takePhoto()
                    } else {
                        camera.toggleRecording()
                    }
                } label: {
                    LegacyActionButtonLabel(
                        titleTop: captureMode == .video ? (camera.isRecording ? "STOP" : "REC") : "SHOT",
                        titleBottom: captureMode == .video ? "VIDEO" : "PHOTO",
                        dark: true
                    )
                }
                .buttonStyle(.plain)

                Button {
                    currentScreen = .settings
                } label: {
                    LegacyActionButtonLabel(
                        titleTop: "ПОЛНЫЕ",
                        titleBottom: "НАСТРОЙКИ",
                        dark: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func legacyTab(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(isActive ? LegacyPalette.active : LegacyPalette.soft)
                .foregroundStyle(isActive ? LegacyPalette.activeText : LegacyPalette.ink)
                .overlay(
                    Rectangle()
                        .fill(isActive ? Color.white.opacity(0.08) : .clear)
                        .frame(height: 1),
                    alignment: .top
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var previewBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LegacyPalette.previewInset)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black)
                .padding(8)

            ZStack(alignment: .topLeading) {
                if let previewImage = camera.previewImage {
                    GeometryReader { geo in
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(8)
                } else {
                    CameraPreview(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 5) {
                    LegacyInfoBadge(title: "MODEL", value: camera.selectedPreset.title)
                    LegacyInfoBadge(title: "MODE", value: captureMode.rawValue.uppercased())
                    LegacyInfoBadge(title: "FPS", value: "\(camera.selectedPreviewFPS)")

                    if captureMode == .video && camera.isRecording {
                        LegacyInfoBadge(title: "STATE", value: "REC")
                    }
                }
                .padding(14)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(camera.captureAspect.title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegacyPalette.previewText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(14)
                }
            }
        }
    }

    private var cameraSelectorScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            LegacySectionTitle(title: "Выбор камеры")

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(RetroPreset.allCases) { preset in
                        LegacyMenuRow(
                            title: preset.title,
                            subtitle: cameraProfileSubtitle(for: preset),
                            isSelected: preset == camera.selectedPreset
                        ) {
                            camera.selectedPreset = preset
                            currentScreen = .camera
                        }
                    }
                }
            }
        }
    }

    private func cameraProfileSubtitle(for preset: RetroPreset) -> String {
        switch preset {
        case .pointAndShoot:
            return "Мягкий цифровой компакт"
        case .vhs:
            return "Размытая VHS-эстетика"
        case .oldPhone:
            return "Главный режим 0.3MP"
        case .nokia6230i:
            return "1.3MP с жёсткой обработкой"
        case .n73:
            return "Более чистая 3.2MP картинка"
        }
    }

    private var optionsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LegacySectionTitle(title: "Быстрые опции")

                LegacyCard {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            LegacyValueTile(title: "РЕЖИМ", value: captureMode.rawValue) {
                                guard !camera.isRecording else { return }
                                cycleCaptureMode()
                            }

                            LegacyValueTile(title: "FPS", value: "\(camera.selectedPreviewFPS)") {
                                cycleFPS()
                            }

                            LegacyValueTile(title: "ФОРМАТ", value: camera.captureAspect.title) {
                                cycleAspect()
                            }
                        }

                        HStack(spacing: 8) {
                            LegacyToggleTile(title: "RETRO", isOn: $camera.useRetroFilter)
                            LegacyToggleTile(title: "ДАТА", isOn: $camera.addDateStamp)
                        }

                        if captureMode == .photo {
                            HStack(spacing: 8) {
                                LegacyValueTile(title: "FLASH", value: camera.photoFlashMode.title) {
                                    cycleFlash()
                                }

                                LegacyValueTile(title: "ПРОФИЛЬ", value: camera.selectedPreset.shortTitle) {
                                    currentScreen = .cameraSelector
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                LegacyValueTile(title: "ВИДЕО", value: camera.isRecording ? "REC" : "READY") { }
                                LegacyValueTile(title: "ПРОФИЛЬ", value: camera.selectedPreset.shortTitle) {
                                    currentScreen = .cameraSelector
                                }
                            }
                        }
                    }
                }

                LegacySectionTitle(title: "Меню")

                VStack(spacing: 8) {
                    LegacyMenuRow(title: "Выбор камеры", subtitle: "Список профилей") {
                        currentScreen = .cameraSelector
                    }

                    LegacyMenuRow(title: "Полные настройки", subtitle: "Оптика, экспозиция, формат") {
                        currentScreen = .settings
                    }

                    LegacyMenuRow(title: "Темы", subtitle: "Оформление оболочки") {
                        currentScreen = .themes
                    }

                    LegacyMenuRow(title: "Галерея", subtitle: "Фото и видео внутри приложения") {
                        currentScreen = .gallery
                    }
                }
            }
        }
    }

    private var settingsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LegacySectionTitle(title: "Режим съёмки")

                LegacyCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("FPS: \(camera.selectedPreviewFPS)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))

                        Picker(
                            "FPS",
                            selection: Binding(
                                get: { camera.selectedPreviewFPS },
                                set: { camera.updatePreviewFPS($0) }
                            )
                        ) {
                            Text("24").tag(24)
                            Text("30").tag(30)
                            Text("60").tag(60)
                        }
                        .pickerStyle(.segmented)

                        Text("Формат: \(camera.captureAspect.title)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))

                        Picker(
                            "Формат",
                            selection: Binding(
                                get: { camera.captureAspect },
                                set: { camera.updateCaptureAspect($0) }
                            )
                        ) {
                            ForEach(CaptureAspect.allCases) { aspect in
                                Text(aspect.title).tag(aspect)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if captureMode == .photo {
                    LegacySectionTitle(title: "Фото")

                    LegacyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Вспышка: \(camera.photoFlashMode.title)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))

                            Picker(
                                "Вспышка",
                                selection: Binding(
                                    get: { camera.photoFlashMode },
                                    set: { camera.updateFlashMode($0) }
                                )
                            ) {
                                ForEach(PhotoFlashMode.allCases) { flash in
                                    Text(flash.title).tag(flash)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                LegacySectionTitle(title: "Оптика")

                LegacyCard {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Зум")
                                Spacer()
                                Text(String(format: "%.1fx", camera.zoomFactor))
                                    .monospacedDigit()
                            }

                            Slider(
                                value: Binding(
                                    get: { camera.zoomFactor },
                                    set: { camera.updateZoom($0) }
                                ),
                                in: 1...6
                            )
                        }

                        Toggle(
                            "Ручной фокус",
                            isOn: Binding(
                                get: { camera.manualFocusEnabled },
                                set: { camera.updateManualFocusEnabled($0) }
                            )
                        )

                        if camera.manualFocusEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Фокус")
                                    Spacer()
                                    Text(String(format: "%.2f", camera.focusPosition))
                                        .monospacedDigit()
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(camera.focusPosition) },
                                        set: { camera.updateFocusPosition(Float($0)) }
                                    ),
                                    in: 0...1
                                )
                            }
                        }
                    }
                }

                LegacySectionTitle(title: "Экспозиция")

                LegacyCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(
                            "Ручная экспозиция",
                            isOn: Binding(
                                get: { camera.manualExposureEnabled },
                                set: { camera.updateManualExposureEnabled($0) }
                            )
                        )

                        if camera.manualExposureEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("ISO")
                                    Spacer()
                                    Text(String(format: "%.2f", camera.manualISOValue))
                                        .monospacedDigit()
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(camera.manualISOValue) },
                                        set: { camera.updateManualISOValue(Float($0)) }
                                    ),
                                    in: 0...1
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Выдержка")
                                    Spacer()
                                    Text(String(format: "%.2f", camera.manualShutterValue))
                                        .monospacedDigit()
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(camera.manualShutterValue) },
                                        set: { camera.updateManualShutterValue(Float($0)) }
                                    ),
                                    in: 0...1
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var themesScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LegacySectionTitle(title: "Темы")

                LegacyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Экран тем уже выделен как отдельный модуль.")
                            .font(.system(size: 14, weight: .bold))

                        Text("Следующим шагом сюда можно добавить реальное переключение оболочки.")
                            .font(.system(size: 13))
                    }
                }

                VStack(spacing: 8) {
                    LegacyMenuRow(title: "Classic Green", subtitle: "Базовая тема оболочки", isSelected: true) { }
                    LegacyMenuRow(title: "Dark Steel", subtitle: "Тёмная телефонная тема") { }
                    LegacyMenuRow(title: "Blue Menu", subtitle: "Псевдо Series 40") { }
                }
            }
        }
    }

    private func placeholderScreen(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LegacySectionTitle(title: title)

            LegacyCard {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lines, id: \.self) { line in
                        Text("• \(line)")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }

            Spacer()

            Button {
                currentScreen = .camera
            } label: {
                Text("Назад к камере")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LegacyPalette.active)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.black)
    }

    private var leftSoftKeyTitle: String {
        switch currentScreen {
        case .camera:
            return "Опции"
        default:
            return "Назад"
        }
    }

    private var centerSoftKeyTitle: String {
        switch currentScreen {
        case .camera:
            return captureMode == .photo
                ? "Снять"
                : (camera.isRecording ? "Стоп" : "Rec")
        case .cameraSelector:
            return "Выбрать"
        case .options:
            return "Камера"
        case .settings:
            return "Камера"
        case .gallery:
            return gallerySelectedAssetID == nil ? "Выбрать" : "Открыть"
        case .editor:
            return "Применить"
        case .themes:
            return "Выбрать"
        }
    }

    private var rightSoftKeyTitle: String {
        switch currentScreen {
        case .camera:
            return "Меню"
        case .cameraSelector:
            return "Камера"
        case .options:
            return "Настр."
        case .settings:
            return "Опции"
        case .gallery:
            return "Меню"
        case .editor:
            return "Меню"
        case .themes:
            return "Меню"
        }
    }

    private func leftSoftKeyAction() {
        switch currentScreen {
        case .camera:
            currentScreen = .options
        default:
            currentScreen = .camera
        }
    }

    private func centerSoftKeyAction() {
        switch currentScreen {
        case .camera:
            if captureMode == .photo {
                camera.takePhoto()
            } else {
                camera.toggleRecording()
            }

        case .cameraSelector:
            currentScreen = .camera

        case .options, .settings:
            currentScreen = .camera

        case .gallery:
            if gallerySelectedAssetID != nil {
                galleryViewerPresented = true
            }

        case .editor:
            break

        case .themes:
            break
        }
    }

    private func rightSoftKeyAction() {
        switch currentScreen {
        case .camera:
            currentScreen = .settings
        case .cameraSelector:
            currentScreen = .camera
        case .options:
            currentScreen = .settings
        case .settings:
            currentScreen = .options
        case .gallery, .editor, .themes:
            currentScreen = .settings
        }
    }

    private func cycleCaptureMode() {
        guard !camera.isRecording else { return }
        captureMode = captureMode == .photo ? .video : .photo
    }

    private func cycleFPS() {
        let values = [24, 30, 60]
        guard let index = values.firstIndex(of: camera.selectedPreviewFPS) else {
            camera.updatePreviewFPS(30)
            return
        }
        let next = values[(index + 1) % values.count]
        camera.updatePreviewFPS(next)
    }

    private func cycleAspect() {
        let all = CaptureAspect.allCases
        guard let index = all.firstIndex(of: camera.captureAspect) else {
            if let first = all.first {
                camera.updateCaptureAspect(first)
            }
            return
        }
        let next = all[(index + 1) % all.count]
        camera.updateCaptureAspect(next)
    }

    private func cycleFlash() {
        let all = PhotoFlashMode.allCases
        guard let index = all.firstIndex(of: camera.photoFlashMode) else {
            if let first = all.first {
                camera.updateFlashMode(first)
            }
            return
        }
        let next = all[(index + 1) % all.count]
        camera.updateFlashMode(next)
    }
}

enum LegacyPalette {
    static let shellOuter = Color(red: 0.08, green: 0.09, blue: 0.10)
    static let shellTop = Color(red: 0.23, green: 0.25, blue: 0.27)
    static let shellBottom = Color(red: 0.11, green: 0.12, blue: 0.13)

    static let shellInner = Color(red: 0.54, green: 0.58, blue: 0.49)
    static let shellEdge = Color(red: 0.32, green: 0.35, blue: 0.30)

    static let panel = Color(red: 0.79, green: 0.84, blue: 0.72)
    static let panelAlt = Color(red: 0.73, green: 0.79, blue: 0.66)
    static let panelInset = Color(red: 0.86, green: 0.90, blue: 0.80)

    static let previewFrame = Color(red: 0.33, green: 0.35, blue: 0.32)
    static let previewInset = Color(red: 0.13, green: 0.14, blue: 0.13)
    static let frameBorder = Color(red: 0.18, green: 0.19, blue: 0.18)

    static let ink = Color.black
    static let soft = Color.black.opacity(0.08)
    static let softStrong = Color.black.opacity(0.14)
    static let active = Color.black
    static let activeText = Color.white

    static let previewBadge = Color(red: 0.79, green: 0.92, blue: 0.74)
    static let previewText = Color(red: 0.84, green: 0.95, blue: 0.80)
}

struct LegacyShell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [LegacyPalette.shellTop, LegacyPalette.shellBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                content
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LegacyPalette.shellInner)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(LegacyPalette.shellEdge, lineWidth: 4)
            )
            .padding(8)
        }
    }
}

struct LegacyHeaderBar: View {
    let title: String
    let status: String

    var body: some View {
        HStack(spacing: 8) {
            Text("0.3MP")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))

            Spacer()

            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Text(status)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
        }
        .foregroundStyle(LegacyPalette.ink)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            LinearGradient(
                colors: [LegacyPalette.panelInset, LegacyPalette.panelAlt],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.bottom, 8)
    }
}

struct LegacyScreenPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LegacyPalette.panelAlt)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LegacyPalette.panel)
                    .padding(6)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LegacyPalette.panelInset)
                    .padding(12)

                content
                    .padding(20)
            }
        }
    }
}

struct LegacySectionTitle: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.black.opacity(0.25))
                .frame(width: 10, height: 2)

            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .monospaced))

            Rectangle()
                .fill(Color.black.opacity(0.25))
                .frame(height: 2)
        }
        .foregroundStyle(LegacyPalette.ink.opacity(0.82))
    }
}

struct LegacyCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(12)
        .background(LegacyPalette.soft)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .tint(.black)
    }
}

struct LegacyMenuRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .black.opacity(0.62))
                    }
                }

                Spacer()

                Text(isSelected ? "OK" : ">")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .frame(width: 26)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(isSelected ? LegacyPalette.active : LegacyPalette.soft)
            .foregroundStyle(isSelected ? LegacyPalette.activeText : LegacyPalette.ink)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.black.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct LegacyValueTile: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(LegacyPalette.soft)
            .foregroundStyle(LegacyPalette.ink)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct LegacyToggleTile: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    Text(isOn ? "ON" : "OFF")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }

                Spacer()

                Circle()
                    .fill(isOn ? Color.white : Color.black.opacity(0.15))
                    .frame(width: 12, height: 12)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isOn ? LegacyPalette.active : LegacyPalette.soft)
            .foregroundStyle(isOn ? LegacyPalette.activeText : LegacyPalette.ink)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isOn ? Color.clear : Color.black.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct LegacyInfoBadge: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(LegacyPalette.previewBadge)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct LegacyActionButtonLabel: View {
    let titleTop: String
    let titleBottom: String
    let dark: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(titleTop)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
            Text(titleBottom)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .lineLimit(1)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(dark ? LegacyPalette.active : LegacyPalette.soft)
        .foregroundStyle(dark ? LegacyPalette.activeText : LegacyPalette.ink)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(dark ? Color.clear : Color.black.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct LegacySoftKeyBar: View {
    let leftTitle: String
    let centerTitle: String
    let rightTitle: String
    let leftAction: () -> Void
    let centerAction: () -> Void
    let rightAction: () -> Void

    var body: some View {
        HStack {
            Button(action: leftAction) {
                Text(leftTitle)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button(action: centerAction) {
                Text(centerTitle)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button(action: rightAction) {
                Text(rightTitle)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.top, 8)
    }
}

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
            return "Проверь разрешение Photo Library и строку доступа в Info.plist"
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
                ProgressView().tint(.black)
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

                    Text("Проверь разрешение Photo Library и строку доступа в Info.plist.")
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
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                        ProgressView().tint(.black)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: asset.mediaType == .video ? "video.fill" : "photo.fill")
                            .font(.system(size: 10, weight: .bold))

                        Text(assetLabel)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.72))
                    .foregroundStyle(LegacyPalette.previewBadge)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .padding(6)
                }

                if isSelected {
                    Text("OK")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(6)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.black : Color.black.opacity(0.15), lineWidth: isSelected ? 3 : 1)
            )
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
                        ProgressView().tint(.white)
                    } else if asset.mediaType == .video, let player {
                        VideoPlayer(player: player)
                            .onAppear { player.play() }
                            .onDisappear { player.pause() }
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
        .onAppear { load() }
        .onDisappear { player?.pause() }
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
