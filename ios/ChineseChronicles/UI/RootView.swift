import SwiftUI

enum ChronicleTab: String, CaseIterable {
    case overview
    case timeline
    case index

    var title: String {
        switch self {
        case .overview:
            return "总览"
        case .timeline:
            return "时间轴"
        case .index:
            return "检索"
        }
    }

    var symbol: String {
        switch self {
        case .overview:
            return "square.grid.2x2"
        case .timeline:
            return "chart.xyaxis.line"
        case .index:
            return "text.magnifyingglass"
        }
    }
}

struct RootView: View {
    let repository: ChronicleRepository
    @State private var selection: ChronicleTab = .overview

    var body: some View {
        ZStack {
            OverviewView(repository: repository)
                .opacity(selection == .overview ? 1 : 0)
                .allowsHitTesting(selection == .overview)
                .accessibilityHidden(selection != .overview)

            ChronicleTimelineView(repository: repository)
                .opacity(selection == .timeline ? 1 : 0)
                .allowsHitTesting(selection == .timeline)
                .accessibilityHidden(selection != .timeline)

            ChronicleIndexView(repository: repository)
                .opacity(selection == .index ? 1 : 0)
                .allowsHitTesting(selection == .index)
                .accessibilityHidden(selection != .index)
        }
        .tint(ChronicleTheme.cinnabar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(ChronicleTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: selection == tab ? .semibold : .regular))
                        Text(tab.title)
                            .font(.caption2.weight(selection == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(
                        selection == tab ? ChronicleTheme.cinnabar : ChronicleTheme.secondaryInk
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(ChronicleTheme.cinnabar.opacity(0.1))
                                .padding(.horizontal, 18)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab-\(tab.rawValue)")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 9)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ChronicleTheme.hairline.opacity(0.65))
                .frame(height: 0.7)
        }
    }
}
