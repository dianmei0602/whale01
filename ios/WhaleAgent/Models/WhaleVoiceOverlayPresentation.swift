import Foundation

struct WhaleVoiceOverlayContent: Equatable {
    let title: String
    let message: String
    let actionTitle: String
    let actionEnabled: Bool
    let showsWaveform: Bool
}

enum WhaleVoiceOverlayPresenter {
    static func content(
        isRecording: Bool,
        isFinalizing: Bool,
        transcript: String,
        errorText: String?
    ) -> WhaleVoiceOverlayContent {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        if let errorText,
           !errorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return WhaleVoiceOverlayContent(
                title: "没听清",
                message: errorText,
                actionTitle: "再试一次",
                actionEnabled: true,
                showsWaveform: false
            )
        }

        if isFinalizing {
            return WhaleVoiceOverlayContent(
                title: "正在整理…",
                message: "马上把识别结果放进输入框",
                actionTitle: "请稍候",
                actionEnabled: false,
                showsWaveform: true
            )
        }

        if isRecording {
            return WhaleVoiceOverlayContent(
                title: "正在听…",
                message: trimmedTranscript.isEmpty
                    ? "说出你想让鲸鱼做的事"
                    : trimmedTranscript,
                actionTitle: "停止",
                actionEnabled: true,
                showsWaveform: true
            )
        }

        if !trimmedTranscript.isEmpty {
            return WhaleVoiceOverlayContent(
                title: "听清了",
                message: trimmedTranscript,
                actionTitle: "填入输入框",
                actionEnabled: true,
                showsWaveform: false
            )
        }

        return WhaleVoiceOverlayContent(
            title: "准备好了",
            message: "轻点开始，或直接说出你想让鲸鱼做的事",
            actionTitle: "开始说话",
            actionEnabled: true,
            showsWaveform: false
        )
    }
}
