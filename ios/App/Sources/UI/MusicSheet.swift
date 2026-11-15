import SwiftUI
import MediaPlayer
import UIKit

/// 读取 iPhone“音乐”资料库，并在 Nomi 的黑胶界面里播放。
struct MusicSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var initialTerm: String = ""

    @StateObject private var library = MusicLibrary()
    @ObservedObject private var player = MusicPlayer.shared

    @State private var showPlayer = false
    @State private var keyword = ""

    private var filtered: [MusicTrack] {
        let key = keyword.trimmingCharacters(in: .whitespaces)
        return key.isEmpty ? library.tracks : library.search(key)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    accessCard

                    if library.loading {
                        ProgressView("正在读取音乐资料库…")
                            .font(.nomiScaled(size: 12))
                            .tint(CardPalette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    } else if library.hasAccess {
                        if library.tracks.isEmpty {
                            emptyState
                        } else {
                            searchBar
                            trackList
                        }
                    } else {
                        permissionState
                    }

                    if let message = library.message, !message.isEmpty {
                        Text(message)
                            .font(.nomiScaled(size: 11.5))
                            .foregroundStyle(CardPalette.subtle)
                    }

                    if let error = player.errorText, !error.isEmpty {
                        Text(error)
                            .font(.nomiScaled(size: 11.5))
                            .foregroundStyle(CardPalette.amberInk)
                            .padding(11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CardPalette.amberSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    noteLine
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 26)
            }
            .background(AppBackground())
            .navigationTitle("听音乐")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .font(.nomiScaled(size: 15, weight: .semibold))
                        .foregroundColor(CardPalette.accent)
                }
            }
            .fullScreenCover(isPresented: $showPlayer) {
                VinylPlayerPage(player: player) {
                    showPlayer = false
                }
            }
            .task {
                if !initialTerm.isEmpty { keyword = initialTerm }
                await library.reload(requestPermission: true)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, library.hasAccess {
                    Task { await library.reload() }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("iPhone 音乐资料库")
                .font(.nomiScaled(size: 13, weight: .semibold))
                .foregroundStyle(CardPalette.subtle)

            Spacer()

            Text("\(library.tracks.count) 首")
                .font(.nomiScaled(size: 11.5))
                .foregroundStyle(CardPalette.subtle)
        }
    }

    private var accessCard: some View {
        WhaleGlassCard(radius: 18, padding: 14) {
            HStack(spacing: 11) {
                WhaleIconTile(symbol: "music.note.list", color: CardPalette.accent, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("读取手机里的音乐")
                        .font(.nomiScaled(size: 14, weight: .semibold))
                        .foregroundStyle(CardPalette.ink)
                    Text("不会导入、复制或上传音频文件")
                        .font(.nomiScaled(size: 10.5))
                        .foregroundStyle(CardPalette.subtle)
                }

                Spacer()

                if library.hasAccess {
                    Button {
                        Task { await library.reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.nomiScaled(size: 13, weight: .semibold))
                            .foregroundStyle(CardPalette.accent)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("刷新音乐资料库")
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.nomiScaled(size: 13))
                .foregroundStyle(CardPalette.subtle)

            TextField("搜歌名、歌手、专辑", text: $keyword)
                .font(.nomiScaled(size: 14))
                .foregroundStyle(CardPalette.ink)

            if !keyword.isEmpty {
                Button {
                    keyword = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.nomiScaled(size: 14))
                        .foregroundStyle(CardPalette.subtle.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private var trackList: some View {
        VStack(spacing: 0) {
            ForEach(filtered) { track in
                trackRow(track)
                if track.id != filtered.last?.id {
                    WhaleRowDivider(leading: 54)
                }
            }
        }
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private func trackRow(_ track: MusicTrack) -> some View {
        Button {
            player.play(track, in: filtered)
            if player.current?.id == track.id {
                showPlayer = true
            }
        } label: {
            HStack(spacing: 11) {
                artworkTile(track)
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.nomiScaled(size: 14.5, weight: .medium))
                        .foregroundStyle(CardPalette.ink)
                        .lineLimit(1)

                    Text(subtitle(track))
                        .font(.nomiScaled(size: 11.5))
                        .foregroundStyle(CardPalette.subtle)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "play.fill")
                    .font(.nomiScaled(size: 11, weight: .semibold))
                    .foregroundStyle(CardPalette.accent)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func artworkTile(_ track: MusicTrack) -> some View {
        if let image = track.artworkImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(CardPalette.raised)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.nomiScaled(size: 14, weight: .medium))
                        .foregroundStyle(CardPalette.accent)
                }
        }
    }

    private func subtitle(_ track: MusicTrack) -> String {
        var parts: [String] = []
        if !track.artist.isEmpty { parts.append(track.artist) }
        if !track.album.isEmpty { parts.append(track.album) }
        if track.duration > 0 { parts.append(MusicUtil.timeText(track.duration)) }
        if track.isCloudItem { parts.append("云端") }
        return parts.isEmpty ? "音乐资料库" : parts.joined(separator: " · ")
    }

    private var permissionState: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.nomiScaled(size: 30))
                .foregroundStyle(CardPalette.subtle.opacity(0.7))
            Text("需要读取音乐资料库")
                .font(.nomiScaled(size: 16, weight: .semibold))
                .foregroundStyle(CardPalette.ink)
            Text("只在你进入音乐入口时申请，不会在 App 启动时弹窗。")
                .font(.nomiScaled(size: 12))
                .foregroundStyle(CardPalette.subtle)
                .multilineTextAlignment(.center)

            Button {
                if library.authorization == .denied {
                    openSystemSettings()
                } else {
                    Task {
                        _ = await library.requestAccess()
                        await library.reload()
                    }
                }
            } label: {
                Text(library.authorization == .denied ? "去系统设置" : "允许读取音乐")
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundStyle(CardPalette.navyInk)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(CardPalette.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(WhalePressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.nomiScaled(size: 30))
                .foregroundStyle(CardPalette.subtle.opacity(0.7))
            Text("资料库里还没有歌曲")
                .font(.nomiScaled(size: 16, weight: .semibold))
                .foregroundStyle(CardPalette.ink)
            Text("请先在 iPhone「音乐」App 或电脑同步音乐。")
                .font(.nomiScaled(size: 12))
                .foregroundStyle(CardPalette.subtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private var noteLine: some View {
        Text("歌曲来自系统「音乐」资料库，不会导入、复制或上传音频文件。")
            .font(.nomiScaled(size: 11))
            .foregroundStyle(CardPalette.subtle.opacity(0.9))
            .padding(.top, 2)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
