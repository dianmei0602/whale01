import SwiftUI

/// 正在播放：iPhone 音乐资料库歌曲的黑胶界面。
///
/// 黑胶、唱臂、歌名、进度都是原生的；播放由 AVAudioPlayer 负责，
/// 锁屏也能显示歌名并用按钮控制。
struct VinylPlayerPage: View {

    @ObservedObject var player: MusicPlayer
    var onOpenLibrary: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var angle: Double = 0
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    private var track: MusicTrack? { player.current }

    private var shownTitle: String {
        guard let track else { return "没有在播" }
        return track.title
    }

    private var shownSubtitle: String {
        guard let track else { return "选一首开始" }
        if !track.artist.isEmpty { return track.artist }
        if !track.album.isEmpty { return track.album }
        return "本地音乐"
    }

    private var displayPosition: Double {
        isScrubbing ? scrubValue : player.position
    }

    private var fraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(displayPosition / player.duration, 0), 1)
    }

    var body: some View {
        ZStack {
            CardPalette.screen.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                Spacer(minLength: 4)

                vinyl

                trackInfo
                    .padding(.top, 20)

                progressBar
                    .padding(.top, 18)
                    .padding(.horizontal, 32)

                controls
                    .padding(.top, 16)

                Spacer(minLength: 10)

                queueBar
                    .padding(.horizontal, 18)

                Text(track == nil ? "" : "iPhone 音乐资料库 · 系统播放")
                    .font(.nomiScaled(size: 10.5))
                    .foregroundColor(CardPalette.subtle.opacity(0.85))
                    .padding(.top, 10)
                    .padding(.bottom, 16)
            }
        }
        .onAppear(perform: startSpinIfNeeded)
        .onChange(of: player.isPlaying) { _, playing in
            if playing { startSpinIfNeeded() } else { stopSpin() }
        }
        .nomiEdgeDismiss()
    }

    // MARK: - 顶栏

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.nomiScaled(size: 15, weight: .semibold))
                    .foregroundColor(CardPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(CardPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(CardPalette.line, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("正在播放")
                .font(.nomiScaled(size: 12.5, weight: .semibold))
                .foregroundColor(CardPalette.subtle)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    // MARK: - 黑胶

    private var vinyl: some View {
        ZStack(alignment: .topTrailing) {
            VinylDisc(size: 268,
                      angle: angle,
                      label: String(shownTitle.prefix(1)),
                      artwork: artworkImage,
                      dimmed: !player.isPlaying)
                .padding(.trailing, 8)

            tonearm
        }
        .frame(width: 286, height: 286)
    }

    private var artworkImage: UIImage? {
        track?.artworkImage
    }

    private var tonearm: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(
                    RadialGradient(colors: [Color(white: 0.96), Color(white: 0.68), Color(white: 0.5)],
                                   center: .init(x: 0.34, y: 0.3),
                                   startRadius: 1,
                                   endRadius: 20)
                )
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.22), radius: 4, y: 2)

            Capsule()
                .fill(
                    LinearGradient(colors: [Color(white: 0.82), Color(white: 0.56), Color(white: 0.44)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 106, height: 9)
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(height: 2)
                        .padding(.horizontal, 8),
                    alignment: .top
                )
                .rotationEffect(.degrees(player.isPlaying ? 26 : 52), anchor: .trailing)
                .offset(x: -18, y: 13)
                .shadow(color: .black.opacity(0.16), radius: 3, y: 2)
        }
        .frame(width: 128, height: 128, alignment: .topTrailing)
        .offset(x: 4, y: 2)
    }

    // MARK: - 曲目

    private var trackInfo: some View {
        VStack(spacing: 6) {
            Text(shownTitle)
                .font(.nomiScaled(size: 22, weight: .bold))
                .foregroundColor(track == nil ? CardPalette.subtle : CardPalette.ink)
                .lineLimit(1)
                .padding(.horizontal, 28)

            Text(shownSubtitle)
                .font(.nomiScaled(size: 13))
                .foregroundColor(CardPalette.subtle)
                .lineLimit(1)

            if let album = track?.album, !album.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "opticaldisc")
                        .font(.nomiScaled(size: 9))
                    Text(album)
                        .font(.nomiScaled(size: 10.5, weight: .medium))
                }
                .foregroundColor(CardPalette.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(CardPalette.raised)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - 进度

    private var progressBar: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CardPalette.line)
                        .frame(height: 4)

                    Capsule()
                        .fill(CardPalette.accent)
                        .frame(width: max(0, geo.size.width * fraction), height: 4)

                    Circle()
                        .fill(CardPalette.accent)
                        .frame(width: 11, height: 11)
                        .offset(x: max(0, geo.size.width * fraction - 5.5))
                        .shadow(color: CardPalette.accent.opacity(0.25), radius: 4)
                }
                .frame(height: 32, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isScrubbing = true
                            let ratio = min(max(value.location.x / geo.size.width, 0), 1)
                            scrubValue = ratio * player.duration
                        }
                        .onEnded { _ in
                            player.seek(to: scrubValue)
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 32)

            HStack {
                Text(MusicUtil.timeText(displayPosition))
                Spacer()
                Text(MusicUtil.timeText(player.duration))
            }
            .font(.nomiScaled(size: 10.5))
            .monospacedDigit()
            .foregroundColor(CardPalette.subtle)
        }
    }

    // MARK: - 控制

    private var controls: some View {
        HStack(spacing: 30) {
            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.nomiScaled(size: 20))
                    .foregroundColor(track == nil ? CardPalette.subtle.opacity(0.4) : CardPalette.ink)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
            .disabled(track == nil)

            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.nomiScaled(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 66, height: 66)
                    .background(track == nil ? CardPalette.subtle.opacity(0.5) : CardPalette.accent)
                    .clipShape(Circle())
                    .shadow(color: CardPalette.accent.opacity(track == nil ? 0 : 0.3),
                            radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(track == nil)

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.nomiScaled(size: 20))
                    .foregroundColor(track == nil ? CardPalette.subtle.opacity(0.4) : CardPalette.ink)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
            .disabled(track == nil)
        }
    }

    // MARK: - 底部

    private var queueBar: some View {
        Button {
            if let onOpenLibrary {
                onOpenLibrary()
            } else {
                dismiss()
            }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "music.note.list")
                    .font(.nomiScaled(size: 15, weight: .medium))
                    .foregroundColor(CardPalette.accent)
                    .frame(width: 34, height: 34)
                    .background(CardPalette.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("我的音乐")
                        .font(.nomiScaled(size: 13.5, weight: .semibold))
                        .foregroundColor(CardPalette.ink)
                    Text("音乐资料库 · 选别的")
                        .font(.nomiScaled(size: 11))
                        .foregroundColor(CardPalette.subtle)
                }

                Spacer(minLength: 0)

                Text("换一首")
                    .font(.nomiScaled(size: 12, weight: .semibold))
                    .foregroundColor(CardPalette.accent)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 转

    private func startSpinIfNeeded() {
        guard player.isPlaying else { return }
        angle = 0
        withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }

    private func stopSpin() {
        withAnimation(.easeOut(duration: 0.8)) {
            angle = angle.truncatingRemainder(dividingBy: 360)
        }
    }
}

