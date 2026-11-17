import SwiftUI

struct OverviewView: View {
    let repository: ChronicleRepository

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        hero
                        eraSection
                        dynastySection
                        editorialNote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("华章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("CHINESE CHRONICLES")
                        .font(.caption2.weight(.bold))
                        .tracking(2.6)
                        .foregroundStyle(ChronicleTheme.cinnabar)
                    Text("华章")
                        .font(ChronicleTheme.display)
                        .foregroundStyle(ChronicleTheme.ink)
                    Text(repository.dataset.title)
                        .font(ChronicleTheme.section)
                        .foregroundStyle(ChronicleTheme.secondaryInk)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(ChronicleTheme.cinnabar.opacity(0.1))
                        .frame(width: 50, height: 62)
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(ChronicleTheme.cinnabar.opacity(0.45), lineWidth: 1)
                        }
                    Text("史")
                        .font(.custom("Songti SC", size: 30, relativeTo: .title))
                        .foregroundStyle(ChronicleTheme.cinnabar)
                }
            }

            Text(repository.dataset.subtitle)
                .font(ChronicleTheme.bodySerif)
                .foregroundStyle(ChronicleTheme.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 0) {
                stat(value: "\(repository.dataset.dynasties.count)", label: "政权")
                stat(value: "\(repository.dataset.events.count)", label: "事件")
                stat(value: "\(repository.dataset.people.count)", label: "人物")
                stat(value: "\(repository.dataset.places.count)", label: "地点")
                stat(value: "\(repository.dataset.topics.count)", label: "主题")
                stat(value: "\(repository.dataset.sources.count)", label: "出处")
            }
            .padding(.vertical, 14)
            .background(ChronicleTheme.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))

            Text(repository.overviewRange)
                .font(.caption)
                .foregroundStyle(ChronicleTheme.secondaryInk)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview-hero")
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(ChronicleTheme.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(ChronicleTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
    }

    private var eraSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "六段历史脉络", title: "从一个时代开始")

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(repository.dataset.eras) { era in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(era.range)
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(ChronicleTheme.cinnabar)
                            Text(era.title)
                                .font(ChronicleTheme.section)
                                .foregroundStyle(ChronicleTheme.ink)
                            Text(era.summary)
                                .font(.caption)
                                .foregroundStyle(ChronicleTheme.secondaryInk)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: 210, alignment: .leading)
                        .padding(16)
                        .background(ChronicleTheme.card.opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(alignment: .topTrailing) {
                            Circle()
                                .fill(ChronicleTheme.cinnabar.opacity(0.12))
                                .frame(width: 52, height: 52)
                                .offset(x: 14, y: -14)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(ChronicleTheme.hairline.opacity(0.7), lineWidth: 0.8)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var dynastySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(eyebrow: "按时代阅读", title: "王朝与并立政权")

            ForEach(repository.dataset.eras) { era in
                let dynasties = repository.dynasties(in: era.id)
                if !dynasties.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(era.title)
                                .font(ChronicleTheme.section)
                                .foregroundStyle(ChronicleTheme.ink)
                            Text(era.range)
                                .font(.caption)
                                .foregroundStyle(ChronicleTheme.secondaryInk)
                            Spacer()
                            Text("\(dynasties.count) 条")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(ChronicleTheme.faintInk)
                        }

                        ForEach(dynasties) { dynasty in
                            NavigationLink {
                                DynastyDetailView(repository: repository, dynasty: dynasty)
                            } label: {
                                DynastyCard(
                                    dynasty: dynasty,
                                    eventCount: repository.events(for: dynasty.id).count
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dynasty-\(dynasty.id)")
                        }
                    }
                }
            }
        }
    }

    private var editorialNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("编年说明")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(ChronicleTheme.cinnabar)
            Text(repository.dataset.editorialNote)
                .font(.footnote)
                .foregroundStyle(ChronicleTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Text("资料版本 \(repository.dataset.contentVersion) · 复核于 \(repository.dataset.reviewedAt)")
                .font(.caption2)
                .foregroundStyle(ChronicleTheme.faintInk)
        }
        .padding(18)
        .background(ChronicleTheme.bronze.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }
}
