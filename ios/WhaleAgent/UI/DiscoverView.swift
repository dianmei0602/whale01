import SwiftUI
import UIKit

struct DiscoverView: View {
    @Binding var selection: DiscoverChannel
    @ObservedObject var appModel: AppModel
    let onSettings: () -> Void
    let onSwitchTab: (AppTab) -> Void
    @State private var path = NavigationPath()
    @State private var slideFrom: Edge = .trailing
    @StateObject private var store: DiscoverChannelStore
    @State private var channelDrag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(selection: Binding<DiscoverChannel>, appModel: AppModel, onSettings: @escaping () -> Void,
         onSwitchTab: @escaping (AppTab) -> Void) {
        _selection = selection
        self.onSettings = onSettings
        self.onSwitchTab = onSwitchTab
        _store = StateObject(wrappedValue: DiscoverChannelStore.shared)
        self.appModel = appModel
    }

    private var models: [DiscoverChannel: DiscoverModel] { store.models }
    var body: some View {
        ZStack {
            WhaleBackdrop()
            VStack(spacing: 0) {
                header
                DiscoverChannelBar(selection: $selection)
                NavigationStack(path: $path) {
                    ZStack {
                        if let model = models[selection] {
                            DiscoverChannelPage(model: model, appModel: appModel)
                                .id(selection)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .offset(x: channelDrag * 0.24)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("discover-content-" + selection.rawValue)
                                .transition(.asymmetric(
                                    insertion: .move(edge: slideFrom),
                                    removal: .move(edge: slideFrom == .trailing ? .leading : .trailing)
                                ))
                        }
                    }
                    .simultaneousGesture(channelSwipe)
                    .animation(reduceMotion ? nil : WhaleMotion.channel, value: selection)
                    .background(Color.clear)
                    .toolbar(.hidden, for: .navigationBar)
                    .task {
#if DEBUG
                        let environment = ProcessInfo.processInfo.environment
                        if environment["WHALE_DEMO_GAME"] == "1", let gameModel = models[.game] {
                            gameModel.gameSection = .grossing
                            await gameModel.selectGameSection(.grossing)
                            if let first = gameModel.rankItems.first {
                                path.append(DiscoverRoute.game(first, .grossing))
                            }
                        }
                        if let raw = environment["WHALE_DEMO_GAME_SECTION"],
                           let section = GameSection(rawValue: raw),
                           let gameModel = models[.game] {
                            gameModel.gameSection = section
                            await gameModel.selectGameSection(section)
                        }
                        if let raw = environment["WHALE_DEMO_AI_SECTION"],
                           let aiModel = models[.ai] {
                            await aiModel.selectNewsSection(raw, for: .ai)
                        }
                        if let raw = environment["WHALE_DEMO_HEADLINE_SECTION"],
                           let headlineModel = models[.headline] {
                            await headlineModel.selectNewsSection(raw, for: .headline)
                        }
                        if let raw = environment["WHALE_DEMO_HOT_BOARD"],
                           let board = HotBoard(rawValue: raw),
                           let hotModel = models[.weibo] {
                            hotModel.hotBoard = board
                            await hotModel.loadHot(force: true)
                        }
                        if environment["WHALE_DEMO_STOCK"] == "1", models[.market] != nil {
                            let seed = StockSearchResult(
                                symbol: "sh600519",
                                code: "600519",
                                name: "贵州茅台",
                                market: "SH",
                                type: "stock"
                            )
                            path.append(DiscoverRoute.search(seed))
                        }
#endif
                    }
                    .navigationDestination(for: DiscoverRoute.self) { route in
                        if let model = models[selection] {
                            switch route {
                            case .news(let item):
                                NewsDetailView(item: item, channel: selection)
                            case .stock(let quote):
                                StockDetailView(quote: quote, discover: model)
                            case .search(let result):
                                StockSeedLoaderView(result: result, discover: model)
                            case .game(let item, let board):
                                GameDetailView(item: item, board: board)
                            }
                        }
                    }
                    .onChange(of: selection) { _, _ in path = NavigationPath() }
                }
            }
        }
    }

    /// Swiping inside a channel steps to the neighbouring channel; past the
    /// first or last channel it hands the swipe back to the main pager.
    private var channelSwipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) * 1.2 else {
                    channelDrag = 0
                    return
                }
                channelDrag = dx
            }
            .onEnded { value in
                let dx = value.translation.width
                let projected = value.predictedEndTranslation.width
                guard abs(dx) > abs(value.translation.height) * 1.2,
                      abs(dx) > 28 || abs(projected) > 58 else {
                    settleChannel()
                    return
                }
                stepChannel(dx < 0 ? 1 : -1)
            }
    }

    private func stepChannel(_ delta: Int) {
        let all = DiscoverChannel.allCases
        guard let index = all.firstIndex(of: selection) else { return }
        let next = index + delta
        guard all.indices.contains(next) else {
            settleChannel()
            onSwitchTab(delta > 0 ? .records : .conversation)
            return
        }
        slideFrom = delta > 0 ? .trailing : .leading
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(reduceMotion ? nil : WhaleMotion.channel) {
            channelDrag = 0
            selection = all[next]
        }
    }

    private func settleChannel() {
        withAnimation(reduceMotion ? nil : WhaleMotion.channel) {
            channelDrag = 0
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("发现").font(.title2.bold()).foregroundStyle(WhaleTheme.ink)
            Text(selection.title).font(.subheadline).foregroundStyle(WhaleTheme.muted)
                .accessibilityIdentifier("discover-current-channel")
            Spacer(minLength: 0)
            Button(action: onSettings) { Image(systemName: "gearshape").whaleTouchTarget() }
                .foregroundStyle(WhaleTheme.accent).accessibilityLabel("设置")
                .accessibilityIdentifier("discover-settings")
        }.frame(minHeight: 52).padding(.horizontal, 16)
            .accessibilityElement(children: .contain).accessibilityIdentifier("discover-fixed-header")
    }

}

struct DiscoverChannelBar: View {
    @Binding var selection: DiscoverChannel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(DiscoverChannel.allCases) { channel in
                        Button {
                            guard selection != channel else { return }
                            UISelectionFeedbackGenerator().selectionChanged()
                            selection = channel
                        } label: {
                            Text(channel.tabTitle).whaleFont(size: 14, weight: .semibold)
                                .whaleChannelLabel(channel, selected: selection == channel)
                        }.buttonStyle(.whalePress).id(channel)
                            .accessibilityLabel(channel.title)
                            .accessibilityAddTraits(selection == channel ? .isSelected : [])
                            .accessibilityIdentifier("discover-channel-" + channel.rawValue)
                    }
                }.padding(.horizontal, 16).padding(.vertical, 8)
            }.scrollIndicators(.hidden).scrollClipDisabled()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("discover-channel-selector")
                .onChange(of: selection) { _, channel in
                    withAnimation(reduceMotion ? nil : WhaleMotion.control) { proxy.scrollTo(channel, anchor: .center) }
                }
                .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }
}

@MainActor
final class DiscoverChannelStore: ObservableObject {
    static let shared = DiscoverChannelStore()
    let models: [DiscoverChannel: DiscoverModel]

    private init() {
        var built: [DiscoverChannel: DiscoverModel] = [:]
        for item in DiscoverChannel.allCases {
            built[item] = DiscoverModel(initialChannel: item)
        }
        models = built
    }
}
