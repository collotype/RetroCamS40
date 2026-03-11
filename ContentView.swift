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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
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
                .overlay(alignment: .topLeading) {
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

                controls
                    .padding(.vertical, 14)
                    .background(.black.opacity(0.92))
            }
        }
        .onAppear { camera.startIfNeeded() }
        .onDisappear { camera.stop() }
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

            Picker("Пресет", selection: $camera.selectedPreset) {
                ForEach(RetroPreset.allCases) { preset in
                    Text(preset.shortTitle).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

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

                Menu {
                    Toggle("Retro-эффект", isOn: $camera.useRetroFilter)
                    Toggle("Штамп даты", isOn: $camera.addDateStamp)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 22)

            Text(mode == .photo ? "Фото" : "Видео")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
