import SwiftUI

/// “值得知道”作为底部主入口时使用，不通过全屏弹层打开。
struct IntelligenceTabView: View {
    @Binding var initialModule: IntelligenceModule
    @State private var digest: IntelligenceDigest?

    var body: some View {
        Group {
            if let digest {
                IntelligenceCenterView(
                    digest: digest,
                    initialModule: initialModule
                )
                .id(initialModule)
            } else {
                loadingState
            }
        }
        .task {
            guard digest == nil else { return }
            digest = await IntelligenceService.cached() ?? .empty()
        }
    }

    private var loadingState: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 11) {
                ProgressView()
                    .tint(CardPalette.accent)
                Text("正在准备值得知道")
                    .font(.nomiScaled(size: 13, weight: .medium))
                    .foregroundStyle(CardPalette.subtle)
            }
        }
    }
}
