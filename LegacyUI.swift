import SwiftUI

enum LegacyPalette {
    static let shellOuter = Color.black
    static let shellInner = Color(red: 0.77, green: 0.83, blue: 0.71)
    static let panel = Color(red: 0.87, green: 0.91, blue: 0.82)
    static let panelAlt = Color(red: 0.80, green: 0.86, blue: 0.74)
    static let ink = Color.black
    static let soft = Color.black.opacity(0.08)
    static let softStrong = Color.black.opacity(0.14)
    static let active = Color.black
    static let activeText = Color.white
    static let previewBadge = Color(red: 0.80, green: 0.90, blue: 0.78)
}

struct LegacyShell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LegacyPalette.shellOuter.ignoresSafeArea()

            VStack(spacing: 0) {
                content
            }
            .background(LegacyPalette.shellInner)
        }
    }
}

struct LegacyHeaderBar: View {
    let title: String
    let status: String

    var body: some View {
        HStack(spacing: 10) {
            Text("0.3MP CAM")
                .font(.system(size: 14, weight: .bold, design: .monospaced))

            Spacer()

            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Text(status)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(LegacyPalette.ink)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            LinearGradient(
                colors: [LegacyPalette.panel, LegacyPalette.panelAlt],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 1)
        }
    }
}

struct LegacyScreenPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { _ in
            ZStack {
                LegacyPalette.shellInner

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LegacyPalette.panel)
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
        Text(title.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundStyle(LegacyPalette.ink.opacity(0.78))
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
                            .foregroundStyle(isSelected ? .white.opacity(0.85) : .black.opacity(0.65))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(isSelected ? LegacyPalette.active : LegacyPalette.soft)
            .foregroundStyle(isSelected ? LegacyPalette.activeText : LegacyPalette.ink)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .font(.system(size: 11, weight: .bold))
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(LegacyPalette.soft)
            .foregroundStyle(LegacyPalette.ink)
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
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                Text(isOn ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isOn ? LegacyPalette.active : LegacyPalette.soft)
            .foregroundStyle(isOn ? LegacyPalette.activeText : LegacyPalette.ink)
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
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            Text(value)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(LegacyPalette.previewBadge)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button(action: centerAction) {
                Text(centerTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button(action: rightAction) {
                Text(rightTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(Color.black)
    }
}
