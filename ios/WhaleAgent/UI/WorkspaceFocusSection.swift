import SwiftUI
import UIKit

struct WorkspaceFocusSection: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: WhaleWorkspaceStore
    let onOpenMusic: () -> Void

    private var nextEvent: CalendarEventPreview? {
        model.upcomingEvents
            .filter { $0.endAt > Date() }
            .sorted { $0.startAt < $1.startAt }
            .first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Label("上下文专注模式", systemImage: "scope")
                    .whaleFont(size: 19, weight: .bold, design: .rounded)
                    .foregroundStyle(WhaleTheme.ink)
                Text("只改变鲸鱼工作台里的上下文和建议，不会替你开启系统勿扰或伪造专注完成记录。")
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.muted)
                if let mode = store.activeFocusMode, let startedAt = store.focusStartedAt {
                    HStack {
                        Label(mode.title, systemImage: mode.icon)
                            .whaleFont(size: 15, weight: .semibold)
                            .foregroundStyle(WhaleTheme.accent)
                        Spacer()
                        TimelineView(.periodic(from: Date(), by: 1)) { context in
                            Text(elapsedText(from: startedAt, to: context.date))
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .foregroundStyle(WhaleTheme.ink)
                        }
                    }
                    Button("结束专注") {
                        store.endFocus()
                    }
                    .whaleFont(size: 13, weight: .semibold)
                    .foregroundStyle(WhaleTheme.onAccent)
                    .padding(.horizontal, 13)
                    .frame(minHeight: 38)
                    .background(WhaleTheme.accent, in: Capsule())
                    .buttonStyle(.plain)
                    Button {
                        onOpenMusic()
                    } label: {
                        Label("打开系统音乐库", systemImage: "music.note")
                            .whaleFont(size: 13, weight: .semibold)
                            .foregroundStyle(WhaleTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .whaleCard(padding: 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(WorkspaceFocusMode.allCases) { mode in
                    Button {
                        store.startFocus(mode)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(WhaleTheme.accent)
                            Text(mode.title)
                                .whaleFont(size: 16, weight: .bold)
                                .foregroundStyle(WhaleTheme.ink)
                            Text(mode.suggestion)
                                .whaleFont(size: 12)
                                .foregroundStyle(WhaleTheme.muted)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
                        .padding(13)
                        .background(
                            store.activeFocusMode == mode
                                ? WhaleTheme.accentSoft
                                : WhaleTheme.card,
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(
                                    store.activeFocusMode == mode
                                        ? WhaleTheme.accent.opacity(0.35)
                                        : WhaleTheme.line,
                                    lineWidth: 0.8
                                )
                        }
                    }
                    .buttonStyle(.whalePress)
                }
            }

            if let nextEvent {
                VStack(alignment: .leading, spacing: 5) {
                    Label("下一项真实日程", systemImage: "calendar")
                        .whaleFont(size: 13, weight: .semibold)
                        .foregroundStyle(WhaleTheme.accent)
                    Text(nextEvent.title)
                        .whaleFont(size: 16, weight: .semibold)
                        .foregroundStyle(WhaleTheme.ink)
                    Text(nextEvent.startAt.formatted(.dateTime.month().day().hour().minute()))
                        .whaleFont(size: 12)
                        .foregroundStyle(WhaleTheme.muted)
                }
                .whaleCard(padding: 14)
            }

            if !store.focusSessions.isEmpty {
                Text("最近专注 \(store.focusSessions.count) 次")
                    .whaleFont(size: 12, weight: .medium)
                    .foregroundStyle(WhaleTheme.muted)
            }
        }
    }

    private func elapsedText(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
