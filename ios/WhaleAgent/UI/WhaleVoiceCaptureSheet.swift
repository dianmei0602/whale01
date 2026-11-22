import SwiftUI

struct WhaleVoiceCaptureSheet: View {
    let target: VoiceCaptureTarget
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var voice = VoiceInputController()
    @State private var phase: VoiceCapturePhase = .listening
    @State private var didAutoStart = false

    private var content: VoiceCaptureContent {
        VoiceCapturePresentation.content(
            target: target,
            phase: phase,
            transcript: voice.transcript
        )
    }

    var body: some View {
        VStack(spacing: 15) {
            Text(content.title)
                .whaleFont(size: 18, weight: .bold)
                .foregroundStyle(WhaleIMessagePalette.text)

            Text(content.message)
                .whaleFont(size: 14)
                .foregroundStyle(WhaleIMessagePalette.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .lineLimit(4)
                .frame(minHeight: 48, alignment: .top)
                .padding(.horizontal, 20)

            waveform

            Button(action: primaryAction) {
                HStack(spacing: 7) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 13, weight: .bold))
                    Text(content.actionTitle)
                        .whaleFont(size: 15, weight: .semibold)
                }
                .foregroundStyle(WhaleIMessagePalette.outgoingText)
                .padding(.horizontal, 24)
                .frame(minHeight: 46)
                .background(WhaleIMessagePalette.outgoing, in: Capsule())
            }
            .buttonStyle(.whalePress)
            .disabled(!content.actionEnabled)
            .opacity(content.actionEnabled ? 1 : 0.55)
            .accessibilityIdentifier("whale-voice-action")
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(WhaleIMessagePalette.canvas)
        .overlay(alignment: .topTrailing) {
            Button {
                voice.cancel()
                onCancel()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WhaleIMessagePalette.muted)
                    .frame(width: 34, height: 34)
                    .background(
                        WhaleIMessagePalette.field,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .padding(12)
            .accessibilityLabel("取消语音输入")
            .accessibilityIdentifier("whale-voice-cancel")
        }
        .accessibilityIdentifier("whale-voice-capture-sheet")
        .task { await startIfNeeded() }
        .onChange(of: voice.finalResult) { _, result in
            guard let result else { return }
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                phase = .failed("没有收到可用文字，请再说一次。")
            } else {
                phase = .review(text)
            }
        }
        .onChange(of: voice.errorText) { _, error in
            guard let error else { return }
            phase = .failed(error)
        }
        .onDisappear { voice.cancel() }
    }

    private var waveform: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 24.0,
                paused: !content.showsWaveform
                    || !InteractionMotion.waveformEnabled(reduceMotion: reduceMotion)
            )
        ) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<16, id: \.self) { index in
                    Capsule()
                        .fill(WhaleIMessagePalette.outgoing.opacity(0.82))
                        .frame(
                            width: 4,
                            height: height(index: index, time: time)
                        )
                }
            }
            .frame(height: 36)
        }
        .opacity(content.showsWaveform ? 1 : 0.32)
        .accessibilityHidden(true)
    }

    private var actionIcon: String {
        switch phase {
        case .idle:
            return "mic.fill"
        case .listening:
            return "stop.fill"
        case .finalizing:
            return "waveform"
        case .review:
            return "arrow.down.to.line"
        case .failed:
            return "arrow.clockwise"
        }
    }

    private func height(index: Int, time: TimeInterval) -> CGFloat {
        let base: [CGFloat] = [10, 16, 24, 13, 30, 20, 34, 18, 27, 14, 31, 22, 35, 19, 26, 12]
        guard content.showsWaveform, !reduceMotion else {
            return base[index % base.count] * 0.52
        }
        let wave = 0.48 + 0.52 * abs(
            sin(time * 6.2 + Double(index) * 0.58)
        )
        return base[index % base.count] * CGFloat(wave)
    }

    private func startIfNeeded() async {
        guard !didAutoStart else { return }
        didAutoStart = true
        phase = .listening
        await voice.start()
        if voice.errorText != nil {
            phase = .failed(voice.errorText ?? "语音输入启动失败。")
        } else if !voice.isRecording && !voice.isFinalizing {
            phase = .idle
        }
    }

    private func primaryAction() {
        switch phase {
        case .idle:
            phase = .listening
            Task { await voice.start() }
        case .listening:
            phase = .finalizing
            voice.stop()
        case .finalizing:
            break
        case .review(let text):
            onCommit(text)
            dismiss()
        case .failed:
            voice.reset()
            phase = .listening
            Task { await voice.start() }
        }
    }
}
