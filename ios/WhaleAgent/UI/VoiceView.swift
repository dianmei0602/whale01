import SwiftUI
import UIKit

/// Compact listening panel presented from the bottom while recognition starts
/// automatically.
struct VoiceView: View {
    @ObservedObject var voice: VoiceInputController
    let onInsert: (String) -> Void
    let onCancel: () -> Void

    @State private var localError: String?
    @State private var isFinishing = false
    @State private var hasAutoStarted = false

    private let voiceBlue = Color(
        red: 31 / 255,
        green: 105 / 255,
        blue: 132 / 255
    )
    private let stopRed = Color(
        red: 184 / 255,
        green: 77 / 255,
        blue: 88 / 255
    )

    private var content: WhaleVoiceOverlayContent {
        WhaleVoiceOverlayPresenter.content(
            isRecording: voice.isRecording,
            isFinalizing: voice.isFinalizing || isFinishing,
            transcript: voice.transcript,
            errorText: localError ?? voice.errorText
        )
    }

    var body: some View {
        listeningCard
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(cardColor.ignoresSafeArea())
        .accessibilityIdentifier("voice-input-overlay")
        .task {
            await startIfNeeded()
        }
        .onDisappear {
            voice.cancel()
        }
    }

    private var listeningCard: some View {
        VStack(spacing: 0) {
            Text(content.title)
                .whaleFont(size: 17, weight: .semibold)
                .foregroundStyle(.primary)

            Text(content.message)
                .whaleFont(size: 13)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .lineLimit(3)
                .padding(.top, 6)
                .padding(.horizontal, 18)
                .frame(minHeight: 38, alignment: .top)

            waveform
                .padding(.top, 12)
                .padding(.bottom, 14)

            actionButton
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("取消语音输入")
            .accessibilityIdentifier("voice-input-cancel")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice-input-card")
    }

    private var waveform: some View {
        TimelineView(
            .animation(minimumInterval: 1.0 / 24.0, paused: !content.showsWaveform)
        ) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<18, id: \.self) { index in
                    Capsule()
                        .fill(voiceBlue)
                        .frame(width: 3, height: waveformHeight(index, time: time))
                }
            }
            .frame(height: 34)
        }
        .opacity(content.showsWaveform ? 1 : 0.28)
        .accessibilityHidden(true)
    }

    private var actionButton: some View {
        Button(action: performPrimaryAction) {
            HStack(spacing: 6) {
                Image(systemName: actionIcon)
                    .font(.system(size: 12, weight: .bold))
                Text(content.actionTitle)
                    .whaleFont(size: 14, weight: .semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(minHeight: 42)
            .background(actionColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!content.actionEnabled)
        .opacity(content.actionEnabled ? 1 : 0.60)
        .accessibilityIdentifier("voice-input-action")
    }

    private var actionIcon: String {
        switch content.actionTitle {
        case "停止": return "stop.fill"
        case "再试一次": return "arrow.clockwise"
        case "填入输入框": return "arrow.down.to.line"
        case "开始说话": return "mic.fill"
        default: return "waveform"
        }
    }

    private var actionColor: Color {
        switch content.actionTitle {
        case "停止", "再试一次":
            return stopRed
        case "请稍候":
            return Color.gray
        default:
            return voiceBlue
        }
    }

    private var cardColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.118, green: 0.129, blue: 0.141, alpha: 1)
                : .white
        })
    }

    private func waveformHeight(_ index: Int, time: TimeInterval) -> CGFloat {
        let base: [CGFloat] = [10, 16, 23, 12, 28, 20, 32, 17, 25, 13, 29, 21, 34, 19, 26, 14, 22, 11]
        guard content.showsWaveform else { return base[index % base.count] * 0.58 }
        let swing = 0.46 + 0.54 * abs(sin(time * 6.4 + Double(index) * 0.62))
        return base[index % base.count] * CGFloat(swing)
    }

    private func startIfNeeded() async {
        guard !hasAutoStarted else { return }
        hasAutoStarted = true
        localError = nil
        guard !voice.isRecording, !voice.isFinalizing else { return }
        await voice.start()
    }

    private func performPrimaryAction() {
        guard content.actionEnabled else { return }

        if voice.errorText != nil || localError != nil {
            localError = nil
            isFinishing = false
            voice.reset()
            Task { await voice.start() }
        } else if voice.isRecording || voice.isFinalizing || isFinishing {
            finishAndInsert()
        } else {
            let transcript = voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if transcript.isEmpty {
                Task { await voice.start() }
            } else {
                onInsert(transcript)
            }
        }
    }

    private func finishAndInsert() {
        guard !isFinishing else { return }
        isFinishing = true
        Task {
            let final = await voice.finishRecognition()
            let text = (final ?? voice.transcript)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                localError = voice.errorText ?? "没有收到最终识别结果，请再试一次。"
                isFinishing = false
                return
            }
            isFinishing = false
            onInsert(text)
        }
    }

    private func cancel() {
        guard !isFinishing else { return }
        voice.cancel()
        onCancel()
    }
}
