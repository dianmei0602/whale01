import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Multi-line composer in the Assistant tab's safe-area inset. Drafts stay
/// editable during a turn and survive tab switches without sending themselves.
struct ConversationComposerBar: View {
    static let reservedHeight: CGFloat = 66

    @ObservedObject var model: AppModel
    @Binding var externalFocused: Bool
    @StateObject private var voice = VoiceInputController()
    @FocusState private var focused: Bool

    @Binding var draft: String
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var finishingVoice = false
    @State private var draftContext: String?
    @State private var voicePrefix = ""
    @State private var voiceAnalysis: VoiceDraftAnalysis?
    @State private var voiceStartedAt: Date?
    @State private var voiceLocked = false
    @State private var longPressToken: UUID?
    @State private var longPressArmed = false
    @State private var correctingCorrection: VoiceCorrection?
    @State private var correctionIntended = ""
    @Environment(\.scenePhase) private var scenePhase
    private let drafts = ComposerDraftStore()

    var body: some View {
        VStack(spacing: 7) {
            if let voiceError = voice.errorText {
                notice(voiceError)
            }
            if let importError {
                notice(importError)
            }
            if voice.isRecording {
                voiceStrip
            }
            if !voice.isRecording, let voiceAnalysis {
                voiceDraftPreview(voiceAnalysis)
            }
            composer
            if model.isBusy && !draft.isEmpty {
                Text("草稿已保留，这一轮结束后可发送")
                    .font(.subheadline).foregroundStyle(WhaleTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(WhaleChromeBackground())
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: photoItem) { _, _ in
            Task { await ingestPhoto() }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            handleImportedFile(result)
        }
        .onChange(of: voice.transcript) { _, text in
            guard !text.isEmpty else { return }
            draft = voicePrefix.isEmpty ? text : voicePrefix + "\n" + text
        }
        .onChange(of: voice.isRecording) { wasRecording, isRecording in
            if isRecording {
                voiceStartedAt = Date()
                voiceLocked = false
                model.setVoiceInteractionPhase(recording: true)
            } else if wasRecording {
                model.setVoiceInteractionPhase(recording: false)
            }
        }
        .onChange(of: voice.finalResult) { _, result in
            guard let result, voice.errorText == nil else { return }
            let raw = voicePrefix.isEmpty ? result.text : voicePrefix + "\n" + result.text
            let analysis = VoiceDraftAnalyzer.analyze(
                raw,
                engine: voice.engineName,
                elapsed: voiceStartedAt.map { Date().timeIntervalSince($0) },
                confidence: voice.confidence
            )
            voiceAnalysis = analysis
            draft = analysis.correctedText
            voicePrefix = ""
            model.setVoiceInteractionPhase(recording: false, editable: true)
            focused = true
        }
        .onChange(of: focused) { _, value in
            externalFocused = value
        }
        .onChange(of: voice.isRecording) { wasRecording, isRecording in
            guard wasRecording, !isRecording else { return }
            guard voice.errorText == nil else { return }
            if !voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                focused = true
            }
        }
        .task {
            if draftContext == nil { draftContext = model.composerContextID; draft = drafts.load(context: model.composerContextID) }
        }
        .task(id: draft) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let context = draftContext else { return }
            drafts.save(draft, context: context)
        }
        .onChange(of: model.composerContextID) { _, context in
            if let old = draftContext { drafts.save(draft, context: old) }
            draftContext = context; draft = drafts.load(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, let context = draftContext { drafts.save(draft, context: context); voice.cancel() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .whalePrefillDraft)) { notification in
            guard let text = notification.userInfo?["text"] as? String else { return }
            draft = draft.isEmpty ? text : draft + "\n" + text
            focused = true
        }
        .onDisappear {
            if let context = draftContext { drafts.save(draft, context: context) }
            externalFocused = false
            voice.cancel()
        }
        .alert("修正识别词", isPresented: Binding(
            get: { correctingCorrection != nil },
            set: { if !$0 { correctingCorrection = nil } }
        )) {
            TextField("以后识别成", text: $correctionIntended)
            Button("取消", role: .cancel) { correctingCorrection = nil }
            Button("记住修正") { saveVoiceCorrection() }
        } message: {
            if let correction = correctingCorrection {
                Text("原听写：\(correction.original)。修正会保存到本机个人词库，只在语音草稿中替换。")
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: 2) {
            Menu {
                Button { showPhotoPicker = true } label: {
                    Label("从照片识别", systemImage: "photo")
                }
                Button { showFileImporter = true } label: {
                    Label("从文件识别 PDF/图片", systemImage: "doc")
                }
            } label: {
                Group {
                    if model.isExtractingDocument {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "plus")
                            .whaleFont(size: 19, weight: .medium)
                            .foregroundStyle(WhaleTheme.ink)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy || model.isExtractingDocument)
            .opacity(model.isBusy || model.isExtractingDocument ? 0.4 : 1)
            .accessibilityLabel("导入照片或文件识别文字")

            TextField("说点什么，或输入文字", text: $draft, axis: .vertical)
                .font(.body)
                .foregroundStyle(WhaleTheme.ink)
                .lineLimit(1...5)
                .frame(minHeight: 44)
                .padding(.horizontal, 4)
                .focused($focused)
                .disabled(voice.isRecording || voice.isFinalizing || finishingVoice)
                .submitLabel(.return)
                .accessibilityLabel("消息草稿")
                .accessibilityIdentifier("assistant-composer")

            if focused {
                micButton
                Button {
                    focused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .whaleFont(size: 19, weight: .semibold)
                        .foregroundStyle(WhaleTheme.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("收起键盘")
            } else {
                micButton
            }

            Button(action: submit) {
                Image(systemName: "paperplane.fill")
                    .whaleFont(size: 16, weight: .semibold)
                    .foregroundStyle(WhaleTheme.buttonInk)
                    .frame(width: 44, height: 44)
                    .background(WhaleTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.whalePress)
            .disabled(model.isBusy || isDraftEmpty || finishingVoice)
            .opacity(model.isBusy || isDraftEmpty ? 0.5 : 1)
            .accessibilityLabel("发送")
            .accessibilityIdentifier("assistant-send")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WhaleTheme.field)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(WhaleTheme.line, lineWidth: 0.7)
                }
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .animation(.easeInOut(duration: 0.16), value: focused)
    }

    private var micButton: some View {
        Button {
            focused = false
            if !voice.isRecording {
                voicePrefix = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                voiceAnalysis = nil
            }
            Task { await voice.toggle() }
        } label: {
            Image(systemName: voice.isRecording ? "waveform" : "mic")
                .whaleFont(size: 19, weight: .medium)
                .foregroundStyle(voice.isRecording ? WhaleTheme.danger : WhaleTheme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isBusy || voice.isFinalizing || finishingVoice)
        .opacity(model.isBusy ? 0.4 : 1)
        .accessibilityLabel(voice.isRecording ? "停止语音输入" : "语音输入")
        .accessibilityHint("轻点开始，按住说话；录音中上滑锁定，左滑取消")
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 48, pressing: { pressing in
            if pressing {
                guard !voice.isRecording else { return }
                let token = UUID()
                longPressToken = token
                longPressArmed = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 380_000_000)
                    guard !Task.isCancelled, longPressToken == token else { return }
                    longPressArmed = true
                    voicePrefix = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    voiceAnalysis = nil
                    focused = false
                    await voice.start()
                }
            } else {
                longPressToken = nil
                if longPressArmed {
                    longPressArmed = false
                    if voice.isRecording { voice.stop() }
                }
            }
        }, perform: {})
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .whaleFont(size: 13)
            .foregroundStyle(WhaleTheme.warm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(WhaleTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(WhaleTheme.line, lineWidth: 0.7)
            }
    }

    private var isDraftEmpty: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var voiceStrip: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(WhaleTheme.danger)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            Text(voice.transcript.isEmpty ? "正在听你说…" : voice.transcript)
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.ink)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("停止") { voice.stop() }
                .whaleFont(size: 13, weight: .semibold)
                .tint(WhaleTheme.danger)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(WhaleTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(WhaleTheme.danger.opacity(0.24), lineWidth: 0.7)
        }
        .overlay(alignment: .bottomLeading) {
            Text(voiceLocked ? "已锁定 · 轻点麦克风结束" : "上滑锁定 · 左滑取消")
                .whaleFont(size: 11, weight: .medium)
                .foregroundStyle(WhaleTheme.muted)
                .padding(.leading, 29)
                .padding(.bottom, 2)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 14)
                .onEnded { value in
                    if value.translation.width < -56 {
                        voice.cancel()
                        voiceAnalysis = nil
                        draft = voicePrefix.isEmpty ? "" : voicePrefix
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    } else if value.translation.height < -48 {
                        voiceLocked = true
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
        )
    }

    private func voiceDraftPreview(_ analysis: VoiceDraftAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "waveform.badge.checkmark")
                    .foregroundStyle(WhaleTheme.accent)
                Text("语音草稿")
                    .whaleFont(size: 13, weight: .bold)
                    .foregroundStyle(WhaleTheme.ink)
                Spacer()
                Text("先检查，再发送")
                    .whaleFont(size: 11, weight: .medium)
                    .foregroundStyle(WhaleTheme.muted)
            }

            HStack(spacing: 6) {
                ForEach(analysis.diagnostics) { diagnostic in
                    Label(diagnostic.value, systemImage: icon(for: diagnostic.id))
                        .whaleFont(size: 11, weight: .medium)
                        .foregroundStyle(WhaleTheme.muted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(WhaleTheme.soft, in: Capsule())
                }
                Spacer(minLength: 0)
            }

            if !analysis.corrections.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(analysis.corrections) { correction in
                        Button {
                            correctingCorrection = correction
                            correctionIntended = correction.replacement
                        } label: {
                            HStack(spacing: 5) {
                            Image(systemName: "text.badge.checkmark")
                                .foregroundStyle(WhaleTheme.accent)
                            Text("\(correction.original) → \(correction.replacement)")
                                .whaleFont(size: 12, weight: .medium)
                                .foregroundStyle(WhaleTheme.ink)
                            Text(correction.reason)
                                .whaleFont(size: 11)
                                .foregroundStyle(WhaleTheme.muted)
                                Spacer(minLength: 0)
                                Image(systemName: "pencil")
                                    .foregroundStyle(WhaleTheme.accent)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("修正 \(correction.original)，当前识别为 \(correction.replacement)")
                    }
                }
                .padding(8)
                .background(WhaleTheme.accentSoft.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if analysis.intents.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("识别到 \(analysis.intents.count) 个意图")
                        .whaleFont(size: 12, weight: .semibold)
                        .foregroundStyle(WhaleTheme.muted)
                    ForEach(Array(analysis.intents.enumerated()), id: \.offset) { index, intent in
                        Text("\(index + 1). \(intent)")
                            .whaleFont(size: 12)
                            .foregroundStyle(WhaleTheme.ink)
                            .lineLimit(2)
                    }
                }
            }

            HStack(spacing: 14) {
                Button("继续编辑") { focused = true }
                    .whaleFont(size: 13, weight: .semibold)
                    .foregroundStyle(WhaleTheme.accent)
                Spacer()
                Button {
                    submit()
                } label: {
                    Label("发送", systemImage: "arrow.up.circle.fill")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.onAccent)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 36)
                        .background(WhaleTheme.auroraGradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(WhaleTheme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(WhaleTheme.accent.opacity(0.22), lineWidth: 0.8)
        }
        .accessibilityElement(children: .contain)
    }

    private func submit() {
        guard !finishingVoice else { return }
        if voice.isRecording || voice.isFinalizing {
            finishingVoice = true
            Task {
                defer { finishingVoice = false }
                guard let final = await voice.finishRecognition(), !final.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    draft = voicePrefix.isEmpty ? voice.transcript : voicePrefix + "\n" + voice.transcript
                    focused = true
                    return
                }
                focused = false
                let composed = voicePrefix.isEmpty ? final : voicePrefix + "\n" + final
                let analysis = VoiceDraftAnalyzer.analyze(
                    composed,
                    engine: voice.engineName,
                    elapsed: voiceStartedAt.map { Date().timeIntervalSince($0) },
                    confidence: voice.confidence
                )
                voiceAnalysis = analysis
                draft = analysis.correctedText
                voicePrefix = ""
                model.setVoiceInteractionPhase(recording: false, editable: true)
                finishingVoice = false
            }
        } else {
            let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            focused = false
            let original = draft
            let context = draftContext
            Task { await sendDraft(text, original: original, context: context) }
        }
    }

    private func sendDraft(_ text: String, original: String, context: String?) async {
        model.setVoiceInteractionPhase(recording: false)
        voiceAnalysis = nil
        await model.send(text: text, onAccepted: {
            // Clear only after the message is accepted into persistent history.
            // Preflight rejection and newer edits must keep their draft intact.
            guard draftContext == context, model.composerContextID == context, draft == original else { return }
            draft = ""
            if let context { drafts.save("", context: context) }
        })
    }

    private func icon(for diagnosticID: String) -> String {
        switch diagnosticID {
        case "engine": return "waveform"
        case "elapsed": return "timer"
        case "intents": return "list.number"
        case "confidence": return "waveform.badge.magnifyingglass"
        default: return "textformat.size"
        }
    }

    private func saveVoiceCorrection() {
        guard let correction = correctingCorrection,
              let analysis = voiceAnalysis else { return }
        PersonalLanguageStore.shared.set(
            spoken: correction.original,
            intended: correctionIntended
        )
        let updated = VoiceDraftAnalyzer.analyze(
            analysis.rawText,
            engine: voice.engineName,
            elapsed: voiceStartedAt.map { Date().timeIntervalSince($0) },
            confidence: voice.confidence
        )
        voiceAnalysis = updated
        draft = updated.correctedText
        correctingCorrection = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func ingestPhoto() async {
        guard let item = photoItem else { return }
        photoItem = nil
        importError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                importError = "没有读到照片数据，请换一张图片。"
                return
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("whale-ocr-\(UUID().uuidString).jpg")
            try data.write(to: url, options: .atomic)
            await model.ingestDocument(url: url, label: "照片")
            try? FileManager.default.removeItem(at: url)
        } catch {
            importError = photoImportMessage(error)
        }
    }

    private func handleImportedFile(_ result: Result<[URL], Error>) {
        importError = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            Task {
                defer {
                    if access { url.stopAccessingSecurityScopedResource() }
                }
                let label = url.pathExtension.lowercased() == "pdf" ? "PDF" : "图片"
                await model.ingestDocument(url: url, label: label)
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func photoImportMessage(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return "照片读取失败：当前网络不可用。若这张照片只存在 iCloud，请先联网下载原图，或改用“从文件识别”选择本机图片。"
        }
        if ns.domain.contains("Photo") || ns.domain.contains("Cloud") {
            return "照片读取失败：\(error.localizedDescription)。请在相册中先下载到本机后重试。"
        }
        return "照片读取失败：\(error.localizedDescription)"
    }
}
