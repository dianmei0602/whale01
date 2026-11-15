import SwiftUI

struct StockSearchSheet: View {
    let existingIDs: Set<String>
    let onAdd: (StockSymbol) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [StockSymbol] = []
    @State private var searching = false
    @State private var errorText: String?
    @State private var addedIDs = Set<String>()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("搜索股票、指数或港股，最多添加 \(StockWatchlistStore.limit) 只。")
                            .font(.nomiScaled(size: 12))
                            .foregroundStyle(CardPalette.subtle)
                            .lineSpacing(3)

                        searchField

                        if searching {
                            ProgressView("正在搜索…")
                                .font(.nomiScaled(size: 12))
                                .tint(CardPalette.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                        } else if let errorText {
                            stateText(errorText, symbol: "wifi.exclamationmark")
                        } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            stateText("输入公司简称或股票代码", symbol: "magnifyingglass")
                        } else if results.isEmpty {
                            stateText("没有找到匹配的股票", symbol: "chart.line.downtrend.xyaxis")
                        } else {
                            resultList
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("添加自选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .font(.nomiScaled(size: 15, weight: .semibold))
                        .foregroundStyle(CardPalette.accent)
                }
            }
        }
        .task(id: query) {
            await search(query)
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.nomiScaled(size: 14, weight: .semibold))
                .foregroundStyle(CardPalette.subtle)

            TextField("例如：贵州茅台、600519、腾讯", text: $query)
                .font(.nomiScaled(size: 15))
                .foregroundStyle(CardPalette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CardPalette.faint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }

    private var resultList: some View {
        VStack(spacing: 0) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, symbol in
                HStack(spacing: 11) {
                    WhaleIconTile(symbol: "chart.line.uptrend.xyaxis",
                                  color: CardPalette.accent,
                                  size: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(symbol.name)
                            .font(.nomiScaled(size: 14.5, weight: .semibold))
                            .foregroundStyle(CardPalette.ink)
                        Text(symbol.code)
                            .font(.nomiScaled(size: 10.5))
                            .foregroundStyle(CardPalette.subtle)
                    }

                    Spacer(minLength: 6)

                    let alreadyAdded = existingIDs.contains(symbol.id) || addedIDs.contains(symbol.id)
                    Button {
                        guard !alreadyAdded else { return }
                        if onAdd(symbol) {
                            addedIDs.insert(symbol.id)
                        }
                    } label: {
                        Text(alreadyAdded ? "已添加" : "添加")
                            .font(.nomiScaled(size: 11.5, weight: .semibold))
                            .foregroundStyle(alreadyAdded ? CardPalette.success : CardPalette.accent)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background((alreadyAdded ? CardPalette.success : CardPalette.accent).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(alreadyAdded)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)

                if index < results.count - 1 {
                    WhaleRowDivider(leading: 57)
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

    private func stateText(_ text: String, symbol: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.nomiScaled(size: 26, weight: .semibold))
            Text(text)
                .font(.nomiScaled(size: 12.5))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(CardPalette.subtle)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }

    @MainActor
    private func search(_ value: String) async {
        let term = value.trimmingCharacters(in: .whitespacesAndNewlines)
        errorText = nil
        guard !term.isEmpty else {
            results = []
            searching = false
            return
        }

        do {
            try await Task.sleep(nanoseconds: 350_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        searching = true
        do {
            let found = try await StockService.search(term)
            guard !Task.isCancelled else { return }
            results = found
        } catch {
            if Task.isCancelled { return }
            results = []
            errorText = "股票搜索暂时不可用，请稍后重试。"
        }
        searching = false
    }
}

