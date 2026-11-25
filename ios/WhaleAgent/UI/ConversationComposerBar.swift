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
    @FocusState private var focused: Bool

    @Binding var draft: String
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var finishingVoice = false
    @State private var draftContext: String?
    @State private var showVoiceSheet = false
    @State private var voiceDraftPrefix = ""
    @State private var voiceContext: String?
    @Environment(\.scenePhase) private var scenePhase
    private let drafts = ComposerDraftStore()

    var body: some View {
        VStack(spacing: 7) {
            if let importError {
                notice(importError)
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
        .onChange(of: focused) { _, value in
            externalFocused = value
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
            if phase != .active, let context = draftContext { drafts.save(draft, context: context) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .whalePrefillDraft)) { notification in
            guard let text = notification.userInfo?["text"] as? String else { return }
            draft = draft.isEmpty ? text : draft + "\n" + text
            focused = true
        }
        .onDisappear {
            if let context = draftContext { drafts.save(draft, context: context) }
            externalFocused = false
        }
        .sheet(isPresented: $showVoiceSheet) {
            WhaleVoiceInputSheet(
                onSend: sendVoiceText,
                onUseText: useVoiceText,
                onCancel: {
                    showVoiceSheet = false
                    focused = false
                }
            )
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
                .disabled(finishingVoice)
                .submitLabel(.return)
                .accessibilityLabel("消息草稿")
                .accessibilityIdentifier("assistant-composer")

            if focused {
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
                Button {
                    focused = false
                    voiceDraftPrefix = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    voiceContext = draftContext
                    showVoiceSheet = true
                } label: {
                    Image(systemName: "mic")
                        .whaleFont(size: 19, weight: .medium)
                        .foregroundStyle(WhaleTheme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(model.isBusy || finishingVoice)
                .opacity(model.isBusy ? 0.4 : 1)
                .accessibilityLabel("语音输入")
                .accessibilityIdentifier("open-voice-sheet")
            }

            Button(action: submit) {
                Image(systemName: "paperplane.fill")
                    .whaleFont(size: 16, weight: .semibold)
                    .foregroundStyle(WhaleTheme.buttonInk)
                    .frame(width: 44, height: 44)
                    .background(WhaleTheme.composerSendGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .whaleSoftElevation(selected: true)
            }
            .buttonStyle(.plain)
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
                        .strokeBorder(WhaleTheme.line, lineWidth: 0.8)
                }
        }
        .animation(.easeInOut(duration: 0.16), value: focused)
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .whaleFont(size: 13)
            .foregroundStyle(WhaleTheme.warm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(WhaleTheme.glassStroke, lineWidth: 0.8)
            }
    }

    private var isDraftEmpty: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard !finishingVoice else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        focused = false
        let original = draft
        let context = draftContext
        Task { await sendDraft(text, original: original, context: context) }
    }

    private func sendDraft(_ text: String, original: String, context: String?) async {
        await model.send(text: text, onAccepted: {
            // Clear only after the message is accepted into persistent history.
            // Preflight rejection and newer edits must keep their draft intact.
            guard draftContext == context, model.composerContextID == context, draft == original else { return }
            draft = ""
            if let context { drafts.save("", context: context) }
        })
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

    private func composedVoiceText(_ text: String) -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return voiceDraftPrefix.isEmpty ? text : voiceDraftPrefix + "\n" + text
    }

    private func sendVoiceText(_ text: String) {
        let composed = composedVoiceText(text)
        guard !composed.isEmpty else { return }
        showVoiceSheet = false
        draft = composed
        let context = voiceContext
        finishingVoice = true
        Task {
            await sendDraft(composed, original: composed, context: context)
            finishingVoice = false
        }
    }

    private func useVoiceText(_ text: String) {
        let composed = composedVoiceText(text)
        showVoiceSheet = false
        draft = composed
        focused = !composed.isEmpty
    }
}
