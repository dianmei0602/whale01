import Foundation

/// 纯逻辑的音乐工具：文件判定、标题清理、时间格式。
///
/// 单独放一个不依赖 AVFoundation 的文件，逻辑测试才能直接编译它。
enum MusicUtil {

    /// 支持导入的音频后缀
    static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "alac", "ogg", "opus"
    ]

    static func isAudioFile(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return audioExtensions.contains(ext)
    }

    /// 没有元数据时，用文件名当标题：去掉后缀、下划线换空格
    static func title(fromFileName name: String) -> String {
        // 以点开头的隐藏文件（比如 ".mp3"）没有可用名字
        if name.hasPrefix(".") { return "未命名" }

        var title = (name as NSString).deletingPathExtension
        title = title.replacingOccurrences(of: "_", with: " ")
        title = title.replacingOccurrences(of: "-", with: " ")
        // 常见的前缀编号：「01 晴天」「03. 夜曲」
        while let first = title.first, first.isNumber {
            title.removeFirst()
        }
        let trimSet = CharacterSet(charactersIn: " .·、-—")
        title = title.trimmingCharacters(in: trimSet)
        return title.isEmpty ? "未命名" : title
    }

    /// 秒 → 3:07 / 1:02:03
    static func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// 「放点周杰伦的歌」→「周杰伦」。用于对话里说的"想听什么"。
    static func cleanTerm(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let platformWords = ["本地音乐", "我的音乐", "网易云音乐", "网易云", "本地", "歌单"]
        for word in platformWords { s = s.replacingOccurrences(of: word, with: " ") }

        let prefixes = [
            "帮我放点", "帮我放首", "帮我放", "放点", "放一首", "放首", "放个",
            "来点", "来一首", "来首", "我想听", "想听", "我要听", "听一首", "听首",
            "听点", "播放", "放"
        ]
        s = s.trimmingCharacters(in: .whitespaces)
        for prefix in prefixes where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
            break
        }

        let suffixes = ["的歌", "的音乐", "一首", "吧", "呗"]
        s = s.trimmingCharacters(in: .whitespaces)
        for suffix in suffixes where s.hasSuffix(suffix) {
            s = String(s.dropLast(suffix.count))
            break
        }

        let empties = ["音乐", "歌曲", "歌", "music", ""]
        if empties.contains(s) { return "" }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
