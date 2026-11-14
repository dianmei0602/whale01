import SwiftUI

struct ChronicleIndexView: View {
    let repository: ChronicleRepository
    @State private var query = ""

    private var results: [ChronicleSearchResult] {
        repository.search(query)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if query.isEmpty {
                            emptyState
                        } else if results.isEmpty {
                            noResults
                        } else {
                            resultSummary
                            ForEach(results) { result in
                                resultDestination(result)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("检索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "朝代、人物、事件或地点"
            )
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("INDEX OF CHRONICLES")
                .font(.caption2.weight(.bold))
                .tracking(2.2)
                .foregroundStyle(ChronicleTheme.cinnabar)
            Text("从一处名字进入历史")
                .font(ChronicleTheme.title)
                .foregroundStyle(ChronicleTheme.ink)
            Text("可以试试“长安”“秦始皇”“靖康”或“丝绸之路”。搜索只在本机资料中进行。")
                .font(ChronicleTheme.bodySerif)
                .foregroundStyle(ChronicleTheme.secondaryInk)

            VStack(alignment: .leading, spacing: 12) {
                quickQuery("秦")
                quickQuery("洛阳")
                quickQuery("南宋")
                quickQuery("统一")
            }
        }
        .padding(.top, 18)
        .accessibilityIdentifier("search-empty")
    }

    private func quickQuery(_ text: String) -> some View {
        Button {
            query = text
        } label: {
            HStack {
                Text(text)
                    .font(ChronicleTheme.bodySerif)
                Spacer()
                Image(systemName: "arrow.up.left")
                    .font(.caption)
            }
            .foregroundStyle(ChronicleTheme.ink)
            .padding(15)
            .background(ChronicleTheme.card.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ChronicleTheme.hairline, lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private var resultSummary: some View {
        Text("找到 \(results.count) 条本地资料")
            .font(.caption)
            .foregroundStyle(ChronicleTheme.secondaryInk)
            .padding(.top, 12)
    }

    @ViewBuilder
    private func resultDestination(_ result: ChronicleSearchResult) -> some View {
        switch result {
        case .dynasty(let dynasty):
            NavigationLink {
                DynastyDetailView(repository: repository, dynasty: dynasty)
            } label: {
                DynastyCard(
                    dynasty: dynasty,
                    eventCount: repository.events(for: dynasty.id).count
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("search-dynasty-\(dynasty.id)")

        case .event(let event):
            let dynastyName = repository.dynasty(id: event.dynastyID)?.name ?? "政权待核"
            NavigationLink {
                EventDetailView(repository: repository, event: event)
            } label: {
                EventRow(event: event, dynastyName: dynastyName)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("search-event-\(event.id)")
        }
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 32))
                .foregroundStyle(ChronicleTheme.faintInk)
            Text("本机资料中暂未找到“\(query)”")
                .font(ChronicleTheme.section)
                .foregroundStyle(ChronicleTheme.ink)
            Text("首版只收录经过整理的主线条目，不代表完整历史数据库。")
                .font(.footnote)
                .foregroundStyle(ChronicleTheme.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .accessibilityIdentifier("search-no-results")
    }
}
