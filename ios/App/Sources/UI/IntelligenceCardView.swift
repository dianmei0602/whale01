import SwiftUI

struct IntelligenceCardView: View {
    let digest: IntelligenceDigest
    var initialModule: IntelligenceModule = .news

    @State private var showDetails = false

    var body: some View {
        WhaleGlassCard(radius: 22, padding: 15, tint: CardPalette.accent) {
            VStack(alignment: .leading, spacing: 13) {
                header

                if !digest.market.isEmpty {
                    marketStrip
                }

                if let topic = digest.trends.first {
                    summaryRow(
                        module: .weibo,
                        title: topic.title,
                        meta: "微博热搜 · \(topic.heatText)"
                    )
                }

                if let topic = digest.zhihu.first {
                    summaryRow(
                        module: .zhihu,
                        title: topic.title,
                        meta: "知乎热榜 · \(topic.heatText)"
                    )
                }

                if let article = digest.news.first {
                    summaryRow(
                        module: .news,
                        title: article.title,
                        meta: article.source
                    )
                }

                if let article = digest.ai.first {
                    summaryRow(
                        module: .ai,
                        title: article.title,
                        meta: article.source
                    )
                }

                if let game = digest.game.steamTop.first {
                    summaryRow(
                        module: .game,
                        title: game.name,
                        meta: "Steam · 第 \(game.rank) 名"
                    )
                } else if let article = digest.game.news.first {
                    summaryRow(
                        module: .game,
                        title: article.title,
                        meta: "游戏新闻 · \(article.source)"
                    )
                }

                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.nomiScaled(size: 9))
                    Text("更新于 \(timeText) · 点击查看全部")
                        .font(.nomiScaled(size: 9.5))
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right")
                        .font(.nomiScaled(size: 9, weight: .semibold))
                }
                .foregroundStyle(CardPalette.faint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetails = true }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("打开六个信息板块")
        .fullScreenCover(isPresented: $showDetails) {
            IntelligenceCenterView(
                digest: digest,
                initialModule: initialModule,
                onClose: { showDetails = false }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            WhaleIconTile(symbol: "newspaper", color: CardPalette.accent, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("今天值得知道")
                    .font(.nomiScaled(size: 17, weight: .bold))
                    .foregroundStyle(CardPalette.ink)
                Text("时事、AI、行情、微博、知乎、游戏")
                    .font(.nomiScaled(size: 10))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.nomiScaled(size: 10, weight: .semibold))
                .foregroundStyle(CardPalette.faint)
        }
    }

    private var marketStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(digest.market.prefix(4))) { quote in
                VStack(alignment: .leading, spacing: 3) {
                    Text(shortMarketName(quote.name))
                        .font(.nomiScaled(size: 9.5, weight: .medium))
                        .foregroundStyle(CardPalette.subtle)
                        .lineLimit(1)
                    Text(quote.percentText)
                        .font(.nomiScaled(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(stockColor(quote))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(CardPalette.raised)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func summaryRow(
        module: IntelligenceModule,
        title: String,
        meta: String
    ) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: module.symbol)
                .font(.nomiScaled(size: 10.5, weight: .semibold))
                .foregroundStyle(moduleColor(module))
                .frame(width: 17, height: 17)
                .background(moduleColor(module).opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.nomiScaled(size: 12.5, weight: .medium))
                    .foregroundStyle(CardPalette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(meta)
                    .font(.nomiScaled(size: 9.5))
                    .foregroundStyle(CardPalette.faint)
                    .lineLimit(1)
            }
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: digest.lastSuccess(for: initialModule) ?? digest.fetchedAt)
    }

    private func shortMarketName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "指数", with: "")
            .replacingOccurrences(of: "成指", with: "")
    }

    private func stockColor(_ quote: StockQuote) -> Color {
        if quote.isRise { return CardPalette.rose }
        if quote.isFall { return CardPalette.success }
        return CardPalette.subtle
    }

    private func moduleColor(_ module: IntelligenceModule) -> Color {
        _ = module
        return CardPalette.accent
    }
}

