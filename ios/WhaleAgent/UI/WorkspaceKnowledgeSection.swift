import SwiftUI
import UIKit

struct WorkspaceKnowledgeSection: View {
    @ObservedObject var store: WhaleWorkspaceStore
    let onSelect: (WorkspaceCapture) -> Void
    let onAsk: (String) -> Void
    @State private var query = ""

    private var results: [WorkspaceCapture] {
        store.searchKnowledge(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Label("私人知识库", systemImage: "books.vertical.fill")
                    .whaleFont(size: 19, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                Text("回答只使用本机保存的内容。检索结果会显示标题、摘要和原始来源，不把命中的资料说成模型推理。")
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.muted)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(WhaleTheme.muted)
                    TextField("问我以前保存了什么", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(WhaleTheme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(WhaleTheme.field, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Text(query.isEmpty ? "直接输入关键词，或先浏览全部条目。" : "找到 \(results.count) 条本机资料")
                    .whaleFont(size: 11, weight: .medium)
                    .foregroundStyle(WhaleTheme.muted)
                if !query.isEmpty && !results.isEmpty {
                    Button {
                        onAsk(questionPrompt)
                    } label: {
                        Label("带着这些真实来源问鲸鱼", systemImage: "sparkles")
                            .whaleFont(size: 13, weight: .semibold)
                            .foregroundStyle(WhaleTheme.onAccent)
                            .padding(.horizontal, 13)
                            .frame(minHeight: 38)
                            .background(WhaleTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .whaleCard(padding: 16)

            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: query.isEmpty ? "books.vertical" : "magnifyingglass")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(WhaleTheme.muted)
                    Text(query.isEmpty ? "还没有知识条目" : "没有找到匹配资料")
                        .whaleFont(size: 16, weight: .semibold)
                        .foregroundStyle(WhaleTheme.ink)
                    Text(query.isEmpty ? "在收件箱详情里打开“保存到知识库”。" : "换一个关键词，或确认资料是否已经保存。")
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(WhaleTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(results) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(item.kind.title, systemImage: item.kind.icon)
                                    .whaleFont(size: 11, weight: .semibold)
                                    .foregroundStyle(WhaleTheme.accent)
                                Spacer()
                                Text(item.updatedAt.formatted(.relative(presentation: .named)))
                                    .whaleFont(size: 11)
                                    .foregroundStyle(WhaleTheme.muted)
                            }
                            Text(item.title)
                                .whaleFont(size: 16, weight: .semibold)
                                .foregroundStyle(WhaleTheme.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(snippet(for: item))
                                .whaleFont(size: 13)
                                .foregroundStyle(WhaleTheme.muted)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                            if let source = item.sourceURL, !source.isEmpty {
                                Text(source)
                                    .whaleFont(size: 11)
                                    .foregroundStyle(WhaleTheme.accent)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .whaleCard(padding: 14)
                    }
                    .buttonStyle(.whalePress)
                }
            }
        }
    }

    private func snippet(for item: WorkspaceCapture) -> String {
        let source = item.body.replacingOccurrences(of: "\n", with: " ")
        guard !query.isEmpty, let range = source.range(of: query, options: .caseInsensitive) else {
            return String(source.prefix(160))
        }
        let lower = source.index(range.lowerBound, offsetBy: -40, limitedBy: source.startIndex) ?? source.startIndex
        let upper = source.index(range.upperBound, offsetBy: 100, limitedBy: source.endIndex) ?? source.endIndex
        return String(source[lower..<upper])
    }

    private var questionPrompt: String {
        let sources = results.prefix(3).map { item in
            """
            【\(item.title)】
            \(String(item.body.prefix(900)))
            来源：\(item.sourceURL ?? "本机记录")
            """
        }.joined(separator: "\n\n")
        return """
        请只根据下面保存的本机资料回答“\(query)”。
        如果资料不足，请直接说明不足，不要补写。回答末尾逐条列出实际使用的标题和来源。

        \(sources)
        """
    }
}

