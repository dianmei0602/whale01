import Foundation

enum WhaleIMessageStarterKind: String, Equatable {
    case greeting
    case calendar
    case quote
    case music
    case pending
}

enum WhaleIMessageStarterAction: Equatable {
    case calendar
    case records
    case music
    case workspace
    case prompt(String)
}

struct WhaleIMessageStarterItem: Identifiable, Equatable {
    let id: String
    let kind: WhaleIMessageStarterKind
    let text: String
    let detail: String?
    let actionTitle: String?
    let action: WhaleIMessageStarterAction?
}

/// Converts the live assistant state into short iMessage-style conversation
/// messages. The builder never invents calendar entries, music, or pending
/// actions when the corresponding source is empty.
enum WhaleIMessageStarterBuilder {
    static let suggestions = [
        "今天怎么安排？",
        "帮我记一件事",
        "找点想听的",
        "我上周记的在哪里？"
    ]

    static func items(
        now: Date = Date(),
        events: [CalendarEventPreview],
        quote: DailyQuote.Item,
        playback: PlaybackSnapshot = .idle,
        pendingCount: Int = 0
    ) -> [WhaleIMessageStarterItem] {
        var items: [WhaleIMessageStarterItem] = [
            WhaleIMessageStarterItem(
                id: "greeting",
                kind: .greeting,
                text: greeting(at: now),
                detail: calendarSummary(now: now, events: events),
                actionTitle: "查看日程",
                action: .calendar
            ),
            WhaleIMessageStarterItem(
                id: "quote-\(quote.id)",
                kind: .quote,
                text: quote.text,
                detail: "— \(quote.source)",
                actionTitle: nil,
                action: nil
            )
        ]

        if let track = playback.track {
            let playing = playback.state == "playing"
            items.append(
                WhaleIMessageStarterItem(
                    id: "music-\(track.trackId)",
                    kind: .music,
                    text: playing ? "正在播放《\(track.title)》" : "上次听到《\(track.title)》",
                    detail: track.artist,
                    actionTitle: "打开音乐",
                    action: .music
                )
            )
        }

        if pendingCount > 0 {
            items.append(
                WhaleIMessageStarterItem(
                    id: "pending-\(pendingCount)",
                    kind: .pending,
                    text: "有 \(pendingCount) 项操作等你确认。",
                    detail: "确认前不会写入系统，也不会发送。",
                    actionTitle: "查看待确认",
                    action: .records
                )
            )
        }
        return items
    }

    static func greeting(at date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12:
            return "早上好，我是鲸鱼。"
        case 12..<18:
            return "下午好，我是鲸鱼。"
        default:
            return "晚上好，我是鲸鱼。"
        }
    }

    private static func calendarSummary(now: Date, events: [CalendarEventPreview]) -> String {
        guard let next = events
            .filter({ $0.endAt >= now })
            .sorted(by: { $0.startAt < $1.startAt })
            .first else {
            return "今天暂时没有日程。直接告诉我想做什么。"
        }

        let time = timeFormatter.string(from: next.startAt)
        if next.isAllDay {
            return "今天有一项全天安排：\(next.title)。"
        }
        return "接下来 \(time)，\(next.title)。"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

enum WhaleIMessageLayout {
    static func isSameGroup(previous: ChatMessage?, current: ChatMessage) -> Bool {
        guard let previous else { return false }
        return previous.role == current.role
            && Calendar.current.isDate(previous.createdAt, inSameDayAs: current.createdAt)
            && current.createdAt.timeIntervalSince(previous.createdAt) < 120
    }

    static func verticalSpacing(previous: ChatMessage?, current: ChatMessage) -> CGFloat {
        guard let previous else { return 2 }
        if !Calendar.current.isDate(previous.createdAt, inSameDayAs: current.createdAt) {
            return 18
        }
        if isSameGroup(previous: previous, current: current) {
            return 3
        }
        return 10
    }
}
