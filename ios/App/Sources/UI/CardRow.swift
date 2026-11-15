import SwiftUI
import Foundation

/// 卡片只有手势，没有按钮。
/// 左滑划掉；只有待办卡能右滑完成，其它卡右滑有阻尼、拉不动。
struct CardRow: View {
    let card: DayCard
    let onDismiss: () -> Void
    let onComplete: () -> Void

    @State private var offset: CGFloat = 0

    private var revealingComplete: Bool { offset > 0 && card.canComplete }
    private var revealingDismiss: Bool { offset < 0 }

    var body: some View {
        ZStack {
            background
            cardBody
                .offset(x: offset)
                .gesture(drag)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        )
    }

    private var background: some View {
        HStack(spacing: 0) {
            if revealingComplete {
                Text("✓ 完成")
                    .foregroundColor(Color(red: 0.03, green: 0.10, blue: 0.06))
                    .padding(.leading, 22)
            }
            Spacer()
            if revealingDismiss {
                Text("✕ 划掉")
                    .foregroundColor(CardPalette.subtle)
                    .padding(.trailing, 22)
            }
        }
        .font(.nomiScaled(size: 15.5, weight: .semibold))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(revealingComplete
                    ? Color(red: 0.36, green: 0.92, blue: 0.66)
                    : CardPalette.raised)
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Text(card.icon)
                    .font(.nomiScaled(size: 18.5))
                    .frame(width: 34, height: 34)
                    .background(card.tint.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(card.tint.border, lineWidth: 1)
                    )

                Text(card.time)
                    .font(.nomiScaled(size: 14.5, weight: .semibold))
                    .foregroundColor(card.tint.color)
                    .tracking(0.4)

                Spacer()
            }

            Text(card.fact)
                .font(.nomiScaled(size: 19.5, weight: .semibold))
                .foregroundColor(CardPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.advice)
                .font(.nomiScaled(size: 16))
                .foregroundColor(CardPalette.subtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                offset = damped(value.translation.width)
            }
            .onEnded { value in
                let width = damped(value.translation.width)
                if width <= -88 {
                    withAnimation(.easeOut(duration: 0.18)) { offset = -420 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onDismiss() }
                } else if width >= 88 && card.canComplete {
                    withAnimation(.easeOut(duration: 0.18)) { offset = 420 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onComplete() }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                }
            }
    }

    private func damped(_ translation: CGFloat) -> CGFloat {
        var value = translation
        if value > 0 && !card.canComplete {
            value = min(value * 0.22, 26)
        }
        return max(-150, min(150, value))
    }
}
