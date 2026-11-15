import SwiftUI

private enum CurrentAffairsFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case domestic = "国内"
    case international = "国际"
    case economy = "经济"
    case automotive = "汽车"
    case technology = "科技"

    var id: String { rawValue }

    func matches(_ article: NewsArticle) -> Bool {
        switch self {
        case .all: return true
        case .domestic: return article.category == .domestic
        case .international: return article.category == .international
        case .economy: return article.category == .economy
        case .automotive: return article.category == .automotive
        case .technology: return article.category == .technology
        }
    }
}

struct IntelligenceCenterView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var digest: IntelligenceDigest
    @State private var selectedModule: IntelligenceModule
    @State private var selectedArticle: NewsArticle?
    @State private var selectedTopic: TrendingTopic?
    @State private var selectedStock: StockQuote?
    @State private var currentAffairsFilter: CurrentAffairsFilter = .all
    @State private var showStockSearch = false
    @State private var refreshingMarket = false
    @State private var marketError: String?
    @State private var loadingModules: Set<IntelligenceModule> = []
    @State private var requestIDs: [IntelligenceModule: UUID] = [:]
    @State private var topicSource = ""
    private let onClose: (() -> Void)?

    init(
        digest: IntelligenceDigest,
        initialModule: IntelligenceModule = .news,
        onClose: (() -> Void)? = nil
    ) {
        _digest = State(initialValue: digest)
        _selectedModule = State(initialValue: initialModule)
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if onClose != nil {
                centerContent
                    .nomiEdgeDismiss()
            } else {
                centerContent
            }
        }
        .fullScreenCover(item: $selectedArticle) { article in
            NewsArticleReader(article: article)
        }
        .fullScreenCover(item: $selectedTopic) { topic in
            NewsArticleReader(
                title: topic.title,
                source: "\(topicSource) · \(topic.heatText)",
                link: topic.link
            )
        }
        .fullScreenCover(item: $selectedStock) { quote in
            StockDetailView(quote: quote)
        }
        .sheet(isPresented: $showStockSearch) {
            StockSearchSheet(existingIDs: Set(watchlist.map(\.id))) { symbol in
                guard StockWatchlistStore.add(symbol) else { return false }
                Task { await reloadMarket() }
                return true
            }
            .presentationDetents([.medium, .large])
        }
        .task(id: selectedModule) {
            await loadModuleIfNeeded(selectedModule)
        }
        .task(id: shouldPollMarket) {
            await pollMarketWhileVisible()
        }
        .sensoryFeedback(.selection, trigger: selectedModule)
    }

    private var centerContent: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                topBar
                modulePicker

                if onClose == nil {
                    // 作为底部主入口时，把横滑留给 RootView 的主页面切换。
                    modulePage(selectedModule)
                        .id(selectedModule)
                } else {
                    TabView(selection: $selectedModule) {
                        ForEach(IntelligenceModule.allCases) { module in
                            modulePage(module)
                                .tag(module)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.nomiScaled(size: 14, weight: .semibold))
                        .foregroundStyle(CardPalette.ink)
                        .frame(width: 44, height: 44)
                        .background(CardPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(WhalePressStyle())
                .accessibilityLabel("返回 Nomi")
            } else {
                Image("NomiHeaderBust")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("今天值得知道")
                    .font(.nomiScaled(size: 21, weight: .bold))
                    .foregroundStyle(CardPalette.ink)
                Text(freshnessLabel)
                    .font(.nomiScaled(size: 10))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(CardPalette.chrome.opacity(0.88))
        .overlay(alignment: .bottom) {
            Rectangle().fill(CardPalette.line).frame(height: 0.6)
        }
    }

    private var modulePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 20) {
                ForEach(IntelligenceModule.allCases) { module in
                    Button {
                        withAnimation(.easeOut(duration: 0.20)) {
                            selectedModule = module
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Text(module.rawValue)
                                .font(.nomiScaled(
                                    size: 13.5,
                                    weight: selectedModule == module ? .semibold : .medium
                                ))
                                .foregroundStyle(
                                    selectedModule == module ? CardPalette.ink : CardPalette.subtle
                                )

                            Capsule()
                                .fill(selectedModule == module ? CardPalette.accent : Color.clear)
                                .frame(width: 22, height: 2)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(module.pageTitle)
                    .accessibilityAddTraits(selectedModule == module ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .background(CardPalette.chrome.opacity(0.90))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CardPalette.line)
                .frame(height: 0.6)
        }
    }

    private func modulePage(_ module: IntelligenceModule) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isModuleEmpty(module) && (loadingModules.contains(module) || digest.failures[module] == nil) {
                    loadingCard(for: module)
                } else {
                    moduleBody(module)
                }
                footer(for: module)
            }
            .padding(.horizontal, 17)
            .padding(.top, 14)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await refreshModule(module)
        }
    }

    private func intro(for module: IntelligenceModule) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: module.symbol)
                .font(.nomiScaled(size: 12, weight: .semibold))
                .foregroundStyle(moduleColor(module))
                .frame(width: 28, height: 28)
                .background(moduleColor(module).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(module.pageTitle)
                    .font(.nomiScaled(size: 14, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                Text(introText(for: module))
                    .font(.nomiScaled(size: 10.5))
                    .foregroundStyle(CardPalette.subtle)
                    .lineSpacing(2)
            }
        }
    }

    @ViewBuilder
    private func moduleContent(for module: IntelligenceModule) -> some View {
        switch module {
        case .news:
            newsContent
        case .market:
            marketContent
        case .weibo:
            trendingContent(digest.trends, module: .weibo)
        case .zhihu:
            trendingContent(digest.zhihu, module: .zhihu)
        case .game:
            GameBoardView(game: digest.game)
        case .ai:
            articleContent(digest.ai, module: .ai)
        }
    }

    @ViewBuilder
    private var newsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(CurrentAffairsFilter.allCases) { filter in
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                currentAffairsFilter = filter
                            }
                        } label: {
                            Text(filter.rawValue)
                                .font(.nomiScaled(size: 10.5, weight: .semibold))
                                .foregroundStyle(currentAffairsFilter == filter ? CardPalette.navyInk : CardPalette.subtle)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 44)
                                .background(currentAffairsFilter == filter ? CardPalette.accent : CardPalette.surface)
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

            if filteredNews.isEmpty {
                failureCard(
                    currentAffairsFilter == .all
                        ? (digest.failures[.news] ?? "时事新闻暂时没有拿到")
                        : "当前分类暂时没有新的\(currentAffairsFilter.rawValue)新闻"
                )
            } else {
                articleContent(filteredNews, module: .news)
            }
        }
    }

    private var filteredNews: [NewsArticle] {
        digest.news.filter { currentAffairsFilter.matches($0) }
    }

    @ViewBuilder
    private func articleContent(_ articles: [NewsArticle], module: IntelligenceModule) -> some View {
        if articles.isEmpty {
            failureCard(digest.failures[module] ?? "暂时没有拿到内容")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                    Button {
                        selectedArticle = article
                    } label: {
                        articleRow(article, module: module)
                    }
                    .buttonStyle(WhalePressStyle(scale: 0.99))

                    if index < articles.count - 1 {
                        WhaleRowDivider(leading: 12)
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

    private func articleRow(_ article: NewsArticle, module: IntelligenceModule) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(moduleColor(module).opacity(0.8))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 5) {
                Text(article.title)
                    .font(.nomiScaled(size: 14, weight: .medium))
                    .foregroundStyle(CardPalette.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Text(articleMeta(article))
                    .font(.nomiScaled(size: 9.5))
                    .foregroundStyle(CardPalette.faint)
            }

            Spacer(minLength: 5)

            Image(systemName: "chevron.right")
                .font(.nomiScaled(size: 9.5, weight: .semibold))
                .foregroundStyle(CardPalette.faint)
                .padding(.top, 3)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var marketContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("主要指数")
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundStyle(CardPalette.subtle)
                Spacer()
                Button {
                    Task { await reloadMarket() }
                } label: {
                    HStack(spacing: 5) {
                        if refreshingMarket {
                            ProgressView().scaleEffect(0.65).tint(CardPalette.accent)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("刷新")
                    }
                    .font(.nomiScaled(size: 10.5, weight: .semibold))
                    .foregroundStyle(CardPalette.accent)
                }
                .buttonStyle(.plain)
                .disabled(refreshingMarket)
            }

            if indexQuotes.isEmpty {
                failureCard(marketError ?? "主要指数暂时没有拿到，请稍后刷新。")
            } else {
                quoteGroup(indexQuotes)
            }

            HStack {
                Text("我的自选")
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundStyle(CardPalette.subtle)
                Spacer()
                Button {
                    showStockSearch = true
                } label: {
                    Label("添加", systemImage: "plus")
                        .font(.nomiScaled(size: 10.5, weight: .semibold))
                        .foregroundStyle(CardPalette.accent)
                }
                .buttonStyle(.plain)
                .disabled(watchlist.count >= StockWatchlistStore.limit)
            }

            if watchlistQuotes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.nomiScaled(size: 24, weight: .semibold))
                    Text(watchlist.isEmpty ? "还没有自选股" : "自选行情暂时没拿到")
                        .font(.nomiScaled(size: 12, weight: .medium))
                    if watchlist.isEmpty {
                        Text("添加公司后可在这里查看价格变化")
                            .font(.nomiScaled(size: 10))
                    }
                }
                .foregroundStyle(CardPalette.subtle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(CardPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                quoteGroup(watchlistQuotes, removable: true)
            }

            if let marketError, !indexQuotes.isEmpty {
                failureCard(marketError)
            }

            Text("行情来自公开数据接口，可能延迟；仅供参考，不构成投资建议。")
                .font(.nomiScaled(size: 9.5))
                .foregroundStyle(CardPalette.faint)
                .lineSpacing(2)
        }
    }

    private func quoteGroup(_ quotes: [StockQuote], removable: Bool = false) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(quotes.enumerated()), id: \.element.id) { index, quote in
                HStack(spacing: 9) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(quote.name)
                            .font(.nomiScaled(size: 14, weight: .semibold))
                            .foregroundStyle(CardPalette.ink)
                            .lineLimit(1)
                        Text(quote.code)
                            .font(.nomiScaled(size: 9.5))
                            .foregroundStyle(CardPalette.faint)
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(StockDisplay.priceText(quote.price))
                            .font(.nomiScaled(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(CardPalette.ink)
                        Text("\(StockDisplay.changeText(quote.change))  \(quote.percentText)")
                            .font(.nomiScaled(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(stockColor(quote))
                    }

                    if removable {
                        Menu {
                            Button(role: .destructive) {
                                StockWatchlistStore.remove(quoteID: quote.id)
                                Task { await reloadMarket() }
                            } label: {
                                Label("从自选移除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.nomiScaled(size: 12, weight: .semibold))
                                .foregroundStyle(CardPalette.faint)
                                .frame(width: 36, height: 44)
                        }
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .onTapGesture { selectedStock = quote }
                .accessibilityAddTraits(.isButton)

                if index < quotes.count - 1 {
                    WhaleRowDivider(leading: 13)
                }
            }
        }
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func trendingContent(
        _ topics: [TrendingTopic],
        module: IntelligenceModule
    ) -> some View {
        if topics.isEmpty {
            failureCard(digest.failures[module] ?? "目前没有拿到\(module.homepageTitle)")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                    Button {
                        topicSource = module.pageTitle
                        selectedTopic = topic
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(topic.rank)")
                                .font(.nomiScaled(size: 12, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(topic.rank <= 3 ? CardPalette.rose : CardPalette.faint)
                                .frame(width: 22, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(topic.title)
                                    .font(.nomiScaled(size: 13.5, weight: .medium))
                                    .foregroundStyle(CardPalette.ink)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                HStack(spacing: 6) {
                                    if !topic.heatText.isEmpty {
                                        Text(topic.heatText)
                                    }
                                    if !topic.label.isEmpty {
                                        Text(topic.label)
                                    }
                                }
                                .font(.nomiScaled(size: 9.5))
                                .foregroundStyle(CardPalette.faint)
                            }

                            Spacer(minLength: 4)

                            Image(systemName: "chevron.right")
                                .font(.nomiScaled(size: 9, weight: .semibold))
                                .foregroundStyle(CardPalette.faint)
                                .padding(.top, 3)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(WhalePressStyle(scale: 0.99))

                    if index < topics.count - 1 {
                        WhaleRowDivider(leading: 45)
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

    private func footer(for module: IntelligenceModule) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.shield")
                .font(.nomiScaled(size: 9))
                .padding(.top, 1)
            Text(footerText(for: module))
                .font(.nomiScaled(size: 9.5))
                .lineSpacing(2)
        }
        .foregroundStyle(CardPalette.faint)
        .padding(.top, 2)
    }

    private func loadingCard(for module: IntelligenceModule) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(CardPalette.accent)
            Text("正在整理\(module.homepageTitle)")
                .font(.nomiScaled(size: 12.5, weight: .medium))
                .foregroundStyle(CardPalette.subtle)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private func isModuleEmpty(_ module: IntelligenceModule) -> Bool {
        switch module {
        case .news: return digest.news.isEmpty
        case .ai: return digest.ai.isEmpty
        case .market: return digest.market.isEmpty
        case .weibo: return digest.trends.isEmpty
        case .zhihu: return digest.zhihu.isEmpty
        case .game: return digest.game.isEmpty
        }
    }

    @ViewBuilder
    private func moduleBody(_ module: IntelligenceModule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isModuleEmpty(module), let failure = digest.failures[module] {
                failureCard(failure)
            }
            moduleContent(for: module)
        }
    }

    private func failureCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "wifi.exclamationmark")
                .font(.nomiScaled(size: 13, weight: .semibold))
                .foregroundStyle(CardPalette.amber)
            Text(text)
                .font(.nomiScaled(size: 11.5))
                .foregroundStyle(CardPalette.amberInk)
                .lineSpacing(2)
            Spacer(minLength: 0)
            Button("重试") {
                Task { await refreshModule(selectedModule) }
            }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(loadingModules.contains(selectedModule))
        }
        .padding(13)
        .background(CardPalette.amberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var watchlist: [StockSymbol] {
        StockWatchlistStore.load()
    }

    private var indexQuotes: [StockQuote] {
        let ids = Set(StockService.indexes.map(\.id))
        return digest.market.filter { ids.contains($0.id) }
    }

    private var watchlistQuotes: [StockQuote] {
        let ids = Set(watchlist.map(\.id))
        return digest.market.filter { ids.contains($0.id) }
    }

    private func introText(for module: IntelligenceModule) -> String {
        switch module {
        case .news: return "国际与时事只保留最近的几条，标题都来自原始来源。"
        case .market: return "涨跌颜色遵循 A 股习惯；公开行情可能延迟，不构成投资建议。"
        case .weibo: return "这里只呈现当前讨论热度，不代表事实判断；点击后在 Nomi 内查看。"
        case .zhihu: return "知乎热榜保留问题热度和讨论入口，不代表 Nomi 对观点的判断。"
        case .game: return "游戏新闻、Steam 和 App Store 游戏榜分别加载，单个来源失败不会影响其他榜单。"
        case .ai: return "AI 科技更新来自中文科技媒体，保留标题、来源和发布时间。"
        }
    }

    private func footerText(for module: IntelligenceModule) -> String {
        switch module {
        case .market:
            return "行情数据来自公开接口，更新时间以本次刷新为准。"
        case .weibo:
            return "热搜标题来自微博公开榜单；页面可能要求登录，Nomi 不会绕过平台验证。"
        case .zhihu:
            return "问题来自知乎公开热榜；页面可能要求登录，Nomi 不会绕过平台验证。"
        case .game:
            return "游戏榜单、介绍和截图来自公开商店接口，可能随时间变化。"
        default:
            return "标题与来源来自公开 RSS，点击可在 Nomi 内查看原文。"
        }
    }

    private func articleMeta(_ article: NewsArticle) -> String {
        var parts = [article.source, article.category.rawValue]
        if let date = article.publishedAt {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "M月d日 HH:mm"
            parts.append(formatter.string(from: date))
        }
        return parts.joined(separator: " · ")
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: date)
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

    private var freshnessLabel: String {
        guard let date = digest.lastSuccess(for: selectedModule) else {
            return loadingModules.contains(selectedModule) ? "正在加载" : "尚未成功更新"
        }
        return "\(digest.failures[selectedModule] == nil ? "更新于" : "上次成功") \(timeText(date))"
    }

    private var shouldPollMarket: Bool {
        selectedModule == .market && scenePhase == .active
            && selectedStock == nil && selectedArticle == nil && selectedTopic == nil && !showStockSearch
    }

    @MainActor
    private func reloadMarket(silent: Bool = false) async {
        await refreshModule(.market)
    }

    @MainActor
    private func loadModuleIfNeeded(_ module: IntelligenceModule) async {
        await updateModule(module, force: false)
    }

    @MainActor
    private func refreshModule(_ module: IntelligenceModule) async {
        await updateModule(module, force: true)
    }

    @MainActor
    private func updateModule(_ module: IntelligenceModule, force: Bool) async {
        let requestID = UUID()
        requestIDs[module] = requestID
        loadingModules.insert(module)
        defer {
            if requestIDs[module] == requestID {
                loadingModules.remove(module)
                if module == .market { refreshingMarket = false }
            }
        }
        if module == .market {
            refreshingMarket = true
            marketError = nil
        }

        let next = await IntelligenceService.load(
            module: module,
            into: digest,
            force: force
        )
        guard !Task.isCancelled, requestIDs[module] == requestID else { return }
        digest.merge(next, module: module)

        if module == .market {
            marketError = next.failures[.market]
            refreshingMarket = false
        }
    }

    @MainActor
    private func pollMarketWhileVisible() async {
        guard shouldPollMarket else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: 60_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  shouldPollMarket
            else { continue }
            await reloadMarket(silent: true)
        }
    }
}

