import SwiftUI

struct ChronicleTimelineView: View {
    let repository: ChronicleRepository

    private let scale = TimelineScale()

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        timelineCard
                        legend
                        eventList
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("时间轴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TIME ACROSS DYNASTIES")
                .font(.caption2.weight(.bold))
                .tracking(2.2)
                .foregroundStyle(ChronicleTheme.cinnabar)
            Text("在同一尺度中，看见并立与更替")
                .font(ChronicleTypeOverride.title)
                .foregroundStyle(ChronicleTheme.ink)
            Text("横向滑动查看长时段；点击朝代条或事件标记进入详情。")
                .font(.subheadline)
                .foregroundStyle(ChronicleTheme.secondaryInk)
        }
        .accessibilityIdentifier("timeline-header")
    }

    private var timelineCard: some View {
        ScrollView(.horizontal) {
            DynastyTimelineBand(repository: repository, scale: scale)
                .frame(width: scale.width, height: 330)
                .padding(.vertical, 8)
        }
        .scrollIndicators(.visible)
        .background(ChronicleTheme.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(ChronicleTheme.hairline.opacity(0.75), lineWidth: 0.8)
        }
        .accessibilityIdentifier("timeline-scroll")
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: ChronicleTheme.bronze, text: "主线与时期")
            legendItem(color: ChronicleTheme.gold, text: "并立 / 异说")
            HStack(spacing: 5) {
                Circle().fill(ChronicleTheme.cinnabar).frame(width: 6, height: 6)
                Text("大事")
                    .font(.caption2)
                    .foregroundStyle(ChronicleTheme.secondaryInk)
            }
        }
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 15, height: 5)
            Text(text)
                .font(.caption2)
                .foregroundStyle(ChronicleTheme.secondaryInk)
        }
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "编年摘记", title: "改变方向的事件")

            ForEach(repository.dataset.events.sorted { $0.date < $1.date }) { event in
                let dynastyName = repository.dynasty(id: event.dynastyID)?.name ?? "政权待核"
                NavigationLink {
                    EventDetailView(repository: repository, event: event)
                } label: {
                    EventRow(event: event, dynastyName: dynastyName)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("timeline-event-\(event.id)")
            }
        }
    }
}

private enum ChronicleTypeOverride {
    static let title = Font.custom("Songti SC", size: 28, relativeTo: .title2)
        .weight(.semibold)
}

private struct DynastyTimelineBand: View {
    let repository: ChronicleRepository
    let scale: TimelineScale

    private let laneHeight: Double = 42
    private let bandTop: Double = 58

    var body: some View {
        let bands = scale.bands(for: repository.dataset.dynasties)

        ZStack(alignment: .topLeading) {
            grid

            ForEach(bands) { band in
                let startX = scale.x(for: band.dynasty.startYear)
                let bandWidth = scale.width(
                    from: band.dynasty.startYear,
                    to: band.dynasty.endYear
                )

                NavigationLink {
                    DynastyDetailView(repository: repository, dynasty: band.dynasty)
                } label: {
                    HStack(spacing: 4) {
                        Text(band.dynasty.name)
                            .font(.custom("Songti SC", size: 12, relativeTo: .caption))
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        if bandWidth > 74 {
                            Text(band.dynasty.startLabel)
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(ChronicleTheme.card)
                    .padding(.horizontal, 7)
                    .frame(width: bandWidth, height: 27, alignment: .leading)
                    .background(
                        Color(hex: band.dynasty.accent),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(band.dynasty.name)，\(band.dynasty.periodLabel)")
                .accessibilityIdentifier("timeline-dynasty-\(band.dynasty.id)")
                .position(
                    x: startX + bandWidth / 2,
                    y: bandTop + Double(band.lane) * laneHeight
                )
            }

            ForEach(repository.dataset.events.filter { $0.importance == 3 }) { event in
                NavigationLink {
                    EventDetailView(repository: repository, event: event)
                } label: {
                    VStack(spacing: 3) {
                        Circle()
                            .fill(ChronicleTheme.cinnabar)
                            .frame(width: 9, height: 9)
                            .overlay {
                                Circle().stroke(ChronicleTheme.card, lineWidth: 2)
                            }
                        Rectangle()
                            .fill(ChronicleTheme.cinnabar.opacity(0.35))
                            .frame(width: 1, height: 18)
                    }
                    .frame(width: 30, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(event.date.display)，\(event.title)")
                .accessibilityIdentifier("timeline-marker-\(event.id)")
                .position(x: scale.x(for: event.date.year), y: 281)
            }
        }
    }

    private var grid: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: -2000, through: 2000, by: 250)), id: \.self) { year in
                let x = scale.x(for: year)
                Rectangle()
                    .fill(ChronicleTheme.hairline.opacity(0.45))
                    .frame(width: 0.7, height: 298)
                    .position(x: x, y: 152)

                Text(year < 0 ? "前 \(-year)" : "\(year)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(ChronicleTheme.faintInk)
                    .position(x: x, y: 18)
            }

            Rectangle()
                .fill(ChronicleTheme.hairline.opacity(0.7))
                .frame(width: scale.width, height: 0.8)
                .position(x: scale.width / 2, y: 40)
        }
    }
}
