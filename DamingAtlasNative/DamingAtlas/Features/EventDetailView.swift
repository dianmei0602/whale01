import SwiftUI

struct EventDetailView: View {
    @Environment(ContentRepository.self) private var content
    let eventID: String

    private var event: HistoryEvent? { content.eventsByID[eventID] }
    private var people: [Person] {
        (event?.people ?? []).compactMap { content.peopleByID[$0] }
    }

    var body: some View {
        ScrollView {
            if let event {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(event.cat) · \(event.time.display)").font(.caption).foregroundStyle(DamingTheme.accent)
                    Text(event.title).font(.system(size: 28, weight: .bold, design: .serif))
                    Text("\(event.era ?? "") · \(event.place)").foregroundStyle(DamingTheme.secondary)
                    DamingCard {
                        HStack {
                            eventMetric("时局", event.era ?? "\(event.year)")
                            Divider()
                            eventMetric("在局者", "\(event.people.count) 人")
                            Divider()
                            eventMetric("时间精度", event.time.precision == "month" ? "月份" : "年份")
                        }
                    }
                    Text(event.text).font(.system(.body, design: .serif)).lineSpacing(9)
                    if let cost = event.cost { DamingCard { Text("代价：\(cost)") } }
                    if let hook = event.hook { DamingCard { Text("余波：\(hook)") } }
                    SourceEvidenceView(refs: event.sourceRefs, title: event.time.precision == "month" ? "月份精度" : "仅记年份")
                    SectionTitle("在场人物 · \(people.count)")
                    ForEach(people) { person in
                        NavigationLink(value: AppRoute.person(person.id)) {
                            HStack {
                                PortraitThumbnail(person: person)
                                VStack(alignment: .leading) {
                                    Text(person.name).font(.headline)
                                    Text(person.role).font(.caption).foregroundStyle(DamingTheme.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(event?.title ?? "事件")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func eventMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption).foregroundStyle(DamingTheme.secondary)
            Text(value).font(.subheadline).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
