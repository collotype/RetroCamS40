import SwiftUI
import AVFoundation

struct ContentView: View {
    enum Screen: String, CaseIterable, Identifiable {
        case camera = "Камера"
        case gallery = "Галерея"
        case editor = "Редактор"
        case themes = "Темы"
        case settings = "Настройки"

        var id: String { rawValue }
    }

    enum CaptureMode: String, CaseIterable, Identifiable {
        case photo = "Фото"
        case video = "Видео"

        var id: String { rawValue }
    }

    @StateObject private var camera = CameraService()

    @State private var currentScreen: Screen = .camera
    @State private var captureMode: CaptureMode = .photo

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topStatusBar
                mainPhoneArea
                bottomSoftKeys
            }
        }
        .onAppear { camera.startIfNeeded() }
        .onDisappear { camera.stop() }
    }

    // MARK: - Top

    private var topStatusBar: some View {
        HStack(spacing: 10) {
            Text("0.3MP CAM")
                .font(.system(size: 14, weight: .bold, design: .monospaced))

            Spacer()

            Text(currentScreen.rawValue.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Text(captureMode == .video && camera.isRecording ? "REC" : "READY")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.87, blue: 0.74),
                    Color(red: 0.69, green: 0.75, blue: 0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.2))
                .frame(height: 1)
        }
    }

    // MARK: - Body

    private var mainPhoneArea: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.78, green: 0.84, blue: 0.72)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.87, green: 0.91, blue: 0.82))
                    .padding(12)

                screenContent(in: geo.size)
                    .padding(20)
            }
        }
    }

    @ViewBuilder
    private func screenContent(in size: CGSize) -> some View {
        switch currentScreen {
        case .camera:
            cameraScreen(size: size)

        case .gallery:
            placeholderScreen(
                title: "Галерея",
                lines: [
                    "Тут будет встроенная медиатека приложения.",
                    "Без внешних переходов.",
                    "Следующим сообщением дам готовый экран галереи."
                ]
            )

        case .editor:
            placeholderScreen(
                title: "Редактор",
                lines: [
                    "Тут будет редактор фото из старой логики.",
                    "Без поддержки и без ссылок наружу."
                ]
            )

        case .themes:
            placeholderScreen(
                title: "Темы",
                lines: [
                    "Тут будет экран тем/скинов.",
                    "Пока только внутри приложения."
                ]
            )

        case .settings:
            settingsScreen
        }
    }

    // MARK: - Camera

    private func cameraScreen(size: CGSize) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                retroTabButton("Камера", isSelected: true) {}
                retroTabButton("Галерея", isSelected: false) { currentScreen = .gallery }
                retroTabButton("Темы", isSelected: false) { currentScreen = .themes }
            }

            VStack(spacing: 10) {
                previewBlock
                    .frame(maxWidth: .infinity)
                    .frame(height: size.height * 0.42)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.25), lineWidth: 2)
                    )

                captureModeRow
                presetRow
                quickSettingsRow
                shutterRow
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
                infoBadge("MODEL", camera.selectedPreset.title)
                infoBadge("MODE", captureMode.rawValue)
                if captureMode == .video && camera.isRecording {
                    infoBadge("STATE", "REC")
                }
            }
            .padding(8)
        }
    }

    private func infoBadge(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            Text(value)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(Color(red: 0.80, green: 0.90, blue: 0.78))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var captureModeRow: some View {
        HStack(spacing: 8) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    guard !camera.isRecording else { return }
                    captureMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(captureMode == mode ? Color.black : Color.black.opacity(0.08))
                        .foregroundStyle(captureMode == mode ? .white : .black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(camera.isRecording)
            }
        }
    }

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RetroPreset.allCases) { preset in
                    Button {
                        camera.selectedPreset = preset
                    } label: {
                        VStack(spacing: 4) {
                            Text(preset.shortTitle)
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)

                            if camera.selectedPreset == preset {
                                Text("выбрано")
                                    .font(.system(size: 9, weight: .medium))
                            }
                        }
                        .foregroundStyle(camera.selectedPreset == preset ? .white : .black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(camera.selectedPreset == preset ? Color.black : Color.black.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var quickSettingsRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                toggleTile(
                    title: "Retro",
                    isOn: $camera.useRetroFilter
                )

                toggleTile(
                    title: "Дата",
                    isOn: $camera.addDateStamp
                )
            }

            HStack(spacing: 8) {
                retroValueTile(title: "FPS", value: "\(camera.selectedPreviewFPS)") {
                    cycleFPS()
                }

                retroValueTile(title: "Формат", value: camera.captureAspect.title) {
                    cycleAspect()
                }

                if captureMode == .photo {
                    retroValueTile(title: "Flash", value: camera.photoFlashMode.title) {
                        cycleFlashMode()
                    }
                } else {
                    retroValueTile(title: "Видео", value: camera.isRecording ? "REC" : "READY") {
                        // без действия
                    }
                }
            }
        }
    }

    private var shutterRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    camera.switchCamera()
                } label: {
                    Text("Сменить\nкамеру")
                        .font(.system(size: 12, weight: .bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black.opacity(0.08))
                        .foregroundStyle(.black)
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
                    Text(captureMode == .video
                         ? (camera.isRecording ? "СТОП" : "ЗАПИСЬ")
                         : "СНЯТЬ")
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
                        .background(Color.black.opacity(0.08))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Settings

    private var settingsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Настройки камеры")

                settingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Retro-эффект", isOn: $camera.useRetroFilter)
                        Toggle("Штамп даты", isOn: $camera.addDateStamp)
                    }
                }

                sectionTitle("Режим предпросмотра")

                settingCard {
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
                    sectionTitle("Фото")

                    settingCard {
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

                sectionTitle("Оптика")

                settingCard {
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

                settingCard {
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

                sectionTitle("Важно")

                settingCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("В этой версии нет кнопок поддержки, Telegram, Review, внешних URL и любых выходов из приложения.")
                            .font(.system(size: 13, weight: .medium))
                        Text("Всё управление остаётся внутри приложения.")
                            .font(.system(size: 12))
                            .foregroundStyle(.black.opacity(0.75))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Shared UI

    private func retroTabButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.black : Color.black.opacity(0.08))
                .foregroundStyle(isSelected ? .white : .black)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func toggleTile(title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                Text(isOn.wrappedValue ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isOn.wrappedValue ? Color.black : Color.black.opacity(0.08))
            .foregroundStyle(isOn.wrappedValue ? .white : .black)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func retroValueTile(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.08))
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundStyle(.black.opacity(0.8))
    }

    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(12)
        .background(Color.black.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .tint(.black)
    }

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

    // MARK: - Bottom keys

    private var bottomSoftKeys: some View {
        HStack {
            Button {
                switch currentScreen {
                case .camera:
                    currentScreen = .gallery
                case .gallery, .editor, .themes, .settings:
                    currentScreen = .camera
                }
            } label: {
                Text(leftSoftKeyTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                centerSoftKeyAction()
            } label: {
                Text(centerSoftKeyTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                currentScreen = .settings
            } label: {
                Text("Меню")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(Color.black)
    }

    private var leftSoftKeyTitle: String {
        switch currentScreen {
        case .camera:
            return "Галерея"
        case .gallery, .editor, .themes, .settings:
            return "Назад"
        }
    }

    private var centerSoftKeyTitle: String {
        switch currentScreen {
        case .camera:
            return captureMode == .photo
            ? "Снять"
            : (camera.isRecording ? "Стоп" : "Rec")
        case .gallery:
            return "Открыть"
        case .editor:
            return "Применить"
        case .themes:
            return "Выбрать"
        case .settings:
            return "Камера"
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

        case .gallery:
            break

        case .editor:
            break

        case .themes:
            break

        case .settings:
            currentScreen = .camera
        }
    }

    // MARK: - Small cyclers

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

    private func cycleFlashMode() {
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
