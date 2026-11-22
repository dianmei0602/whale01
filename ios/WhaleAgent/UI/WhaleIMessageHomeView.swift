import SwiftUI
import UIKit

enum WhaleIMessagePalette {
    static let outgoing = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let outgoingPressed = Color(red: 0.0, green: 0.384, blue: 0.8)
    static let outgoingText = Color.white

    static let canvas = adaptive(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
    )
    static let header = adaptive(
        light: UIColor(red: 0.976, green: 0.976, blue: 0.984, alpha: 1),
        dark: UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)
    )
    static let incoming = adaptive(
        light: UIColor(red: 0.914, green: 0.914, blue: 0.922, alpha: 1),
        dark: UIColor(red: 0.149, green: 0.149, blue: 0.165, alpha: 1)
    )
    static let field = adaptive(
        light: UIColor(red: 0.973, green: 0.973, blue: 0.984, alpha: 1),
        dark: UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1)
    )
    static let line = adaptive(
        light: UIColor(red: 0.898, green: 0.898, blue: 0.910, alpha: 1),
        dark: UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1)
    )
    static let muted = adaptive(
        light: UIColor(red: 0.420, green: 0.420, blue: 0.435, alpha: 1),
        dark: UIColor(red: 0.659, green: 0.659, blue: 0.678, alpha: 1)
    )
    static let text = adaptive(
        light: UIColor.black,
        dark: UIColor.white
    )

    static func incomingShape() -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 5,
            bottomTrailingRadius: 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    static func outgoingShape() -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 5,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

/// The selected iMessage-style assistant start screen. It remains a message
/// thread instead of becoming a dashboard: calendar, quote, music and pending
/// confirmations all arrive as assistant messages.
struct WhaleIMessageHomeView: View {
    @ObservedObject var model: AppModel
    let onOpenRecords: () -> Void
    let onOpenMusic: () -> Void
    let onOpenWorkspace: () -> Void
    let onUsePrompt: (String) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text(dayLabel(context.date))
                        .whaleFont(size: 11, weight: .medium)
                        .foregroundStyle(WhaleIMessagePalette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)

                    ForEach(items(at: context.date)) { item in
                        incomingMessage(item)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("你可以这样说")
                            .whaleFont(size: 12, weight: .semibold)
                            .foregroundStyle(WhaleIMessagePalette.muted)
                            .padding(.top, 6)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(WhaleIMessageStarterBuilder.suggestions, id: \.self) { prompt in
                                Button {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    onUsePrompt(prompt)
                                } label: {
                                    Text(prompt)
                                        .whaleFont(size: 13, weight: .medium)
                                        .foregroundStyle(WhaleIMessagePalette.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .frame(minHeight: 38)
                                        .background(
                                            WhaleIMessagePalette.incoming,
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.whalePress)
                                .accessibilityIdentifier("imessage-prompt-\(prompt)")
                            }
                        }
                    }
                    .padding(.top, 4)

                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
            .background(WhaleIMessagePalette.canvas)
        }
        .background(WhaleIMessagePalette.canvas)
        .accessibilityIdentifier("imessage-assistant-home")
    }

    private func items(at date: Date) -> [WhaleIMessageStarterItem] {
        WhaleIMessageStarterBuilder.items(
            now: date,
            events: model.upcomingEvents,
            quote: DailyQuote.item(at: date),
            playback: model.playback,
            pendingCount: model.pending.count
        )
    }

    private func incomingMessage(_ item: WhaleIMessageStarterItem) -> some View {
        HStack(alignment: .bottom, spacing: 7) {
            WhaleMarkView(size: 27)
            VStack(alignment: .leading, spacing: 8) {
                Text(item.text)
                    .whaleFont(size: 16)
                    .lineSpacing(3)
                    .foregroundStyle(WhaleIMessagePalette.text)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .whaleFont(size: 12)
                        .lineSpacing(2)
                        .foregroundStyle(WhaleIMessagePalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    if item.kind == .quote {
                        Button {
                            model.toggleContentSpeech(text: item.text, contentId: item.id)
                        } label: {
                            Label(
                                model.speakingContentId == item.id ? "停止" : "听一下",
                                systemImage: model.speakingContentId == item.id ? "stop.fill" : "speaker.wave.2"
                            )
                            .whaleFont(size: 12, weight: .semibold)
                            .foregroundStyle(WhaleIMessagePalette.outgoing)
                        }
                        .buttonStyle(.plain)
                    }

                    if let title = item.actionTitle, let action = item.action {
                        Button {
                            perform(action)
                        } label: {
                            Text(title)
                                .whaleFont(size: 12, weight: .semibold)
                                .foregroundStyle(WhaleIMessagePalette.outgoing)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 310, alignment: .leading)
            .background(WhaleIMessagePalette.incoming, in: WhaleIMessagePalette.incomingShape())
            .accessibilityElement(children: .contain)

            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("imessage-home-\(item.kind.rawValue)")
    }

    private func perform(_ action: WhaleIMessageStarterAction) {
        UISelectionFeedbackGenerator().selectionChanged()
        switch action {
        case .calendar:
            onUsePrompt("看看我今天的安排")
        case .records:
            onOpenRecords()
        case .music:
            onOpenMusic()
        case .workspace:
            onOpenWorkspace()
        case .prompt(let text):
            onUsePrompt(text)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE HH:mm"
        return formatter.string(from: date)
    }
}