/// 黑胶唱片：纹路、反光、中心标签（有封面就显示封面）
struct VinylDisc: View {
    var size: CGFloat
    var angle: Double
    var label: String
    var artwork: UIImage?
    var dimmed: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [Color(white: 0.10), Color(white: 0.045), Color(white: 0.02)],
                                   center: .init(x: 0.5, y: 0.5),
                                   startRadius: size * 0.05,
                                   endRadius: size * 0.55)
                )

            ForEach(0..<18, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.035 + Double(index % 3) * 0.008), lineWidth: 0.6)
                    .padding(CGFloat(index) * size * 0.026)
            }

            Circle()
                .fill(
                    AngularGradient(
                        colors: [Color.white.opacity(0.16), .clear, .clear,
                                 Color.white.opacity(0.05), .clear],
                        center: .center
                    )
                )
                .blendMode(.plusLighter)
                .rotationEffect(.degrees(angle * 0.2))

            centerLabel
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(angle))
        .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
        .opacity(dimmed ? 0.72 : 1)
        .shadow(color: .black.opacity(0.22), radius: 24, y: 14)
        .accessibilityHidden(true)
    }

    private var centerLabel: some View {
        ZStack {
            if let artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 0.42, height: size * 0.42)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            } else {
                Circle()
                    .fill(
                        LinearGradient(colors: [Color(red: 0.29, green: 0.64, blue: 0.91),
                                                Color(red: 0.12, green: 0.44, blue: 0.82)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .frame(width: size * 0.37, height: size * 0.37)

                Text(label)
                    .font(.system(size: size * 0.062, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(0.92)
            }

            Circle()
                .fill(CardPalette.screen)
                .frame(width: size * 0.032, height: size * 0.032)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
        }
    }
}
