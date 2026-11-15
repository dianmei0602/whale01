import SwiftUI

private enum StockDetailTab: String, CaseIterable, Identifiable {
    case overview = "概览"
    case fund = "资金"
    case sector = "板块"
    case finance = "财报"
    case equity = "股权"

    var id: String { rawValue }
}

struct StockDetailView: View {
    let quote: StockQuote

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: StockDetailTab = .overview
    @State private var snapshot: StockDetailSnapshot?
    @State private var reloadTick = 0
    @State private var currentQuote: StockQuote

    init(quote: StockQuote) {
        self.quote = quote
        _currentQuote = State(initialValue: quote)
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                topBar
                quoteHeader
                tabBar

                if let snapshot {
                    content(snapshot)
                } else {
                    loadingState
                }
            }
        }
        .task(id: reloadTick) {
            await refreshAll()
        }
        .nomiEdgeDismiss()
    }

    private var topBar: some View {
        HStack(spacing: 11) {
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
            .accessibilityLabel("关闭股票详情")

            VStack(alignment: .leading, spacing: 2) {
                Text(quote.name)
                    .font(.nomiScaled(size: 18, weight: .bold))
                    .foregroundStyle(CardPalette.ink)
                Text("\(quote.code) · 东方财富公开数据")
                    .font(.nomiScaled(size: 9.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer(minLength: 0)

            Button {
                reloadTick &+= 1
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundStyle(CardPalette.accent)
                    .frame(width: 44, height: 44)
                    .background(CardPalette.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("刷新股票详情")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(CardPalette.chrome.opacity(0.9))
        .overlay(alignment: .bottom) {
            Rectangle().fill(CardPalette.line).frame(height: 0.6)
        }
    }

    private var quoteHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(StockDisplay.priceText(currentQuote.price))
                .font(.nomiScaled(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(CardPalette.ink)

            VStack(alignment: .leading, spacing: 2) {
                Text(StockDisplay.changeText(currentQuote.change))
                Text(currentQuote.percentText)
            }
            .font(.nomiScaled(size: 12.5, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(currentQuote.isRise ? CardPalette.rose : (currentQuote.isFall ? CardPalette.success : CardPalette.subtle))

            Spacer()

            TrendingArrow(quote: currentQuote)
        }
        .padding(.horizontal, 18)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }

    @MainActor
    private func refreshAll() async {
        async let details = StockDetailService.load(quote)
        let symbol = StockSymbol(quoteID: quote.id, code: quote.code, name: quote.name)
        if let quotes = try? await StockService.fetchQuotes([symbol]),
           let latest = quotes.first {
            currentQuote = latest
        }
        snapshot = await details
    }

    private var tabBar: some View {
        HStack(spacing: 5) {
            ForEach(StockDetailTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.nomiScaled(size: 11.5, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? CardPalette.navyInk : CardPalette.subtle)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(selectedTab == tab ? CardPalette.accent : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(CardPalette.surface)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(CardPalette.line, lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func content(_ snapshot: StockDetailSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                switch selectedTab {
                case .overview:
                    overview(snapshot)
                case .fund:
                    fundFlow(snapshot)
                case .sector:
                    sectors(snapshot)
                case .finance:
                    finance(snapshot)
                case .equity:
                    equity(snapshot)
                }

                Text("公开行情和 F10 数据可能延迟，仅供信息参考，不构成投资建议。")
                    .font(.nomiScaled(size: 9.5))
                    .foregroundStyle(CardPalette.faint)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func overview(_ snapshot: StockDetailSnapshot) -> some View {
        if let profile = snapshot.profile {
            metricGrid([
                ("总市值", StockNumber.whole(profile.totalMarketCap)),
                ("流通市值", StockNumber.whole(profile.floatMarketCap)),
                ("市盈率", String(format: "%.2f", profile.pe)),
                ("市净率", String(format: "%.2f", profile.pb)),
                ("总股本", StockNumber.whole(profile.totalShares)),
                ("流通股本", StockNumber.whole(profile.floatShares))
            ])
        } else {
            unavailable(snapshot.failures["概览"] ?? "个股概览暂无数据")
        }

        if let latest = snapshot.fundFlow.last {
            sectionTitle("最近资金", subtitle: latest.date)
            metricGrid([
                ("主力净流入", StockNumber.compact(latest.mainNet)),
                ("超大单", StockNumber.compact(latest.superLargeNet)),
                ("大单", StockNumber.compact(latest.largeNet)),
                ("中单", StockNumber.compact(latest.mediumNet)),
                ("小单", StockNumber.compact(latest.smallNet))
            ])
        }
    }

    @ViewBuilder
    private func fundFlow(_ snapshot: StockDetailSnapshot) -> some View {
        if snapshot.fundFlow.isEmpty {
            unavailable(snapshot.failures["资金"] ?? "资金流向暂无数据")
        } else {
            ForEach(snapshot.fundFlow.reversed()) { point in
                WhaleGlassCard(radius: 18, padding: 13) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(point.date)
                                .font(.nomiScaled(size: 12.5, weight: .semibold))
                                .foregroundStyle(CardPalette.ink)
                            Spacer()
                            Text("主力 \(StockNumber.compact(point.mainNet))")
                                .font(.nomiScaled(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(point.mainNet >= 0 ? CardPalette.rose : CardPalette.success)
                        }
                        HStack(spacing: 10) {
                            flowCell("超大单", point.superLargeNet)
                            flowCell("大单", point.largeNet)
                            flowCell("中单", point.mediumNet)
                            flowCell("小单", point.smallNet)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectors(_ snapshot: StockDetailSnapshot) -> some View {
        if snapshot.sectors.isEmpty {
            unavailable(snapshot.failures["板块"] ?? "板块数据暂无")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(snapshot.sectors.enumerated()), id: \.element.id) { index, sector in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.nomiScaled(size: 11, weight: .bold))
                            .foregroundStyle(index < 3 ? CardPalette.rose : CardPalette.faint)
                            .frame(width: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sector.name)
                                .font(.nomiScaled(size: 13.5, weight: .semibold))
                                .foregroundStyle(CardPalette.ink)
                            Text("主力 \(StockNumber.compact(sector.mainNetInflow)) · 占比 \(String(format: "%.2f%%", sector.mainNetRatio))")
                                .font(.nomiScaled(size: 9.5))
                                .foregroundStyle(CardPalette.faint)
                        }
                        Spacer()
                        Text(String(format: "%+.2f%%", sector.changePercent))
                            .font(.nomiScaled(size: 12, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(sector.changePercent >= 0 ? CardPalette.rose : CardPalette.success)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    if index < snapshot.sectors.count - 1 {
                        WhaleRowDivider(leading: 43)
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
    }

    @ViewBuilder
    private func finance(_ snapshot: StockDetailSnapshot) -> some View {
        if let report = snapshot.finance {
            sectionTitle("主要财务指标", subtitle: report.reportName)
            metricGrid([
                ("营业收入", StockNumber.whole(report.revenue)),
                ("归母净利润", StockNumber.whole(report.parentNetProfit)),
                ("净资产收益率", String(format: "%.2f%%", report.roe)),
                ("毛利率", String(format: "%.2f%%", report.grossMargin)),
                ("净利率", String(format: "%.2f%%", report.netMargin))
            ])
        } else {
            unavailable(snapshot.failures["财报"] ?? "财报暂无数据")
        }
    }

    @ViewBuilder
    private func equity(_ snapshot: StockDetailSnapshot) -> some View {
        if let capital = snapshot.capital {
            metricGrid([
                ("总股本", StockNumber.whole(capital.totalShares)),
                ("流通股", StockNumber.whole(capital.unlimitedShares)),
                ("限售股", StockNumber.whole(capital.limitedShares))
            ])
        }

        if snapshot.shareholders.isEmpty {
            unavailable(snapshot.failures["股东"] ?? "股东数据暂无")
        } else {
            sectionTitle("前五大股东", subtitle: "报告期以公开 F10 为准")
            VStack(spacing: 0) {
                ForEach(Array(snapshot.shareholders.enumerated()), id: \.element.id) { index, holder in
                    HStack(alignment: .top, spacing: 9) {
                        Text("\(holder.rank)")
                            .font(.nomiScaled(size: 11, weight: .bold))
                            .foregroundStyle(CardPalette.accent)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(holder.name)
                                .font(.nomiScaled(size: 12.5, weight: .medium))
                                .foregroundStyle(CardPalette.ink)
                                .lineLimit(2)
                            Text("\(String(format: "%.2f%%", holder.ratio)) · \(StockNumber.whole(holder.shares)) 股 · 变化 \(holder.change)")
                                .font(.nomiScaled(size: 9.5))
                                .foregroundStyle(CardPalette.faint)
                        }
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    if index < snapshot.shareholders.count - 1 {
                        WhaleRowDivider(leading: 40)
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
    }

    private func metricGrid(_ metrics: [(String, String)]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.0)
                        .font(.nomiScaled(size: 10))
                        .foregroundStyle(CardPalette.subtle)
                    Text(metric.1)
                        .font(.nomiScaled(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(CardPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                .padding(.horizontal, 12)
                .overlay(alignment: .bottomTrailing) {
                    Rectangle()
                        .fill(CardPalette.line)
                        .frame(height: 0.6)
                }
            }
        }
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private func flowCell(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.nomiScaled(size: 8.5))
                .foregroundStyle(CardPalette.faint)
            Text(StockNumber.compact(value))
                .font(.nomiScaled(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(value >= 0 ? CardPalette.rose : CardPalette.success)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.nomiScaled(size: 14, weight: .bold))
                .foregroundStyle(CardPalette.ink)
            Spacer()
            Text(subtitle)
                .font(.nomiScaled(size: 9.5))
                .foregroundStyle(CardPalette.faint)
        }
    }

    private func unavailable(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "tray")
                .foregroundStyle(CardPalette.amber)
            Text(text)
                .font(.nomiScaled(size: 11.5))
                .foregroundStyle(CardPalette.subtle)
            Spacer()
        }
        .padding(13)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView().tint(CardPalette.accent)
            Text("正在整理资金、板块和 F10 数据")
                .font(.nomiScaled(size: 12))
                .foregroundStyle(CardPalette.subtle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TrendingArrow: View {
    let quote: StockQuote

    var body: some View {
        Image(systemName: quote.isRise ? "arrow.up.right" : (quote.isFall ? "arrow.down.right" : "minus"))
            .font(.nomiScaled(size: 17, weight: .bold))
            .foregroundStyle(quote.isRise ? CardPalette.rose : (quote.isFall ? CardPalette.success : CardPalette.subtle))
            .frame(width: 36, height: 36)
            .background(CardPalette.surface)
            .clipShape(Circle())
    }
}

