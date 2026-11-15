import SwiftUI

struct IntelligenceEntryView: View {
    let initialModule: IntelligenceModule

    @Environment(\.dismiss) private var dismiss
    @State private var digest: IntelligenceDigest?

    var body: some View {
        Group {
            if let digest {
                IntelligenceCenterView(
                    digest: digest,
                    initialModule: initialModule,
                    onClose: { dismiss() }
                )
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

            VStack(spacing: 14) {
                HStack {
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
                    .accessibilityLabel("关闭")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Spacer()

                VStack(spacing: 11) {
                    ProgressView()
                        .tint(CardPalette.accent)
                    Text("正在准备\(initialModule.homepageTitle)")
                        .font(.nomiScaled(size: 13, weight: .medium))
                        .foregroundStyle(CardPalette.subtle)
                }

                Spacer()
            }
        }
    }
}

