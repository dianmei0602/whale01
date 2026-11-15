import Foundation
import MediaPlayer
import UIKit
import Combine

/// 一首来自 iPhone“音乐”资料库的歌曲。
struct MusicTrack: Identifiable {
    let id: String
    let mediaItem: MPMediaItem

    var title: String {
        let value = mediaItem.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "未命名歌曲" : value
    }

    var artist: String {
        mediaItem.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var album: String {
        mediaItem.albumTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var duration: Double {
        max(0, mediaItem.playbackDuration)
    }

    var isCloudItem: Bool {
        mediaItem.isCloudItem
    }

    var artworkImage: UIImage? {
        mediaItem.artwork?.image(at: CGSize(width: 360, height: 360))
    }

    init(item: MPMediaItem) {
        self.mediaItem = item
        self.id = String(item.persistentID)
    }
}

/// 读取系统“音乐”资料库。不会复制或导入文件。
@MainActor
final class MusicLibrary: ObservableObject {

    @Published private(set) var tracks: [MusicTrack] = []
    @Published private(set) var authorization: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published private(set) var loading = false
    @Published var message: String?

    var hasAccess: Bool {
        authorization == .authorized
    }

    init() {
        authorization = MPMediaLibrary.authorizationStatus()
    }

    func requestAccess() async -> Bool {
        if MPMediaLibrary.authorizationStatus() == .notDetermined {
            let status: MPMediaLibraryAuthorizationStatus = await withCheckedContinuation { continuation in
                MPMediaLibrary.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus)
                }
            }
            authorization = status
        } else {
            authorization = MPMediaLibrary.authorizationStatus()
        }
        return authorization == .authorized
    }

    func reload(requestPermission: Bool = false) async {
        authorization = MPMediaLibrary.authorizationStatus()

        if authorization == .notDetermined, requestPermission {
            _ = await requestAccess()
        }

        guard authorization == .authorized else {
            tracks = []
            message = authorization == .denied
                ? "音乐资料库权限已关闭，可到系统设置中开启。"
                : nil
            return
        }

        loading = true
        defer { loading = false }

        let items = MPMediaQuery.songs().items ?? []
        var seen = Set<UInt64>()
        tracks = items.compactMap { item in
            guard seen.insert(item.persistentID).inserted else { return nil }
            return MusicTrack(item: item)
        }
        .sorted {
            let titleOrder = $0.title.localizedStandardCompare($1.title)
            if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
            return $0.artist.localizedStandardCompare($1.artist) == .orderedAscending
        }

        message = tracks.isEmpty ? "手机音乐资料库中还没有歌曲。" : nil
    }

    func search(_ term: String) -> [MusicTrack] {
        let key = term.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.lowercased().contains(key)
                || $0.artist.lowercased().contains(key)
                || $0.album.lowercased().contains(key)
        }
    }
}
