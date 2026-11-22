import Foundation

enum VoiceCaptureTarget: String, Equatable {
    case chat
    case todo
    case workspace

    var title: String {
        switch self {
        case .chat: return "给鲸鱼说"
        case .todo: return "记一件待办"
        case .workspace: return "记到工作台"
        }
    }

    var commitTitle: String {
        switch self {
        case .chat: return "填入输入框"
        case .todo: return "填入待办"
        case .workspace: return "填入记录"
        }
    }
}

enum VoiceCapturePhase: Equatable {
    case idle
    case listening
    case finalizing
    case review(String)
    case failed(String)
}

struct VoiceCaptureContent: Equatable {
    let title: String
    let message: String
    let actionTitle: String
    let actionEnabled: Bool
    let showsWaveform: Bool
}

enum VoiceCapturePresentation {
    static func content(
        target: VoiceCaptureTarget,
        phase: VoiceCapturePhase,
        transcript: String
    ) -> VoiceCaptureContent {
        switch phase {
        case .idle:
            return VoiceCaptureContent(
                title: target.title,
                message: "轻触开始说话",
                actionTitle: "开始说话",
                actionEnabled: true,
                showsWaveform: false
            )
        case .listening:
            return VoiceCaptureContent(
                title: target.title,
                message: transcript.isEmpty ? "正在听你说…" : transcript,
                actionTitle: "完成",
                actionEnabled: true,
                showsWaveform: true
            )
        case .finalizing:
            return VoiceCaptureContent(
                title: "正在整理…",
                message: transcript,
                actionTitle: "请稍候",
                actionEnabled: false,
                showsWaveform: false
            )
        case .review(let text):
            return VoiceCaptureContent(
                title: "听清了",
                message: text,
                actionTitle: target.commitTitle,
                actionEnabled: !text.isEmpty,
                showsWaveform: false
            )
        case .failed(let message):
            return VoiceCaptureContent(
                title: "没听清",
                message: message,
                actionTitle: "再试一次",
                actionEnabled: true,
                showsWaveform: false
            )
        }
    }
}
