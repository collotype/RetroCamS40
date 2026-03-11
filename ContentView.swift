import SwiftUI
import AVFoundation

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

    // MARK: - Header

    private var headerStatus: String {
        if captureMode == .video && camera.isRecording {
            return "REC"
        }
        return "READY"
    }

    // MARK: - Screen switch

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

    // MARK: - Camera

    private var cameraScreen: some View {
        VStack(spacing: 12) {
            previewBlock
                .frame(maxWidth: .infinity)
                .frame(height: 310)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.22), lineWidth: 2)
                )

            HStack(spacing: 8) {
                LegacyValueTile(title: "Режим", value: captureMode.rawValue) {
                    guard !camera.isRecording else { return }
                    cycleCaptureMode()
                }

                LegacyValueTile(title: "Профиль", value: camera.selectedPreset.shortTitle) {
                    currentScreen = .cameraSelector
                }

                LegacyValueTile(title: "Опции", value: "Открыть") {
                    currentScreen = .options
                }
            }

            HStack(spacing: 8) {
                LegacyToggleTile(title: "Retro", isOn: $camera.useRetroFilter)
                LegacyToggleTile(title: "Дата", isOn: $camera.addDateStamp)
            }

            HStack(spacing: 10) {
                Button {
                    camera.switchCamera()
                } label: {
                    Text("Сменить\nкамеру")
                        .font(.system(size: 12, weight: .bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LegacyPalette.soft)
                        .foregroundStyle(LegacyPalette.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    Text(captureMode == .video ? (camera.isRecording ? "СТОП" : "ЗАПИСЬ") : "СНЯТЬ")
                        .font(.system(size: 18, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    currentScreen = .settings
                } label: {
                    Text("Все\nнастройки")
                        .font(.system(size: 12, weight: .bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LegacyPalette.soft)
                        .foregroundStyle(LegacyPalette.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var previewBlock: some View {
        ZStack(alignment: .topLeading) {
            Color.black

            if let previewImage = camera.previewImage {
                GeometryReader { geo in
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            } else {
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                LegacyInfoBadge(title: "MODEL", value: camera.selectedPreset.title)
                LegacyInfoBadge(title: "MODE", value: captureMode.rawValue)
                LegacyInfoBadge(title: "FPS", value: "\(camera.selectedPreviewFPS)")
                if captureMode == .video && camera.isRecording {
                    LegacyInfoBadge(title: "STATE", value: "REC")
                }
            }
            .padding(8)
        }
    }

    // MARK: - Camera selector

    private var cameraSelectorScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            LegacySectionTitle(title: "Выбор камеры")

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(RetroPreset.allCases) { preset in
                        LegacyMenuRow(
                            title: preset.title,
                            subtitle: cameraProfileSubtitle(for: preset),
                            isSelected: camera.selectedPreset == preset
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

    // MARK: - Options

    private var optionsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LegacySectionTitle(title: "Быстрые опции")

                LegacyCard {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            LegacyValueTile(title: "Режим", value: captureMode.rawValue) {
                                guard !camera.isRecording else { return }
                                cycleCaptureMode()
                            }

                            LegacyValueTile(title: "FPS", value: "\(camera.selectedPreviewFPS)") {
                                cycleFPS()
                            }

                            LegacyValueTile(title: "Формат", value: camera.captureAspect.title) {
                                cycleAspect()
                            }
                        }

                        HStack(spacing: 8) {
                            LegacyToggleTile(title: "Retro", isOn: $camera.useRetroFilter)
                            LegacyToggleTile(title: "Дата", isOn: $camera.addDateStamp)
                        }

                        if captureMode == .photo {
                            HStack(spacing: 8) {
                                LegacyValueTile(title: "Flash", value: camera.photoFlashMode.title) {
                                    cycleFlash()
                                }

                                LegacyValueTile(title: "Профиль", value: camera.selectedPreset.shortTitle) {
                                    currentScreen = .cameraSelector
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                LegacyValueTile(title: "Видео", value: camera.isRecording ? "REC" : "READY") { }
                                LegacyValueTile(title: "Профиль", value: camera.selectedPreset.shortTitle) {
                                    currentScreen = .cameraSelector
                                }
                            }
                        }
                    }
                }

                LegacySectionTitle(title: "Переходы")

                VStack(spacing: 10) {
                    LegacyMenuRow(title: "Выбор камеры", subtitle: "Список профилей") {
                        currentScreen = .cameraSelector
                    }

                    LegacyMenuRow(title: "Полные настройки", subtitle: "Оптика, экспозиция, формат") {
                        currentScreen = .settings
                    }

                    LegacyMenuRow(title: "Темы", subtitle: "Оформление оболочки") {
                        currentScreen = .themes
                    }
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LegacySectionTitle(title: "Режим съёмки")

                LegacyCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("FPS: \(camera.selectedPreviewFPS)")
                            .font(.system(size: 13, weight: .bold))
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
                            .font(.system(size: 13, weight: .bold))
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
                                .font(.system(size: 13, weight: .bold))
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

                LegacySectionTitle(title: "Принцип сборки")

                LegacyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Внутри приложения сейчас нет поддержки, Telegram, Review, Privacy Policy и любых внешних выходов.")
                            .font(.system(size: 13, weight: .medium))
                        Text("Сначала пересобираем логику старого приложения поверх твоей базы камеры.")
                            .font(.system(size: 12))
                            .foregroundStyle(.black.opacity(0.72))
                    }
                }
            }
        }
    }

    // MARK: - Themes

    private var themesScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LegacySectionTitle(title: "Темы")

                LegacyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Экран тем пока без импорта, но уже выделен как отдельный модуль.")
                            .font(.system(size: 14, weight: .bold))

                        Text("Следующим шагом сюда можно добавить список оболочек, превью и переключение стиля интерфейса.")
                            .font(.system(size: 13))
                    }
                }

                VStack(spacing: 10) {
                    LegacyMenuRow(title: "Classic Green", subtitle: "Базовая тема оболочки", isSelected: true) { }
                    LegacyMenuRow(title: "Dark Steel", subtitle: "Тёмная телефонная тема") { }
                    LegacyMenuRow(title: "Blue Menu", subtitle: "Псевдо Series 40") { }
                }
            }
        }
    }

    // MARK: - Placeholder

    private func placeholderScreen(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .heavy))

            ForEach(lines, id: \.self) { line in
                Text("• \(line)")
                    .font(.system(size: 15, weight: .medium))
            }

            Spacer()

            Button {
                currentScreen = .camera
            } label: {
                Text("Назад к камере")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.black)
    }

    // MARK: - Soft keys

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
            return "Открыть"
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

        case .gallery, .editor, .themes:
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

    // MARK: - Small helpers

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
