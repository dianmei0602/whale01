import SwiftUI
import UIKit

struct DiscoverLibraryView: View {
    @ObservedObject var library: DiscoverReadingLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var readerArticle: SavedArticle?
    @State private var recentlyRemoved: SavedArticle?

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
                                        Text(article.status.title)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(WhaleTheme.accentSoft, in: Capsule())
                                        Text("\(Int(article.progress * 100))%")
                                            .foregroundStyle(WhaleTheme.muted)
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
            .sheet(item: $readerArticle) { article in
                NativeArticleReaderView(item: newsItem(for: article), library: library)
            }
            .safeAreaInset(edge: .bottom) {
                if let recentlyRemoved {
                    HStack(spacing: 10) {
                        Text("已移出稍后读")
                            .font(.subheadline)
                            .foregroundStyle(WhaleTheme.ink)
                        Spacer()
                        Button("撤销") {
                            restore(recentlyRemoved)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WhaleTheme.accent)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(WhaleTheme.card)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(WhaleTheme.line)
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    private func open(_ article: SavedArticle) {
        readerArticle = article
    }

    private func newsItem(for article: SavedArticle) -> NewsItem {
        NewsItem(
            id: article.id,
            title: article.title,
            summary: article.summary,
            source: article.source,
            link: article.link,
            publishedAt: nil,
            channel: article.channel,
            rank: nil
        )
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
        guard library.isSaved(placeholder) else { return }
        library.toggleSaved(placeholder)
        recentlyRemoved = article
        WhaleAccessibility.announce("已移出稍后读，可以撤销")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if recentlyRemoved?.id == article.id {
                recentlyRemoved = nil
            }
        }
    }

    private func restore(_ article: SavedArticle) {
        let placeholder = newsItem(for: article)
        if !library.isSaved(placeholder) {
            library.toggleSaved(placeholder)
        }
        recentlyRemoved = nil
        WhaleAccessibility.announce("已恢复到稍后读")
    }
}
