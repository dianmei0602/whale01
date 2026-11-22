import Foundation

@main
struct VoiceOverlayStateTest {
    static func main() {
        let listening = WhaleVoiceOverlayPresenter.content(
            isRecording: true,
            isFinalizing: false,
            transcript: "",
            errorText: nil
        )
        precondition(listening.title == "正在听…")
        precondition(listening.message == "说出你想让鲸鱼做的事")
        precondition(listening.actionTitle == "停止")
        precondition(listening.showsWaveform)

        let finalizing = WhaleVoiceOverlayPresenter.content(
            isRecording: false,
            isFinalizing: true,
            transcript: "帮我记一件事",
            errorText: nil
        )
        precondition(finalizing.title == "正在整理…")
        precondition(finalizing.actionTitle == "请稍候")
        precondition(!finalizing.actionEnabled)

        let failed = WhaleVoiceOverlayPresenter.content(
            isRecording: false,
            isFinalizing: false,
            transcript: "",
            errorText: "没有收到最终识别结果"
        )
        precondition(failed.title == "没听清")
        precondition(failed.actionTitle == "再试一次")
        precondition(!failed.showsWaveform)

        let ready = WhaleVoiceOverlayPresenter.content(
            isRecording: false,
            isFinalizing: false,
            transcript: "今天怎么安排",
            errorText: nil
        )
        precondition(ready.title == "听清了")
        precondition(ready.message == "今天怎么安排")
        precondition(ready.actionTitle == "填入输入框")

        print("VOICE_OVERLAY_STATE_OK")
    }
}
