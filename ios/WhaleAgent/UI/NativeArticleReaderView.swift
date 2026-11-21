import SwiftUI
import UIKit

private struct ArticleParagraph: Identifiable, Equatable {
    let index: Int
    let text: String
    var id: Int { index }
}

private struct ArticleHighlight: Identifiable, Equatable {
    let paragraphIndex: Int
    let text: String
    let why: String
    var id: Int { paragraphIndex }
}

private struct CachedArticleBody: Codable {
    let title: String
    let text: String
    let fetchedAt: Date
}

struct NativeArticleReaderView: View {
    let item: NewsItem
    @ObservedObject var library: DiscoverReadingLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var paragraphs: [ArticleParagraph] = []
    @State private var highlights: [ArticleHighlight] = []
    @State private var selectedParagraph: Int?
    @State private var visibleParagraph = 0
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var safari: SafariTarget?

    init(item: NewsItem, library: DiscoverReadingLibrary) {
        self.item = item
        _library = ObservedObject(wrappedValue: library)
        _title = State(initialValue: item.displayTitle)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WhaleBackdrop().ignoresSafeArea()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            readerHeader
                            if isLoading {
                                ProgressView("正在抽取正文…")
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 60)
                            } else if let errorText {
                                failureCard(errorText)
                            } else {
                                if !highlights.isEmpty {
                                    highlightSection(proxy)
                                }
                                ForEach(paragraphs) { paragraph in
                                    paragraphView(paragraph)
                                        .id(paragraph.index)
                                }
                                Button {
                                    finishReading()
                                } label: {
                                    Label("标记读完", systemImage: "checkmark.circle.fill")
                                        .whaleFont(size: 14, weight: .semibold)
                                        .foregroundStyle(WhaleTheme.onAccent)
                                        .frame(maxWidth: .infinity, minHeight: 46)
                                        .background(WhaleTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 36)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("阅读")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("复制正文", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = paragraphs.map(\.text).joined(separator: "\n\n")
                        }
                        if item.url != nil {
                            Button("在 Safari 中打开", systemImage: "safari") {
                                if let url = item.url {
                                    safari = SafariTarget(url: url)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(item: $safari) { target in
            InAppSafari(url: target.url).ignoresSafeArea()
        }
        .task { await load() }
        .onAppear { library.markReading(item) }
    }

    private var readerHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.source)
                .whaleFont(size: 12, weight: .semibold)
                .foregroundStyle(WhaleTheme.accent)
            Text(title)
                .whaleFont(size: 25, weight: .bold, design: .rounded)
                .foregroundStyle(WhaleTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                Text(DiscoverFormat.relative(item.publishedAt))
                Spacer()
                Text("\(Int(readerProgress * 100))%")
            }
            .whaleFont(size: 12, weight: .medium)
            .foregroundStyle(WhaleTheme.muted)
            ProgressView(value: readerProgress)
                .tint(WhaleTheme.accent)
        }
        .whaleCard(padding: 16)
    }

    private func highlightSection(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("三条重点", systemImage: "highlighter")
                .whaleFont(size: 14, weight: .bold)
                .foregroundStyle(WhaleTheme.accent)
            ForEach(highlights) { highlight in
                Button {
                    selectedParagraph = highlight.paragraphIndex
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo(highlight.paragraphIndex, anchor: .center)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(highlight.text)
                            .whaleFont(size: 14, weight: .semibold)
                            .foregroundStyle(WhaleTheme.ink)
                            .multilineTextAlignment(.leading)
                        Text(highlight.why)
                            .whaleFont(size: 12)
                            .foregroundStyle(WhaleTheme.muted)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(WhaleTheme.accentSoft.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func paragraphView(_ paragraph: ArticleParagraph) -> some View {
        Text(paragraph.text)
            .whaleFont(size: 17)
            .lineSpacing(6)
            .foregroundStyle(WhaleTheme.ink)
            .textSelection(.enabled)
            .padding(10)
            .background(
                selectedParagraph == paragraph.index ? WhaleTheme.accent.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .onAppear {
                guard paragraph.index > visibleParagraph else { return }
                visibleParagraph = paragraph.index
                updateProgress()
            }
    }

    private func failureCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("无法抽取正文", systemImage: "doc.text.magnifyingglass")
                .whaleFont(size: 17, weight: .semibold)
                .foregroundStyle(WhaleTheme.ink)
            Text(message)
                .whaleFont(size: 14)
                .foregroundStyle(WhaleTheme.muted)
            Text("鲸鱼没有偷偷跳到浏览器；下面仍保留来源摘要，是否打开 Safari 由你决定。")
                .whaleFont(size: 13)
                .foregroundStyle(WhaleTheme.muted)
            if let summary = item.displaySummary.nilIfEmpty {
                Text(summary)
                    .whaleFont(size: 15)
                    .foregroundStyle(WhaleTheme.ink)
            }
            if let url = item.url {
                Button {
                    safari = SafariTarget(url: url)
                } label: {
                    Label("在 Safari 中打开", systemImage: "safari")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.onAccent)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 40)
                        .background(WhaleTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .whaleCard(padding: 16)
    }

    private var readerProgress: Double {
        if paragraphs.isEmpty { return library.saved.first { $0.id == item.id }?.progress ?? 0 }
        return min(1, Double(visibleParagraph + 1) / Double(max(1, paragraphs.count)))
    }

    private func updateProgress() {
        library.updateProgress(item, progress: readerProgress)
    }

    private func finishReading() {
        visibleParagraph = max(0, paragraphs.count - 1)
        library.markRead(item)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func load() async {
        guard let url = item.url else {
            errorText = "这条资讯没有可读取的原文链接。"
            isLoading = false
            return
        }
        if let cached = DiscoverDiskCache.load(CachedArticleBody.self, key: cacheKey) {
            apply(cached)
            library.markReading(item)
        }
        do {
            let payload = try await WebContentExecutor().fetch(urlString: url.absoluteString, maxChars: 12_000)
            guard let object = payload.objectValue else {
                throw ToolExecutionError(code: "reader_invalid", message: "正文格式无法识别。")
            }
            let text = object.optionalString("text") ?? ""
            guard text.count >= 80 else {
                throw ToolExecutionError(code: "reader_empty", message: "网页没有返回足够正文，可能由登录、脚本或站点限制造成。")
            }
            let cached = CachedArticleBody(
                title: object.optionalString("title") ?? item.displayTitle,
                text: text,
                fetchedAt: Date()
            )
            DiscoverDiskCache.save(cached, key: cacheKey)
            apply(cached)
            library.markReading(item)
        } catch {
            if paragraphs.isEmpty { errorText = error.localizedDescription }
        }
        isLoading = false
    }

    private func apply(_ cached: CachedArticleBody) {
        title = cached.title.nilIfEmpty ?? item.displayTitle
        paragraphs = Self.makeParagraphs(cached.text)
        highlights = Self.makeHighlights(paragraphs)
        errorText = nil
        isLoading = false
    }

    private var cacheKey: String { "reader-v2-\(item.id)" }

    private static func makeParagraphs(_ text: String) -> [ArticleParagraph] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 24 }
            .enumerated()
            .map { ArticleParagraph(index: $0.offset, text: $0.element) }
    }

    private static func makeHighlights(_ paragraphs: [ArticleParagraph]) -> [ArticleHighlight] {
        let scored = paragraphs.map { paragraph -> (ArticleParagraph, Int) in
            var score = 0
            if paragraph.text.contains(where: { $0.isNumber }) { score += 3 }
            for marker in ["因为", "因此", "结果", "宣布", "增长", "下降", "风险", "计划", "发布"] where paragraph.text.contains(marker) {
                score += 1
            }
            score += min(3, paragraph.text.count / 180)
            return (paragraph, score)
        }.sorted { $0.1 == $1.1 ? $0.0.index < $1.0.index : $0.1 > $1.1 }.prefix(3)
        return scored.map { paragraph, _ in
            let hasNumbers = paragraph.text.contains(where: { $0.isNumber })
            let why = hasNumbers
                ? "这里包含可回到正文核对的数据或时间。"
                : "这一段给出了正文的核心事实或结论。"
            return ArticleHighlight(
                paragraphIndex: paragraph.index,
                text: String(firstSentence(paragraph.text).prefix(180)),
                why: why
            )
        }.sorted { $0.paragraphIndex < $1.paragraphIndex }
    }

    private static func firstSentence(_ text: String) -> String {
        for separator in ["。", "！", "？", "；"] {
            if let index = text.firstIndex(of: Character(separator)) {
                return String(text[...index])
            }
        }
        return text
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
