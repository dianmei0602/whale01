import WidgetKit
import SwiftUI

/// 小组件：只展示 App 写下的快照，不自己抓数据、不猜。
///
/// - 小号：完整角色（42pt）+ 倒计时 + 一行事件名
/// - 中号：完整角色（54pt）+ 今天 + 下一件事 + 地点 + 状态 + 新鲜度
/// - 读不到共享快照（免费签名没有 App Group）→ 明确显示「打开 App 同步」，不显示旧数据
struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct TodayProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: WidgetSnapshot(eventTitle: "产品评审",
                                                          startAt: Date().addingTimeInterval(22 * 60),
                                                          timeText: "16:00–17:00",
                                                          place: "B 座 12F",
                                                          kind: "soon",
                                                          source: "系统日历",
                                                          updatedAt: Date(),
                                                          remainingCount: 3))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: Date(), snapshot: WidgetSnapshot.load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JinriToday", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .widgetURL(URL(string: "nomi://today"))
                .containerBackground(for: .widget) {
                    WidgetAuroraBackground()
                }
        }
        .configurationDisplayName("Nomi · 今天")
        .description("下一件事和倒计时，数据来自 App 的快照。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        Group {
            if family == .accessoryInline {
                inlineView
            } else if family == .accessoryCircular {
                circularView
            } else if family == .accessoryRectangular {
                rectangularView
            } else {
                ZStack {
                    WidgetAuroraBackground()

                    if let snapshot = entry.snapshot, !snapshot.eventTitle.isEmpty || snapshot.kind != "idle" {
                        content(snapshot)
                    } else if entry.snapshot != nil {
                        emptyState
                    } else {
                        degradeState
                    }
                }
            }
        }
    }

    // MARK: - 锁屏组件

    private var inlineView: some View {
        Text(inlineText)
            .font(.system(size: 13, weight: .semibold))
    }

    private var circularView: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.35), lineWidth: 2)
                .padding(2)
            VStack(spacing: 2) {
                AccessoryNomiEyes(size: 15)
                Text(shortCountdown)
                    .font(.system(size: 10, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .widgetAccentable()
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            AccessoryNomiEyes(size: 23)

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(primarySubtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(shortCountdown)
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
        }
        .widgetAccentable()
    }

    private var primaryTitle: String {
        guard let snapshot = entry.snapshot else { return "打开 Nomi 同步" }
        return snapshot.eventTitle.isEmpty ? "今天没安排" : snapshot.eventTitle
    }

    private var primarySubtitle: String {
        guard let snapshot = entry.snapshot else { return "还没有日程快照" }
        if !snapshot.timeText.isEmpty { return snapshot.timeText }
        return snapshot.source
    }

    private var shortCountdown: String {
        guard let snapshot = entry.snapshot else { return "--" }
        let text = snapshot.countdownText
        return text.isEmpty ? "Nomi" : text
    }

    private var inlineText: String {
        guard let snapshot = entry.snapshot else { return "Nomi · 打开 App 同步" }
        if snapshot.eventTitle.isEmpty { return "Nomi · 今天没安排" }
        return "Nomi · \(snapshot.countdownText) · \(snapshot.eventTitle)"
    }

    // MARK: 有快照

    private func content(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 6) {
            HStack(alignment: .center, spacing: 6) {
                Image("NomiWidgetIdle")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: family == .systemSmall ? 42 : 52,
                           height: family == .systemSmall ? 42 : 52)

                Spacer(minLength: 0)

                Text(snapshot.countdownText)
                    .font(.system(size: family == .systemSmall ? 18 : 20, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(Color(red: 0.38, green: 0.92, blue: 0.84))
            }

            if family == .systemSmall {
                Text(snapshot.eventTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
                    .lineLimit(1)
            } else {
                Text("今天 · 还剩 \(snapshot.remainingCount) 件")
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(red: 0.58, green: 0.68, blue: 0.70))

                Text(snapshot.eventTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
                    .lineLimit(1)

                Text(subtitle(snapshot))
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(red: 0.58, green: 0.68, blue: 0.70))
                    .lineLimit(1)
            }
        }
        .padding(family == .systemSmall ? 10 : 12)
    }

    private func subtitle(_ snapshot: WidgetSnapshot) -> String {
        var parts: [String] = []
        if !snapshot.timeText.isEmpty { parts.append(snapshot.timeText) }
        if !snapshot.place.isEmpty { parts.append(snapshot.place) }
        parts.append(snapshot.source)
        parts.append(snapshot.freshnessText)
        return parts.joined(separator: " · ")
    }

    // MARK: 无安排 / 无快照

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image("NomiWidgetHappy")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 42, height: 42)

            Text("今天没安排")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
        }
    }

    /// 拿不到共享快照：说清楚，不编数据
    private var degradeState: some View {
        VStack(spacing: 6) {
            Image("NomiWidgetIdle")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 40, height: 40)

            Text("打开 App 同步")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.88))

            Text("还没拿到日程")
                .font(.system(size: 9.5))
                .foregroundColor(Color(red: 0.58, green: 0.68, blue: 0.70))
        }
        .padding(8)
    }
}

private struct AccessoryNomiEyes: View {
    let size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.28) {
            Capsule()
                .fill(.primary)
                .frame(width: size * 0.18, height: size * 0.72)
            Capsule()
                .fill(.primary)
                .frame(width: size * 0.18, height: size * 0.72)
        }
        .frame(width: size * 1.4, height: size)
        .accessibilityHidden(true)
    }
}

private struct WidgetAuroraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.027, green: 0.075, blue: 0.102),
                    Color(red: 0.016, green: 0.043, blue: 0.063)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.38, green: 0.92, blue: 0.84).opacity(0.25),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 2,
                endRadius: 100
            )

            RadialGradient(
                colors: [
                    Color(red: 0.47, green: 0.73, blue: 1.00).opacity(0.13),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 2,
                endRadius: 90
            )
        }
    }
}
