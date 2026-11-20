import SwiftUI
import UIKit

struct DiscoverLibraryView: View {
    @ObservedObject var library: DiscoverReadingLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var safari: SafariTarget?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if library.saved.isEmpty {
                    ContentUnavailableView(
                        "还没有收藏",
                        systemImage: "bookmark",
                        description: Text("在资讯详情里点书签，文章会保存在这里，稍后继续读。")
                    )
                } else {
                    List {
                        ForEach(library.saved) { article in
                            Button {
                                open(article)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(article.title)
                                        .font(.headline)
                                        .foregroundStyle(WhaleTheme.ink)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                    HStack(spacing: 6) {
                                        Text(article.source)
                                        Text("·")
                                        Text(article.savedAt.formatted(.relative(presentation: .named)))
                                        if article.isReadLater {
                                            Text("稍后读")
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(WhaleTheme.accentSoft, in: Capsule())
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(WhaleTheme.muted)
                                }
                                .padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(WhaleTheme.card)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    remove(article)
                                } label: {
                                    Label("移除", systemImage: "bookmark.slash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(WhaleBackdrop())
                }
            }
            .tint(WhaleTheme.accent)
            .navigationTitle("收藏与稍后读")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $safari) { target in
                InAppSafari(url: target.url)
                    .ignoresSafeArea()
            }
            .alert("无法打开原文", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func open(_ article: SavedArticle) {
        guard let url = URL(string: article.link), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            errorText = "这条收藏没有可用的原文链接。"
            return
        }
        safari = SafariTarget(url: url)
    }

    private func remove(_ article: SavedArticle) {
        let placeholder = NewsItem(
            id: article.id,
            title: article.title,
            summary: article.summary,
            source: article.source,
            link: article.link,
            publishedAt: nil,
            channel: article.channel,
            rank: nil
        )
        library.toggleSaved(placeholder)
    }
}
