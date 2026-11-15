import SwiftUI

struct GameBoardView: View {
    let game: GameDigest

    @State private var section: GameSection = .news
    @State private var selectedArticle: NewsArticle?
    @State private var selectedGame: GameRankItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(GameSection.allCases) { item in
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                section = item
                            }
                        } label: {
                            Text(item.rawValue)
                                .font(.nomiScaled(size: 10.5, weight: .semibold))
                                .foregroundStyle(section == item ? CardPalette.navyInk : CardPalette.subtle)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 44)
                                .background(section == item ? CardPalette.rose : CardPalette.surface)
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule().stroke(CardPalette.line, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)

            sectionContent
        }
        .fullScreenCover(item: $selectedArticle) { article in
            NewsArticleReader(article: article)
        }
        .fullScreenCover(item: $selectedGame) { game in
            GameDetailView(item: game)
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .news:
            articleList(game.news, error: game.failures[.news])
        case .steam:
            rankList(game.steamTop, error: game.failures[.steam])
        case .coming:
            rankList(game.steamComing, error: game.failures[.coming])
        case .free:
            rankList(game.iosFree, error: game.failures[.free])
        case .grossing:
            rankList(game.iosGrossing, error: game.failures[.grossing])
        }
    }

    @ViewBuilder
    private func articleList(_ articles: [NewsArticle], error: String?) -> some View {
        if articles.isEmpty {
            unavailable(error ?? "游戏新闻暂时没有拿到", symbol: "newspaper")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                    Button {
                        selectedArticle = article
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(CardPalette.accent.opacity(0.8))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(.nomiScaled(size: 13.5, weight: .medium))
                                    .foregroundStyle(CardPalette.ink)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)
                                Text(meta(article))
                                    .font(.nomiScaled(size: 9.5))
                                    .foregroundStyle(CardPalette.faint)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.nomiScaled(size: 9))
                                .foregroundStyle(CardPalette.faint)
                                .padding(.top, 3)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(WhalePressStyle(scale: 0.99))

                    if index < articles.count - 1 {
                        WhaleRowDivider(leading: 42)
                    }
                }
            }
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private func rankList(_ items: [GameRankItem], error: String?) -> some View {
        if items.isEmpty {
            unavailable(error ?? "当前榜单暂时没有拿到", symbol: "trophy")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        selectedGame = item
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(item.rank)")
                                .font(.nomiScaled(size: 11.5, weight: .bold))
                                .foregroundStyle(item.rank <= 3 ? CardPalette.ink : CardPalette.faint)
                                .monospacedDigit()
                                .frame(width: 22, alignment: .leading)

                            artwork(item, size: 42)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.nomiScaled(size: 13.5, weight: .semibold))
                                    .foregroundStyle(CardPalette.ink)
                                    .lineLimit(1)
                                Text(item.subtitle)
                                    .font(.nomiScaled(size: 9.5))
                                    .foregroundStyle(CardPalette.faint)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 4)

                            Text(item.priceText)
                                .font(.nomiScaled(size: 10, weight: .semibold))
                                .foregroundStyle(CardPalette.subtle)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(WhalePressStyle(scale: 0.99))

                    if index < items.count - 1 {
                        WhaleRowDivider(leading: 86)
                    }
                }
            }
            .background(CardPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            }
        }
    }

    private func artwork(_ item: GameRankItem, size: CGFloat) -> some View {
        AsyncImage(url: item.artworkURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                CardPalette.raised
                    .overlay {
                        Image(systemName: "gamecontroller")
                            .foregroundStyle(CardPalette.accent)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func unavailable(_ text: String, symbol: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.nomiScaled(size: 24, weight: .semibold))
            Text(text)
                .font(.nomiScaled(size: 11.5))
                .lineSpacing(2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(CardPalette.subtle)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func meta(_ article: NewsArticle) -> String {
        var parts = [article.source]
        if let date = article.publishedAt {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 HH:mm"
            parts.append(formatter.string(from: date))
        }
        return parts.joined(separator: " · ")
    }
}

private struct GameDetailView: View {
    let item: GameRankItem

    @Environment(\.dismiss) private var dismiss
    @State private var showStore = false
    @State private var detail: GameDetailRecord?
    @State private var detailError: String?
    @State private var loadingDetail = true

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.nomiScaled(size: 13, weight: .semibold))
                            .foregroundStyle(CardPalette.ink)
                    .frame(width: 44, height: 44)
                            .background(CardPalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(WhalePressStyle())
                    .accessibilityLabel("关闭游戏详情")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            AsyncImage(url: item.artworkURL) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    CardPalette.raised
                                        .overlay {
                                            Image(systemName: "gamecontroller")
                                                .font(.nomiScaled(size: 28))
                                                .foregroundStyle(CardPalette.accent)
                                        }
                                }
                            }
                            .frame(width: 110, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.name)
                                    .font(.nomiScaled(size: 23, weight: .bold))
                                    .foregroundStyle(CardPalette.ink)
                                    .lineLimit(3)
                                Text("\(item.source) · 第 \(item.rank) 名")
                                    .font(.nomiScaled(size: 10.5))
                                    .foregroundStyle(CardPalette.subtle)
                                Text(item.platform)
                                    .font(.nomiScaled(size: 9.5, weight: .semibold))
                                    .foregroundStyle(CardPalette.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(CardPalette.accent.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        if loadingDetail {
                            HStack(spacing: 8) {
                                ProgressView().tint(CardPalette.accent)
                                Text("正在读取游戏资料")
                                    .font(.nomiScaled(size: 11.5))
                                    .foregroundStyle(CardPalette.subtle)
                            }
                            .padding(.vertical, 8)
                        } else if let detail {
                            if !detail.screenshots.isEmpty {
                                VStack(alignment: .leading, spacing: 9) {
                                    Text("游戏截图")
                                        .font(.nomiScaled(size: 14, weight: .bold))
                                        .foregroundStyle(CardPalette.ink)
                                    ScrollView(.horizontal) {
                                        HStack(spacing: 9) {
                                            ForEach(detail.screenshots, id: \.absoluteString) { url in
                                                AsyncImage(url: url) { phase in
                                                    if let image = phase.image {
                                                        image.resizable()
                                                            .scaledToFit()
                                                            .padding(6)
                                                    } else {
                                                        CardPalette.raised
                                                    }
                                                }
                                                .frame(width: 190, height: 250)
                                                .background(CardPalette.raised)
                                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                            }
                                        }
                                    }
                                    .scrollIndicators(.hidden)
                                }
                            }

                            if !detail.description.isEmpty {
                                WhaleGlassCard(radius: 18, padding: 14) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("游戏介绍")
                                            .font(.nomiScaled(size: 14, weight: .bold))
                                            .foregroundStyle(CardPalette.ink)
                                        Text(detail.description)
                                            .font(.nomiScaled(size: 11.5))
                                            .foregroundStyle(CardPalette.subtle)
                                            .lineSpacing(3)
                                    }
                                }
                            }

                            applicationInfo(detail)
                        } else {
                            unavailable(detailError ?? "游戏资料暂时没有拿到")
                        }

                        WhaleGlassCard(radius: 18, padding: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("价格")
                                    .font(.nomiScaled(size: 10))
                                    .foregroundStyle(CardPalette.subtle)
                                Text(item.priceText)
                                    .font(.nomiScaled(size: 18, weight: .bold))
                                    .foregroundStyle(CardPalette.ink)
                                Text(item.subtitle)
                                    .font(.nomiScaled(size: 11.5))
                                    .foregroundStyle(CardPalette.subtle)
                                    .lineSpacing(2)
                            }
                        }

                        if item.storeURL != nil {
                            Button {
                                showStore = true
                            } label: {
                                Label("在 Nomi 内查看商店页面", systemImage: "chevron.right")
                                    .font(.nomiScaled(size: 13, weight: .semibold))
                                    .foregroundStyle(CardPalette.navyInk)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(CardPalette.accent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(WhalePressStyle())
                        }

                        Text("榜单和价格来自公开商店接口，可能随时间变化。")
                            .font(.nomiScaled(size: 9.5))
                            .foregroundStyle(CardPalette.faint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
        .fullScreenCover(isPresented: $showStore) {
            if let url = item.storeURL {
                NewsArticleReader(title: item.name, source: item.source, link: url)
            }
        }
        .task {
            switch await GameDetailService.load(item) {
            case .success(let value):
                detail = value
            case .failure:
                detailError = "游戏资料暂时没有拿到，榜单排名和商店入口仍可使用。"
            }
            loadingDetail = false
        }
        .nomiEdgeDismiss()
    }

    private func applicationInfo(_ detail: GameDetailRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("应用资料")
                .font(.nomiScaled(size: 14, weight: .bold))
                .foregroundStyle(CardPalette.ink)

            infoRow("开发商", detail.developer)
            infoRow("发行商", detail.publisher)
            infoRow("类型", detail.genres.joined(separator: "、"))
            infoRow("发行日期", detail.releaseDate)
            if let rating = detail.rating {
                let count = detail.ratingCount.map { "（\($0) 人）" } ?? ""
                infoRow("评分", String(format: "%.1f", rating) + count)
            }
            infoRow("版本", detail.version)
        }
        .padding(14)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.nomiScaled(size: 10.5))
                .foregroundStyle(CardPalette.faint)
                .frame(width: 54, alignment: .leading)
            Text(value.isEmpty ? "暂无" : value)
                .font(.nomiScaled(size: 11.5))
                .foregroundStyle(CardPalette.subtle)
                .lineSpacing(2)
        }
    }

    private func unavailable(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .foregroundStyle(CardPalette.amber)
            Text(text)
                .font(.nomiScaled(size: 11))
                .foregroundStyle(CardPalette.subtle)
                .lineSpacing(2)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

