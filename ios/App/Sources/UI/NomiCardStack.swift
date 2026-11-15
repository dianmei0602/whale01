import SwiftUI

/// 主卡栈：横向三张卡，一张一张看。
///
/// 用系统分页（`TabView(.page)`）而不是自绘拖拽：
/// - 惯性、边缘阻尼、可访问性都是系统给的，手感比手写稳
/// - 外层是纵向 ScrollView，横向分页不会和它抢手势
///
/// 切页时给一次轻触觉；尊重「减弱动态效果」。
struct NomiCardStack<Content: View>: View {

    @Binding var index: Int
    let count: Int
    let content: (Int) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(index: Binding<Int>,
         count: Int,
         @ViewBuilder content: @escaping (Int) -> Content) {
        self._index = index
        self.count = count
        self.content = content
    }

    var body: some View {
        VStack(spacing: 7) {
            TabView(selection: $index) {
                ForEach(0..<max(1, count), id: \.self) { page in
                    content(page)
                        .padding(.horizontal, 1)
                        .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 104)

            HStack(spacing: 5) {
                ForEach(0..<max(1, count), id: \.self) { page in
                    Capsule()
                        .fill(page == index ? CardPalette.accent : CardPalette.lineStrong)
                        .frame(width: page == index ? 13 : 5, height: 5)
                        .animation(reduceMotion ? nil : NomiMotion.fast, value: index)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: index)
    }
}

/// 卡栈里的一种卡：图标 + 两行字 + 可选进度条
struct NomiGlanceCard: View {
    let symbol: String
    let eyebrow: String
    let title: String
    let detail: String?
    var progress: Double? = nil
    var accent: Color = CardPalette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.nomiScaled(size: 12.5, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(eyebrow)
                    .font(.nomiScaled(size: 12.5, weight: .semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(title)
                .font(.nomiScaled(size: 17, weight: .semibold))
                .foregroundStyle(CardPalette.ink)
                .lineLimit(1)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.nomiScaled(size: 13))
                    .foregroundStyle(CardPalette.subtle)
                    .lineLimit(1)
            }

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(CardPalette.lineStrong).frame(height: 4)
                        Capsule()
                            .fill(accent)
                            .frame(width: max(0, geo.size.width * min(max(progress, 0), 1)),
                                   height: 4)
                            .animation(NomiMotion.base, value: progress)
                    }
                    .frame(height: 4)
                }
                .frame(height: 4)
                .padding(.top, 1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        }
    }
}
