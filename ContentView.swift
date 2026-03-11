import SwiftUI
import AVFoundation

struct ContentView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case photo = "Фото"
        case video = "Видео"
        var id: String { rawValue }
    }

    @StateObject private var camera = CameraService()
    @State private var mode: Mode = .photo
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    previewArea

                    if showSettings {
                        settingsPanel
                            .padding(.top, 16)
                            .padding(.trailing, 12)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }

                controls
                    .padding(.vertical, 14)
                    .background(.black.opacity(0.92))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSettings)
        .onAppear { camera.startIfNeeded() }
        .onDisappear { camera.stop() }
    }

    @ViewBuilder
    private var previewArea: some View {
        if camera.captureAspect == .fourThree && mode == .photo {
            ZStack(alignment: .topLeading) {
                Color.black
                previewContent
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                topLeftInfo
            }
        } else {
            ZStack(alignment: .topLeading) {
                previewContent
                topLeftInfo
            }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
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
                .ignoresSafeArea(edges: .top)
        }
    }

    private var topLeftInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RetroCam")
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.5))
                .cornerRadius(8)

            Text(camera.selectedPreset.title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.5))
                .cornerRadius(8)

            if mode == .video && camera.isRecording {
                Text("REC")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5))
                    .cornerRadius(8)
            }
        }
        .padding(.top, 16)
        .padding(.leading, 12)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Режим", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .disabled(camera.isRecording)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RetroPreset.allCases) { preset in
                        Button {
                            camera.selectedPreset = preset
                        } label: {
                            Text(preset.shortTitle)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(camera.selectedPreset == preset ? .white.opacity(0.25) : .white.opacity(0.10))
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
            }

            HStack(spacing: 18) {
                Button {
                    camera.switchCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .disabled(camera.isRecording)

                Spacer()

                Button {
                    if mode == .photo {
                        camera.takePhoto()
                    } else {
                        camera.toggleRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 78, height: 78)

                        if mode == .video && camera.isRecording {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.red)
                                .frame(width: 34, height: 34)
                        } else {
                            Circle()
                                .fill(mode == .video ? .red : .white)
                                .frame(width: 62, height: 62)
                        }
                    }
                }

                Spacer()

                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(showSettings ? 0.25 : 0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Настройки")
                    .font(.headline)
                    .foregroundStyle(.white)

                Toggle("Retro-эффект", isOn: $camera.useRetroFilter)
                    .foregroundStyle(.white)

                Toggle("Штамп даты", isOn: $camera.addDateStamp)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 8) {
                    Text("FPS")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))

                    Picker("FPS", selection: Binding(
                        get: { camera.selectedPreviewFPS },
                        set: { camera.updatePreviewFPS($0) }
                    )) {
                        Text("24").tag(24)
                        Text("30").tag(30)
                        Text("60").tag(60)
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Формат фото")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))

                    Picker("Формат", selection: Binding(
                        get: { camera.captureAspect },
                        set: { camera.updateCaptureAspect($0) }
                    )) {
                        ForEach(CaptureAspect.allCases) { aspect in
                            Text(aspect.title).tag(aspect)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .photo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Вспышка")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))

                        Picker("Вспышка", selection: Binding(
                            get: { camera.photoFlashMode },
                            set: { camera.updateFlashMode($0) }
                        )) {
                            ForEach(PhotoFlashMode.allCases) { flash in
                                Text(flash.title).tag(flash)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Зум")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        Text(String(format: "%.1fx", camera.zoomFactor))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Slider(
                        value: Binding(
                            get: { camera.zoomFactor },
                            set: { camera.updateZoom($0) }
                        ),
                        in: 1...6
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Ручной фокус", isOn: Binding(
                        get: { camera.manualFocusEnabled },
                        set: { camera.updateManualFocusEnabled($0) }
                    ))
                    .foregroundStyle(.white)

                    if camera.manualFocusEnabled {
                        Slider(
                            value: Binding(
                                get: { Double(camera.focusPosition) },
                                set: { camera.updateFocusPosition(Float($0)) }
                            ),
                            in: 0...1
                        )

                        HStack {
                            Text("Близко")
                            Spacer()
                            Text("Далеко")
                        }
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Ручная экспозиция", isOn: Binding(
                        get: { camera.manualExposureEnabled },
                        set: { camera.updateManualExposureEnabled($0) }
                    ))
                    .foregroundStyle(.white)

                    if camera.manualExposureEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ISO")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))

                            Slider(
                                value: Binding(
                                    get: { Double(camera.manualISOValue) },
                                    set: { camera.updateManualISOValue(Float($0)) }
                                ),
                                in: 0...1
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Выдержка")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))

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
            .padding(14)
        }
        .frame(width: 280, height: 380)
        .background(.black.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}
