import SwiftUI

struct DynastyDetailView: View {
    let repository: ChronicleRepository
    let dynasty: ChronicleDynasty

    private var events: [ChronicleEvent] {
        repository.events(for: dynasty.id)
    }

    private var sources: [ChronicleSource] {
        repository.sources(ids: dynasty.sourceIDs)
    }

    private var people: [ChroniclePerson] {
        repository.people(ids: dynasty.peopleIDs)
    }

    private var places: [ChroniclePlace] {
        repository.places(ids: dynasty.placeIDs)
    }

    private var topics: [ChronicleTopic] {
        repository.topics(ids: dynasty.topicIDs)
    }

    var body: some View {
        ZStack {
            PaperBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    facts
                    narrative
                    structuralSections
                    connectionsSection
                    eventsSection
                    sourcesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(dynasty.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("dynasty-detail-\(dynasty.id)")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(dynasty.periodLabel)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(ChronicleTheme.cinnabar)
                    Text(dynasty.name)
                        .font(.custom("Songti SC", size: 54, relativeTo: .largeTitle))
                        .fontWeight(.semibold)
                        .foregroundStyle(ChronicleTheme.ink)
                    Text(dynasty.subtitle)
                        .font(ChronicleTheme.section)
                        .foregroundStyle(ChronicleTheme.secondaryInk)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: dynasty.accent))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Text(String(dynasty.name.prefix(1)))
                            .font(.custom("Songti SC", size: 28, relativeTo: .title))
                            .foregroundStyle(ChronicleTheme.card)
                    }
            }

            HStack(spacing: 8) {
                ChronicleChip(
                    text: dynasty.role.label,
                    tint: Color(hex: dynasty.accent)
                )
                Text(repository.era(id: dynasty.eraID)?.title ?? "时代待核")
                    .font(.caption)
                    .foregroundStyle(ChronicleTheme.secondaryInk)
            }
        }
    }

    private var facts: some View {
        VStack(spacing: 0) {
            factRow(label: "建立者", value: dynasty.founder)
            Divider().overlay(ChronicleTheme.hairline)
            factRow(label: "都城", value: dynasty.capital)
            if !dynasty.aliases.isEmpty {
                Divider().overlay(ChronicleTheme.hairline)
                factRow(label: "又称", value: dynasty.aliases.joined(separator: "、"))
            }
        }
        .padding(.horizontal, 16)
        .background(ChronicleTheme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(ChronicleTheme.hairline.opacity(0.75), lineWidth: 0.7)
        }
    }

    private func factRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChronicleTheme.faintInk)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(ChronicleTheme.bodySerif)
                .foregroundStyle(ChronicleTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
    }

    private var narrative: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(eyebrow: "时代切片", title: "阅读这段历史")
            Text(dynasty.summary)
                .font(ChronicleTheme.bodySerif)
                .foregroundStyle(ChronicleTheme.ink.opacity(0.84))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var structuralSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            narrativeBlock(title: "权力结构", text: dynasty.structure)
            narrativeBlock(title: "社会与生活", text: dynasty.society)
            narrativeBlock(title: "历史影响", text: dynasty.legacy)
        }
    }

    private func narrativeBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ChronicleTheme.section)
                .foregroundStyle(ChronicleTheme.ink)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(ChronicleTheme.secondaryInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ChronicleTheme.bronze.opacity(0.34))
                .frame(width: 2)
        }
    }

    @ViewBuilder
    private var connectionsSection: some View {
        if !people.isEmpty || !places.isEmpty || !topics.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(eyebrow: "继续探索", title: "人物、地点与制度")

                if !people.isEmpty {
                    entityGroupTitle("相关人物")
                    ForEach(people) { person in
                        NavigationLink {
                            PersonDetailView(repository: repository, person: person)
                        } label: {
                            LinkedEntityRow(
                                title: person.name,
                                eyebrow: person.kind.label,
                                detail: "\(person.periodLabel) · \(person.summary)"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !places.isEmpty {
                    entityGroupTitle("历史地点")
                    ForEach(places) { place in
                        NavigationLink {
                            PlaceDetailView(repository: repository, place: place)
                        } label: {
                            LinkedEntityRow(
                                title: place.name,
                                eyebrow: "地点",
                                detail: "\(place.modernName) · \(place.summary)"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !topics.isEmpty {
                    entityGroupTitle("制度与文明")
                    ForEach(topics) { topic in
                        NavigationLink {
                            TopicDetailView(repository: repository, topic: topic)
                        } label: {
                            LinkedEntityRow(
                                title: topic.title,
                                eyebrow: topic.category.label,
                                detail: topic.summary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func entityGroupTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ChronicleTheme.cinnabar)
            .padding(.top, 4)
    }

    @ViewBuilder
    private var eventsSection: some View {
        if events.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("本版尚未为该条目录入单独事件。")
                    .font(.footnote)
                    .foregroundStyle(ChronicleTheme.secondaryInk)
            }
        } else {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeading(eyebrow: "编年摘记", title: "这件政权留下了什么")
                ForEach(events) { event in
                    NavigationLink {
                        EventDetailView(repository: repository, event: event)
                    } label: {
                        EventRow(event: event, dynastyName: dynasty.name)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dynasty-event-\(event.id)")
                }
            }
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(eyebrow: "可追溯", title: "资料出处")
            ForEach(sources) { source in
                SourceBadge(source: source)
            }
        }
    }
}

struct EventDetailView: View {
    let repository: ChronicleRepository
    let event: ChronicleEvent

    private var dynasty: ChronicleDynasty? {
        repository.dynasty(id: event.dynastyID)
    }

    private var relatedDynasties: [ChronicleDynasty] {
        event.relatedDynastyIDs.compactMap { repository.dynasty(id: $0) }
    }

    private var sources: [ChronicleSource] {
        repository.sources(ids: event.sourceIDs)
    }

    private var people: [ChroniclePerson] {
        repository.people(ids: event.peopleIDs)
    }

    private var places: [ChroniclePlace] {
        repository.places(ids: event.placeIDs)
    }

    private var topics: [ChronicleTopic] {
        repository.topics(ids: event.topicIDs)
    }

    var body: some View {
        ZStack {
            PaperBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    summaryCard
                    relatedPolitiesSection
                    eventNarrative
                    connectionsSection
                    if let caveat = event.caveat, !caveat.isEmpty {
                        caveatCard(caveat)
                    }
                    dynastyLink
                    sourceSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("事件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("event-detail-\(event.id)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(event.date.display)
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(ChronicleTheme.cinnabar)
                Spacer()
                ChronicleChip(text: event.date.precision.label)
            }

            Text(event.title)
                .font(.custom("Songti SC", size: 36, relativeTo: .largeTitle))
                .fontWeight(.semibold)
                .foregroundStyle(ChronicleTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let dynasty {
                Text("\(dynasty.name) · \(dynasty.periodLabel)")
                    .font(.subheadline)
                    .foregroundStyle(ChronicleTheme.secondaryInk)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("史事")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(ChronicleTheme.cinnabar)
            Text(event.summary)
                .font(ChronicleTheme.bodySerif)
                .foregroundStyle(ChronicleTheme.ink.opacity(0.85))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            if !event.tags.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(event.tags, id: \.self) { tag in
                            ChronicleChip(text: tag, tint: ChronicleTheme.bronze)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(ChronicleTheme.card.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(ChronicleTheme.hairline.opacity(0.72), lineWidth: 0.8)
        }
    }

    private var eventNarrative: some View {
        VStack(alignment: .leading, spacing: 20) {
            narrativeBlock(title: "背景", text: event.background)
            narrativeBlock(title: "经过", text: event.process)
            narrativeBlock(title: "结果", text: event.consequence)
            narrativeBlock(title: "为什么重要", text: event.significance)
        }
    }

    @ViewBuilder
    private var relatedPolitiesSection: some View {
        if relatedDynasties.count > 1 {
            VStack(alignment: .leading, spacing: 9) {
                Text("相关政权")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChronicleTheme.cinnabar)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(relatedDynasties) { related in
                            NavigationLink {
                                DynastyDetailView(repository: repository, dynasty: related)
                            } label: {
                                ChronicleChip(
                                    text: related.name,
                                    tint: Color(hex: related.accent)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func narrativeBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ChronicleTheme.section)
                .foregroundStyle(ChronicleTheme.ink)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(ChronicleTheme.secondaryInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ChronicleTheme.cinnabar.opacity(0.3))
                .frame(width: 2)
        }
    }

    @ViewBuilder
    private var connectionsSection: some View {
        if !people.isEmpty || !places.isEmpty || !topics.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(eyebrow: "线索", title: "继续查证")

                ForEach(people) { person in
                    NavigationLink {
                        PersonDetailView(repository: repository, person: person)
                    } label: {
                        LinkedEntityRow(
                            title: person.name,
                            eyebrow: person.kind.label,
                            detail: person.summary
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(places) { place in
                    NavigationLink {
                        PlaceDetailView(repository: repository, place: place)
                    } label: {
                        LinkedEntityRow(
                            title: place.name,
                            eyebrow: "地点",
                            detail: place.modernName
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(topics) { topic in
                    NavigationLink {
                        TopicDetailView(repository: repository, topic: topic)
                    } label: {
                        LinkedEntityRow(
                            title: topic.title,
                            eyebrow: topic.category.label,
                            detail: topic.summary
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func caveatCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(ChronicleTheme.gold)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text("阅读提示")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ChronicleTheme.gold)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(ChronicleTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(ChronicleTheme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
    }

    @ViewBuilder
    private var dynastyLink: some View {
        if let dynasty {
            NavigationLink {
                DynastyDetailView(repository: repository, dynasty: dynasty)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("所在政权")
                            .font(.caption)
                            .foregroundStyle(ChronicleTheme.secondaryInk)
                        Text(dynasty.name)
                            .font(ChronicleTheme.section)
                            .foregroundStyle(ChronicleTheme.ink)
                    }
                    Spacer()
                    Text(dynasty.periodLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(ChronicleTheme.secondaryInk)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ChronicleTheme.faintInk)
                }
                .padding(16)
                .background(ChronicleTheme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(eyebrow: "可追溯", title: "这页的依据")
            ForEach(sources) { source in
                SourceBadge(source: source)
            }
            Text("出处列表用于说明资料依据，不代表已经完成逐句校勘。古代年代与事件解释仍有不同学术意见。")
                .font(.caption2)
                .foregroundStyle(ChronicleTheme.faintInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
