import SwiftUI

struct ClassicalDailyQuoteCard: View {
    let quote: DailyEncouragement
    let onNext: () -> Void
    let onOpenLibrary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日一句")
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundStyle(CardPalette.subtle)

                Spacer()

                Text(Self.dateText.string(from: Date()))
                    .font(.nomiScaled(size: 12.5, weight: .medium))
                    .foregroundStyle(CardPalette.faint)
            }

            Text(quote.text)
                .font(.nomiScaled(size: 23, weight: .semibold, design: .serif))
                .foregroundStyle(CardPalette.ink)
                .lineSpacing(5)
                .lineLimit(4)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .padding(.bottom, 11)
                .accessibilityLabel("今日一句：\(quote.text)")

            HStack(spacing: 8) {
                Circle()
                    .fill(CardPalette.accent)
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)

                if let sourceLink = quote.sourceLink {
                    Link(destination: sourceLink) {
                        HStack(spacing: 4) {
                            Text(quote.citation)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            Image(systemName: "arrow.up.right")
                                .font(.nomiScaled(size: 9, weight: .semibold))
                                .accessibilityHidden(true)
                        }
                        .font(.nomiScaled(size: 12.5, weight: .medium))
                        .foregroundStyle(CardPalette.subtle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("打开 \(quote.citation) 的固定版本原文")
                } else {
                    Text(quote.citation)
                        .font(.nomiScaled(size: 12.5, weight: .medium))
                        .foregroundStyle(CardPalette.subtle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 4)

                Button("换一句", action: onNext)
                    .font(.nomiScaled(size: 12.5, weight: .semibold))
                    .foregroundStyle(CardPalette.accent)
                    .frame(minWidth: 50, minHeight: 44)

                Button("古籍库", action: onOpenLibrary)
                    .font(.nomiScaled(size: 12.5, weight: .semibold))
                    .foregroundStyle(CardPalette.accent)
                    .frame(minWidth: 54, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(CardPalette.surface)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(CardPalette.accent.opacity(0.035))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private static let dateText: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}

struct ClassicalQuoteLibraryView: View {
    @Environment(\.dismiss) private var dismiss

    let quotes: [DailyEncouragement]
    let currentQuoteID: String
    let onSelect: (DailyEncouragement) -> Void

    @State private var selectedBook = "全部"

    private var books: [String] {
        var seen = Set<String>()
        let ordered = quotes.compactMap { quote -> String? in
            guard seen.insert(quote.book).inserted else { return nil }
            return quote.book
        }
        return ["全部"] + ordered
    }

    private var visibleQuotes: [DailyEncouragement] {
        guard selectedBook != "全部" else { return quotes }
        return quotes.filter { $0.book == selectedBook }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                libraryHeader
                bookFilters
                quoteList
            }
        }
        .nomiEdgeDismiss()
    }

    private var libraryHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("中国古籍库")
                    .font(.nomiScaled(size: 25, weight: .bold))
                    .tracking(-0.55)
                    .foregroundStyle(CardPalette.ink)

                Text("\(max(books.count - 1, 1)) 部典籍 · \(quotes.count) 句原文 · 最近 30 句不重复")
                    .font(.nomiScaled(size: 12.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.nomiScaled(size: 14, weight: .semibold))
                    .foregroundStyle(CardPalette.subtle)
                    .frame(width: 44, height: 44)
                    .background(CardPalette.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(CardPalette.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭古籍库")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var bookFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(books, id: \.self) { book in
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            selectedBook = book
                        }
                    } label: {
                        Text(book)
                            .font(.nomiScaled(size: 12.5, weight: .semibold))
                            .foregroundStyle(selectedBook == book ? CardPalette.navyInk : CardPalette.subtle)
                            .padding(.horizontal, 13)
                            .frame(minHeight: 42)
                            .background(selectedBook == book ? CardPalette.accent : CardPalette.surface)
                            .clipShape(Capsule())
                            .overlay {
                                if selectedBook != book {
                                    Capsule().stroke(CardPalette.line, lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(WhalePressStyle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 8)
    }

    private var quoteList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(visibleQuotes) { quote in
                    quoteRow(quote)
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(CardPalette.accent)
                        .frame(width: 5, height: 5)

                    Text("原文逐句匹配 NiuTrans Classical-Modern · MIT · 固定版本 4e746ea9")
                        .font(.nomiScaled(size: 10.5))
                        .foregroundStyle(CardPalette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func quoteRow(_ quote: DailyEncouragement) -> some View {
        Button {
            onSelect(quote)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(quote.citation)
                        .font(.nomiScaled(size: 12, weight: .semibold))
                        .foregroundStyle(CardPalette.accent)
                        .lineLimit(1)

                    Text("\(quote.hanziCount) 字")
                        .font(.nomiScaled(size: 10.5))
                        .foregroundStyle(CardPalette.faint)

                    Spacer(minLength: 0)

                    if quote.id == currentQuoteID {
                        Text("今日")
                            .font(.nomiScaled(size: 10.5, weight: .semibold))
                            .foregroundStyle(CardPalette.navyInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(CardPalette.accent)
                            .clipShape(Capsule())
                    }
                }

                Text(quote.text)
                    .font(.nomiScaled(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(CardPalette.ink)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(quote.id == currentQuoteID ? CardPalette.accent.opacity(0.055) : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(CardPalette.line)
                    .frame(height: 0.6)
                    .padding(.leading, 18)
            }
        }
        .buttonStyle(WhalePressStyle(scale: 0.995))
        .accessibilityLabel("\(quote.citation)，\(quote.text)")
        .accessibilityHint("选择为今日一句")
    }
}
