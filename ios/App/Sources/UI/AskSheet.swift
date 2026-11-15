import SwiftUI

/// 点底部那条「问我点什么」进来的对话页。
/// 打字或按住说话；有 API key 就走 DeepSeek，没有就退回本地规则。
struct AskSheet: View {
    let state: AppState
    @Environment(\.dismiss) private var dismiss

    struct Line: Identifiable {
        let id = UUID()
        let mine: Bool
        let text: String
    }

    @State private var input = ""
    @State private var messages: [Line] = []
    @State private var speech = SpeechRecognizer()
    @State private var thinking = false
    @State private var showSettings = false
    @State private var hasKey = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { line in
                            bubble(line)
                        }
                        if thinking {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.75).tint(CardPalette.accent)
                                Text("我在想…")
                                    .font(.nomiScaled(size: 14.5))
                                    .foregroundColor(CardPalette.subtle)
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)

                if let err = speech.errorText {
                    Text(err)
                        .font(.nomiScaled(size: 13.5))
                        .foregroundColor(Color(red: 1.00, green: 0.55, blue: 0.45))
                        .padding(.bottom, 4)
                }

                inputBar
            }
            .background(
                ZStack {
                    CardPalette.screen
                    RadialGradient(colors: [CardPalette.accent.opacity(0.08), .clear],
                                   center: .top, startRadius: 0, endRadius: 340)
                }
                .ignoresSafeArea()
            )
            .navigationTitle("问我")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(state: state)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            hasKey = !(Keychain.load("deepseek.key") ?? "").isEmpty
            if messages.isEmpty {
                messages.append(Line(mine: false,
                                     text: "在。天气、日程、运动、睡觉，问这些我还答得上来。"))
            }
        }
        .onChange(of: showSettings) { _, presenting in
            if !presenting {
                hasKey = !(Keychain.load("deepseek.key") ?? "").isEmpty
            }
        }
    }

    // MARK: - 顶部状态：到底走没走模型

    private var statusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(hasKey ? CardPalette.accent : Color(red: 1.00, green: 0.74, blue: 0.38))
                .frame(width: 6, height: 6)
                .shadow(color: hasKey ? CardPalette.accent : .clear, radius: 4)

            Text(hasKey ? "DeepSeek 已连接" : "未填 API key · 本地规则回答")
                .font(.nomiScaled(size: 13.5))
                .foregroundColor(CardPalette.subtle)

            Spacer()

            if !hasKey {
                Button("去填") { showSettings = true }
                    .font(.nomiScaled(size: 13.5, weight: .semibold))
                    .foregroundColor(CardPalette.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(CardPalette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CardPalette.line).frame(height: 1)
        }
    }

    private func bubble(_ line: Line) -> some View {
        HStack {
            if line.mine { Spacer(minLength: 44) }
            Text(line.text)
                .font(.nomiScaled(size: 17.5))
                .foregroundColor(line.mine
                                 ? Color(red: 0.03, green: 0.09, blue: 0.12)
                                 : CardPalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(line.mine ? CardPalette.accent : CardPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(line.mine ? Color.clear : CardPalette.line, lineWidth: 1)
                )
            if !line.mine { Spacer(minLength: 44) }
        }
    }

    // MARK: - 输入区

    private var inputBar: some View {
        VStack(spacing: 10) {
            if speech.isRecording {
                recordingHint
            }

            HStack(spacing: 10) {
                Image(systemName: speech.isRecording ? "waveform" : "mic.fill")
                    .font(.nomiScaled(size: 24.5, weight: .medium))
                    .foregroundColor(speech.isRecording
                                     ? Color(red: 0.03, green: 0.09, blue: 0.12)
                                     : CardPalette.ink)
                    .frame(width: 56, height: 56)
                    .background(speech.isRecording
                                ? Color(red: 0.36, green: 0.92, blue: 0.66)
                                : CardPalette.raised)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(CardPalette.line, lineWidth: 1))
                    .onLongPressGesture(minimumDuration: 0.15, pressing: { pressing in
                        if pressing {
                            Task { await speech.start() }
                        } else {
                            speech.stop()
                            if !speech.transcript.isEmpty {
                                send(speech.transcript)
                            }
                        }
                    }, perform: {})

                TextField(speech.isRecording ? "松开就发送…" : "问我点什么…",
                          text: $input, axis: .vertical)
                    .font(.nomiScaled(size: 17.5))
                    .foregroundColor(CardPalette.ink)
                    .lineLimit(1...3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 17)
                    .background(CardPalette.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(CardPalette.line, lineWidth: 1)
                    )
                    .onSubmit { send(input) }

                Button {
                    send(input)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.nomiScaled(size: 23, weight: .bold))
                        .foregroundColor(Color(red: 0.03, green: 0.09, blue: 0.12))
                        .frame(width: 56, height: 56)
                        .background(CardPalette.accent)
                        .clipShape(Circle())
                        .shadow(color: CardPalette.accent.opacity(0.45), radius: 10)
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var recordingHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .foregroundColor(CardPalette.accent)
            Text(speech.transcript.isEmpty ? "在听…说完了松手" : speech.transcript)
                .font(.nomiScaled(size: 16))
                .foregroundColor(CardPalette.ink)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(CardPalette.raised)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CardPalette.accent.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - 发出去

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(Line(mine: true, text: trimmed))
        input = ""

        let context = AnswerEngine.Context(cards: state.cards,
                                           temperature: state.currentTemperature,
                                           now: Date(),
                                           stage: state.pet.stage)

        let key = Keychain.load("deepseek.key") ?? ""
        guard !key.isEmpty else {
            messages.append(Line(mine: false,
                                 text: AnswerEngine.answer(to: trimmed, context: context)))
            return
        }

        thinking = true
        Task {
            let reply: String
            do {
                reply = try await LLMClient(apiKey: key).chat(system: systemPrompt, user: trimmed)
            } catch {
                reply = AnswerEngine.answer(to: trimmed, context: context) + "（模型没连上）"
            }
            messages.append(Line(mine: false, text: reply))
            thinking = false
        }
    }

    /// 模型看到的"今天"。它只知道这些，所以不会编。
    private var systemPrompt: String {
        var lines: [String] = []
        lines.append("你是「它」，一个住在手机里的助理宠物，只有眼睛没有嘴。")
        lines.append("说话规则：用「我」「你」；短句；一次只说一件事；不超过 50 字；")
        lines.append("不说教、不评价用户；不用「建议您」「温馨提示」「综上」这类词。")
        lines.append("下面是你唯一知道的信息。信息里没有的，就说不知道，绝不编。")

        if state.cards.isEmpty {
            lines.append("今天没有卡片。")
        } else {
            lines.append("今天的卡片：")
            for card in state.cards {
                lines.append("- \(card.time) \(card.fact)；\(card.advice)")
            }
        }

        if let temp = state.currentTemperature {
            lines.append("现在气温 \(Int(temp.rounded())) 度。")
        }
        lines.append("你现在的状态：\(state.pet.stage.title)。")
        return lines.joined(separator: "\n")
    }
}
