import SwiftUI
import AVFoundation
import Photos
import AVKit

struct ContentView: View {
    enum Screen: String {
        case camera = "Камера"
        case cameraSelector = "Выбор камеры"
        case options = "Опции"
        case settings = "Настройки"
        case gallery = "Галерея"
        case editor = "Редактор"
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
        ZStack {
            LegacyPalette.outer.ignoresSafeArea()

            VStack(spacing: 0) {
                topHeader
                phoneBody
                softKeyBar
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LegacyPalette.shell)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(LegacyPalette.shellStroke, lineWidth: 4)
            )
            .padding(8)
        }
        .onAppear { camera.startIfNeeded() }
        .onDisappear { camera.stop() }
    }

    private var topHeader: some View {
        HStack(spacing: 8) {
            Text("0.3MP")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))

            Spacer()

            Text(currentScreen.rawValue.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Text(headerStatus)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            LinearGradient(
                colors: [LegacyPalette.lcdBright, LegacyPalette.lcdMid],
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

    private var phoneBody: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LegacyPalette.panelOuter)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LegacyPalette.panelMid)
                    .padding(6)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LegacyPalette.panelInner)
                    .padding(12)

                screenBody
                    .padding(18)
            }
        }
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
            editorPlaceholder
        }
    }

    private var headerStatus: String {
        if captureMode == .video && camera.isRecording {
            return "REC"
        }
        return "READY"
    }

    private var cameraScreen: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                topMiniTab("CAM", active: true) { }
                topMiniTab("OPT", active: false) { currentScreen = .options }
                topMiniTab("GAL", active: false) { currentScreen = .gallery }
                topMiniTab("SET", active: false) { currentScreen = .settings }
            }

            previewBlock
                .frame(maxWidth: .infinity)
                .frame(height: 300)

            HStack(spacing: 8) {
                infoCell(title: "MODE", value: captureMode.rawValue) {
                    guard !camera.isRecording else { return }
                    cycleCaptureMode()
                }

                infoCell(title: "CAM", value: camera.selectedPreset.shortTitle) {
                    currentScreen = .cameraSelector
                }

                infoCell(title: "FPS", value: "\(camera.selectedPreviewFPS)") {
                    cycleFPS()
                }
            }

            HStack(spacing: 8) {
                toggleCell(title: "RETRO", isOn: $camera.useRetroFilter)
                toggleCell(title: "DATE", isOn: $camera.addDateStamp)

                if captureMode == .photo {
                    infoCell(title: "FLASH", value: camera.photoFlashMode.title) {
                        cycleFlash()
                    }
                } else {
                    infoCell(title: "VIDEO", value: camera.isRecording ? "REC" : "READY") { }
                }
            }

            HStack(spacing: 8) {
                infoCell(title: "ASPECT", value: camera.captureAspect.title) {
                    cycleAspect()
                }

                infoCell(title: "ZOOM", value: String(format: "%.1fx", camera.zoomFactor)) {
                    currentScreen = .settings
                }

                infoCell(title: "MENU", value: "OPEN") {
                    currentScreen = .options
                }
            }

            HStack(spacing: 8) {
                Button {
                    camera.switchCamera()
                } label: {
                    actionButtonLabel(
                        top: "SWITCH",
                        bottom: "CAMERA",
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
                    actionButtonLabel(
                        top: captureMode == .video ? (camera.isRecording ? "STOP" : "REC") : "SHOT",
                        bottom: captureMode == .video ? "VIDEO" : "PHOTO",
                        dark: true
                    )
                }
                .buttonStyle(.plain)

                Button {
                    currentScreen = .settings
                } label: {
                    actionButtonLabel(
                        top: "FULL",
                        bottom: "SETTINGS",
                        dark: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var previewBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LegacyPalette.previewFrame)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LegacyPalette.previewInset)
                .padding(6)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.black)
                .padding(10)

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
                    .padding(10)
                } else {
                    CameraPreview(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(10)
                }

                VStack(alignment: .leading, spacing: 5) {
                    previewBadge("MODEL", camera.selectedPreset.title)
                    previewBadge("MODE", captureMode.rawValue.uppercased())
                    previewBadge("FPS", "\(camera.selectedPreviewFPS)")
                    previewBadge("SIZE", camera.captureAspect.title.uppercased())

                    if captureMode == .video && camera.isRecording {
                        previewBadge("STATE", "REC")
                    }
                }
                .padding(16)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("0.3MP CAM")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(LegacyPalette.previewText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.70))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(16)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LegacyPalette.previewStroke, lineWidth: 3)
        )
    }

    private var cameraSelectorScreen: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Выбор камеры")

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(RetroPreset.allCases) { preset in
                        menuRow(
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
            return "1.3MP жёсткая обработка"
        case .n73:
            return "Более чистая 3.2MP картинка"
        }
    }

    private var optionsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Быстрые опции")

                card {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            infoCell(title: "MODE", value: captureMode.rawValue) {
                                guard !camera.isRecording else { return }
                                cycleCaptureMode()
                            }

                            infoCell(title: "FPS", value: "\(camera.selectedPreviewFPS)") {
                                cycleFPS()
                            }

                            infoCell(title: "ASPECT", value: camera.captureAspect.title) {
                                cycleAspect()
                            }
                        }

                        HStack(spacing: 8) {
                            toggleCell(title: "RETRO", isOn: $camera.useRetroFilter)
                            toggleCell(title: "DATE", isOn: $camera.addDateStamp)

                            if captureMode == .photo {
                                infoCell(title: "FLASH", value: camera.photoFlashMode.title) {
                                    cycleFlash()
                                }
                            } else {
                                infoCell(title: "VIDEO", value: camera.isRecording ? "REC" : "READY") { }
                            }
                        }
                    }
                }

                sectionTitle("Меню")

                VStack(spacing: 8) {
                    menuRow(title: "Выбор камеры", subtitle: "Список профилей") {
                        currentScreen = .cameraSelector
                    }

                    menuRow(title: "Полные настройки", subtitle: "Оптика и экспозиция") {
                        currentScreen = .settings
                    }

                    menuRow(title: "Галерея", subtitle: "Фото и видео внутри приложения") {
                        currentScreen = .gallery
                    }

                    menuRow(title: "Редактор", subtitle: "Заглушка под старую логику") {
                        currentScreen = .editor
                    }
                }
            }
        }
    }

    private var settingsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Режим съёмки")

                card {
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
                    sectionTitle("Фото")

                    card {
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

                sectionTitle("Оптика")

                card {
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

                sectionTitle("Экспозиция")

                card {
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

    private var editorPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Редактор")

            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Пока заглушка.")
                        .font(.system(size: 15, weight: .bold))

                    Text("Потом сюда можно перенести старую логику редактирования фото.")
                        .font(.system(size: 13, weight: .medium))
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
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.black)
    }

    private var softKeyBar: some View {
        HStack {
            Button {
                leftSoftKeyAction()
            } label: {
                Text(leftSoftKeyTitle)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                centerSoftKeyAction()
            } label: {
                Text(centerSoftKeyTitle)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                rightSoftKeyAction()
            } label: {
                Text(rightSoftKeyTitle)
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

    private var leftSoftKeyTitle: String {
        switch currentScreen {
        case .camera:
            return "Галерея"
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
            return "Камера"
        }
    }

    private var rightSoftKeyTitle: String {
        switch currentScreen {
        case .camera:
            return "Меню"
        case .cameraSelector:
            return "Опции"
        case .options:
            return "Настр."
        case .settings:
            return "Опции"
        case .gallery:
            return "Меню"
        case .editor:
            return "Меню"
        }
    }

    private func leftSoftKeyAction() {
        switch currentScreen {
        case .camera:
            currentScreen = .gallery
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

        case .options, .settings, .editor:
            currentScreen = .camera

        case .gallery:
            if gallerySelectedAssetID != nil {
                galleryViewerPresented = true
            }
        }
    }

    private func rightSoftKeyAction() {
        switch currentScreen {
        case .camera:
            currentScreen = .options
        case .cameraSelector:
            currentScreen = .options
        case .options:
            currentScreen = .settings
        case .settings:
            currentScreen = .options
        case .gallery:
            currentScreen = .options
        case .editor:
            currentScreen = .options
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

    private func sectionTitle(_ text: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.black.opacity(0.25))
                .frame(width: 10, height: 2)

            Text(text.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .monospaced))

            Rectangle()
                .fill(Color.black.opacity(0.25))
                .frame(height: 2)
        }
        .foregroundStyle(Color.black.opacity(0.82))
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(12)
        .background(LegacyPalette.card)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .tint(.black)
    }

    private func menuRow(
        title: String,
        subtitle: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : .black.opacity(0.62))
                }

                Spacer()

                Text(isSelected ? "OK" : ">")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .frame(width: 24)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(isSelected ? Color.black : LegacyPalette.card)
            .foregroundStyle(isSelected ? .white : .black)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.black.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func infoCell(title: String, value: String, action: @escaping () -> Void) -> some View {
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
            .background(LegacyPalette.card)
            .foregroundStyle(.black)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func toggleCell(title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    Text(isOn.wrappedValue ? "ON" : "OFF")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }

                Spacer()

                Circle()
                    .fill(isOn.wrappedValue ? Color.white : Color.black.opacity(0.15))
                    .frame(width: 12, height: 12)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isOn.wrappedValue ? Color.black : LegacyPalette.card)
            .foregroundStyle(isOn.wrappedValue ? .white : .black)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isOn.wrappedValue ? Color.clear : Color.black.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func previewBadge(_ title: String, _ value: String) -> some View {
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

    private func topMiniTab(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(active ? Color.black : LegacyPalette.card)
                .foregroundStyle(active ? .white : .black)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(active ? Color.clear : Color.black.opacity(0.10), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func actionButtonLabel(top: String, bottom: String, dark: Bool) -> some View {
        VStack(spacing: 3) {
            Text(top)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
            Text(bottom)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .lineLimit(1)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(dark ? Color.black : LegacyPalette.card)
        .foregroundStyle(dark ? .white : .black)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(dark ? Color.clear : Color.black.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

enum LegacyPalette {
    static let outer = Color(red: 0.08, green: 0.09, blue: 0.10)

    static let shell = Color(red: 0.50, green: 0.55, blue: 0.46)
    static let shellStroke = Color(red: 0.30, green: 0.33, blue: 0.28)

    static let panelOuter = Color(red: 0.71, green: 0.77, blue: 0.65)
    static let panelMid = Color(red: 0.79, green: 0.84, blue: 0.72)
    static let panelInner = Color(red: 0.87, green: 0.91, blue: 0.82)
    static let card = Color.black.opacity(0.08)

    static let lcdBright = Color(red: 0.89, green: 0.94, blue: 0.82)
    static let lcdMid = Color(red: 0.76, green: 0.83, blue: 0.69)

    static let previewFrame = Color(red: 0.33, green: 0.35, blue: 0.32)
    static let previewInset = Color(red: 0.13, green: 0.14, blue: 0.13)
    static let previewStroke = Color(red: 0.18, green: 0.19, blue: 0.18)

    static let previewBadge = Color(red: 0.80, green: 0.92, blue: 0.76)
    static let previewText = Color(red: 0.86, green: 0.96, blue: 0.83)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 10, height: 2)

                Text("ГАЛЕРЕЯ")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))

                Rectangle()
                    .fill(Color.black.opacity(0.25))
                    .frame(height: 2)
            }
            .foregroundStyle(Color.black.opacity(0.82))

            galleryHeader
            galleryContent
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

    private var galleryHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                        .background(Color.black.opacity(0.12))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            return "Загрузка последних фото и видео"
        case .denied:
            return "Проверь доступ к Photo Library"
        case .limited:
            return selectedAssetID == nil ? "Ограниченный доступ" : "Файл выбран"
        case .authorized:
            return selectedAssetID == nil ? "Ничего не выбрано" : "Можно открыть просмотр"
        }
    }

    @ViewBuilder
    private var galleryContent: some View {
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
            VStack(alignment: .leading, spacing: 10) {
                Text("Доступ к галерее выключен.")
                    .font(.system(size: 16, weight: .bold))

                Text("Нужен доступ к Photo Library и строка NSPhotoLibraryUsageDescription в Info.plist.")
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
            .padding(12)
            .background(Color.black.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.14), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

        case .authorized, .limited:
            if model.assets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Пока пусто")
                        .font(.system(size: 16, weight: .bold))
                    Text("Сделай фото или видео, затем вернись сюда.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.75))
                }
                .padding(12)
                .background(Color.black.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.14), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        .fill(Color.black.opacity(0.14))

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
                    .foregroundStyle(Color(red: 0.80, green: 0.92, blue: 0.76))
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
