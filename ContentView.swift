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
                CameraPreview(session: camera.session)
                    .ignoresSafeArea(edges: .top)

                controls
                    .padding(.vertical, 14)
                    .background(.black.opacity(0.9))
            }
        }
        .onAppear { camera.startIfNeeded() }
        .onDisappear { camera.stop() }
    }

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Режим", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
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

                        Circle()
                            .fill(mode == .video && camera.isRecording ? .red : .white)
                            .frame(width: 62, height: 62)
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
        }
    }
}
