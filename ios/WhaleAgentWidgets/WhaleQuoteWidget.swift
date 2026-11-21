import Foundation
import SwiftUI
import WidgetKit

private struct WhaleQuoteEntry: TimelineEntry {
    let date: Date
    let quote: DailyQuote.Item
    let snapshot: WhaleWidgetSnapshot
}

private struct WhaleQuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> WhaleQuoteEntry {
        WhaleQuoteEntry(date: Date(), quote: DailyQuote.item(at: Date()), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WhaleQuoteEntry) -> Void) {
        completion(
            WhaleQuoteEntry(
                date: Date(),
                quote: DailyQuote.item(at: Date()),
                snapshot: WhaleWidgetSnapshotStore.load()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WhaleQuoteEntry>) -> Void) {
        let now = Date()
        let entries = [
            WhaleQuoteEntry(
                date: now,
                quote: DailyQuote.item(at: now),
                snapshot: WhaleWidgetSnapshotStore.load()
            )
        ]
        let next = Calendar.current.date(byAdding: .minute, value: DailyQuote.slotMinutes, to: now)
            ?? now.addingTimeInterval(1_800)
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

private struct WhaleQuoteWidgetView: View {
    let entry: WhaleQuoteEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.quote.text)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                    Text("— \(entry.quote.source)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !entry.snapshot.nextTitle.isEmpty {
                        Text("下一项：\(entry.snapshot.nextTitle)")
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Image(systemName: "text.quote")
                            .foregroundStyle(Color.teal)
                        Text("今日一句")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Text(entry.quote.text)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .lineLimit(entry.snapshot.nextTitle.isEmpty ? 5 : 3)
                    Spacer(minLength: 0)
                    Text("— \(entry.quote.source)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !entry.snapshot.nextTitle.isEmpty {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("下一项 · \(entry.snapshot.nextTitle)")
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(entry.snapshot.nextDetail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "whaleagent://workspace"))
    }
}

@main
struct WhaleQuoteWidget: Widget {
    let kind = "WhaleQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WhaleQuoteProvider()) { entry in
            WhaleQuoteWidgetView(entry: entry)
        }
        .configurationDisplayName("鲸鱼今日一句")
        .description("在主屏幕或锁屏查看今日一句，打开后进入鲸鱼工作台。")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
