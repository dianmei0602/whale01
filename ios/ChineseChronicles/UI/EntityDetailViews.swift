import SwiftUI

struct PersonDetailView: View {
    let repository: ChronicleRepository
    let person: ChroniclePerson

    private var dynasties: [ChronicleDynasty] {
        person.dynastyIDs.compactMap { repository.dynasty(id: $0) }
            .sorted { $0.startYear < $1.startYear }
    }

    private var events: [ChronicleEvent] {
        person.eventIDs.compactMap { repository.event(id: $0) }
            .sorted { $0.date < $1.date }
    }

    private var sources: [ChronicleSource] {
        repository.sources(ids: person.sourceIDs)
    }

    var body: some View {
        ZStack {
            PaperBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    biography
                    dynastySection
                    eventSection
                    sourcesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("person-detail-\(person.id)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(person.kind.label)
                .font(.caption.weight(.bold))
                .foregroundStyle(ChronicleTheme.cinnabar)
            Text(person.name)
                .font(.custom("Songti SC", size: 48, relativeTo: .largeTitle))
                .fontWeight(.semibold)
                .foregroundStyle(ChronicleTheme.ink)
            Text(person.periodLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(ChronicleTheme.secondaryInk)
            if !person.aliases.isEmpty {
                Text(person.aliases.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(ChronicleTheme.faintInk)
            }
        }
    }

    private var biography: some View {
        Text(person.summary)
            .font(ChronicleTheme.bodySerif)
            .foregroundStyle(ChronicleTheme.ink.opacity(0.86))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 18)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(ChronicleTheme.hairline)
                    .frame(height: 0.8)
            }
    }

    @ViewBuilder
    private var dynastySection: some View {
        if !dynasties.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(eyebrow: "所处时代", title: "相关政权")
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
                }
            }
        }
    }

    @ViewBuilder
    private var eventSection: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(eyebrow: "历史线索", title: "相关事件")
                ForEach(events) { event in
                    let dynastyName = repository.dynasty(id: event.dynastyID)?.name ?? "政权待核"
                    NavigationLink {
                        EventDetailView(repository: repository, event: event)
                    } label: {
                        EventRow(event: event, dynastyName: dynastyName)
                    }
                    .buttonStyle(.plain)
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

struct PlaceDetailView: View {
    let repository: ChronicleRepository
    let place: ChroniclePlace

    private var dynasties: [ChronicleDynasty] {
        place.dynastyIDs.compactMap { repository.dynasty(id: $0) }
            .sorted { $0.startYear < $1.startYear }
    }

    private var events: [ChronicleEvent] {
        place.eventIDs.compactMap { repository.event(id: $0) }
            .sorted { $0.date < $1.date }
    }

    private var sources: [ChronicleSource] {
        repository.sources(ids: place.sourceIDs)
    }

    var body: some View {
        ZStack {
            PaperBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    narrative
                    if let caveat = place.caveat, !caveat.isEmpty {
                        caveatCard(caveat)
                    }
                    dynastySection
                    eventSection
                    sourcesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("place-detail-\(place.id)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("历史地点")
                .font(.caption.weight(.bold))
                .foregroundStyle(ChronicleTheme.cinnabar)
            Text(place.name)
                .font(.custom("Songti SC", size: 46, relativeTo: .largeTitle))
                .fontWeight(.semibold)
                .foregroundStyle(ChronicleTheme.ink)
            Text("今地 · \(place.modernName)")
                .font(.subheadline)
                .foregroundStyle(ChronicleTheme.secondaryInk)
        }
    }

    private var narrative: some View {
        Text(place.summary)
            .font(ChronicleTheme.bodySerif)
            .foregroundStyle(ChronicleTheme.ink.opacity(0.86))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func caveatCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("地名提示")
                .font(.caption.weight(.bold))
                .foregroundStyle(ChronicleTheme.gold)
            Text(text)
                .font(.footnote)
                .foregroundStyle(ChronicleTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(ChronicleTheme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var dynastySection: some View {
        if !dynasties.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(eyebrow: "历史角色", title: "相关政权")
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
                }
            }
        }
    }

    @ViewBuilder
    private var eventSection: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(eyebrow: "发生于此", title: "相关事件")
                ForEach(events) { event in
                    let dynastyName = repository.dynasty(id: event.dynastyID)?.name ?? "政权待核"
                    NavigationLink {
                        EventDetailView(repository: repository, event: event)
                    } label: {
                        EventRow(event: event, dynastyName: dynastyName)
                    }
                    .buttonStyle(.plain)
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

struct TopicDetailView: View {
    let repository: ChronicleRepository
    let topic: ChronicleTopic

    private var dynasties: [ChronicleDynasty] {
        topic.dynastyIDs.compactMap { repository.dynasty(id: $0) }
            .sorted { $0.startYear < $1.startYear }
    }

    private var events: [ChronicleEvent] {
        topic.eventIDs.compactMap { repository.event(id: $0) }
            .sorted { $0.date < $1.date }
    }

    private var sources: [ChronicleSource] {
        repository.sources(ids: topic.sourceIDs)
    }

    var body: some View {
        ZStack {
            PaperBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    narrative
                    dynastySection
                    eventSection
                    sourcesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("topic-detail-\(topic.id)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(topic.category.label)
                .font(.caption.weight(.bold))
                .foregroundStyle(ChronicleTheme.cinnabar)
            Text(topic.title)
                .font(.custom("Songti SC", size: 40, relativeTo: .largeTitle))
                .fontWeight(.semibold)
                .foregroundStyle(ChronicleTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !topic.keywords.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(topic.keywords, id: \.self) { keyword in
                            ChronicleChip(text: keyword, tint: ChronicleTheme.bronze)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var narrative: some View {
        Text(topic.summary)
            .font(ChronicleTheme.bodySerif)
            .foregroundStyle(ChronicleTheme.ink.opacity(0.86))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var dynastySection: some View {
        if !dynasties.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(eyebrow: "跨时代", title: "相关政权")
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
                }
            }
        }
    }

    @ViewBuilder
    private var eventSection: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(eyebrow: "关键节点", title: "相关事件")
                ForEach(events) { event in
                    let dynastyName = repository.dynasty(id: event.dynastyID)?.name ?? "政权待核"
                    NavigationLink {
                        EventDetailView(repository: repository, event: event)
                    } label: {
                        EventRow(event: event, dynastyName: dynastyName)
                    }
                    .buttonStyle(.plain)
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

struct PeopleDirectoryView: View {
    let repository: ChronicleRepository

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    Text("人物")
                        .font(ChronicleTheme.title)
                        .foregroundStyle(ChronicleTheme.ink)
                    Text("从君主、将相与改革者，到思想、科学、技术和航海人物。")
                        .font(ChronicleTheme.bodySerif)
                        .foregroundStyle(ChronicleTheme.secondaryInk)

                    ForEach(ChroniclePersonKind.allCases, id: \.self) { kind in
                        let people = repository.dataset.people.filter { $0.kind == kind }
                        if !people.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                directoryHeading(kind.label, count: people.count)
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
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("人物")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func directoryHeading(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(ChronicleTheme.section)
                .foregroundStyle(ChronicleTheme.ink)
            Spacer()
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ChronicleTheme.faintInk)
        }
        .padding(.top, 10)
    }
}

struct PlacesDirectoryView: View {
    let repository: ChronicleRepository

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Text("地点")
                        .font(ChronicleTheme.title)
                        .foregroundStyle(ChronicleTheme.ink)
                    Text("历史名称、现代位置，以及它们在多个政权中的角色。")
                        .font(ChronicleTheme.bodySerif)
                        .foregroundStyle(ChronicleTheme.secondaryInk)
                        .padding(.bottom, 8)
                    ForEach(repository.dataset.places) { place in
                        NavigationLink {
                            PlaceDetailView(repository: repository, place: place)
                        } label: {
                            LinkedEntityRow(
                                title: place.name,
                                eyebrow: "历史地点",
                                detail: place.modernName
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("地点")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct TopicsDirectoryView: View {
    let repository: ChronicleRepository

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    Text("主题")
                        .font(ChronicleTheme.title)
                        .foregroundStyle(ChronicleTheme.ink)
                    Text("沿制度、军事、经济、技术、社会与文化线索跨时代阅读。")
                        .font(ChronicleTheme.bodySerif)
                        .foregroundStyle(ChronicleTheme.secondaryInk)

                    ForEach(ChronicleTopicCategory.allCases, id: \.self) { category in
                        let topics = repository.dataset.topics.filter { $0.category == category }
                        if !topics.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                directoryHeading(category.label, count: topics.count)
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("主题")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func directoryHeading(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(ChronicleTheme.section)
                .foregroundStyle(ChronicleTheme.ink)
            Spacer()
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ChronicleTheme.faintInk)
        }
        .padding(.top, 10)
    }
}
