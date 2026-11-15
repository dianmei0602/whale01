import SwiftUI
import UIKit

struct PersonDossierView: View {
    @Environment(ContentRepository.self) private var content
    let personID: String

    private var person: Person? { content.peopleByID[personID] }
    private var events: [HistoryEvent] {
        (person?.eventIds ?? []).compactMap { content.eventsByID[$0] }
    }
    private var relations: [PersonRelation] {
        content.bundle.relations.filter { $0.from == personID || $0.to == personID }
    }

    var body: some View {
        ScrollView {
            if let person {
                VStack(alignment: .leading, spacing: 18) {
                    PersonPortraitView(person: person)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("人物详传 · \(person.side)").font(.caption).foregroundStyle(DamingTheme.accent)
                        Text(person.name).font(.system(size: 30, weight: .bold, design: .serif))
                        Text("\(person.years) · \(person.alias.isEmpty ? person.role : person.alias)")
                            .foregroundStyle(DamingTheme.secondary)
                    }
                    DamingCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(person.arc).font(.system(.title3, design: .serif))
                            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                                GridRow { detail("生卒", person.years); detail("身份", person.side) }
                                GridRow { detail("结局", person.end); detail("可考大事", "\(person.deeds.count) 项 · \(events.count) 篇史事") }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    SectionTitle("生平")
                    Text(person.bio).font(.system(.body, design: .serif)).lineSpacing(9)
                    if !person.memoir.isEmpty {
                        SectionTitle("第一人称自述 · 文学重构")
                        Text(person.memoir)
                            .font(.system(.body, design: .serif))
                            .lineSpacing(9)
                            .padding()
                            .background(DamingTheme.raised)
                    }
                    if !person.stages.isEmpty {
                        SectionTitle("人生阶段")
                        ForEach(Array(person.stages.enumerated()), id: \.offset) { _, stage in
                            HStack(alignment: .top, spacing: 12) {
                                Text(stage.year ?? stage.era ?? "").font(.caption).foregroundStyle(DamingTheme.accent).frame(width: 58, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stage.title ?? stage.label ?? "").font(.headline)
                                    Text(stage.text).font(.system(.subheadline, design: .serif)).foregroundStyle(DamingTheme.secondary)
                                }
                            }
                        }
                    }
                    SectionTitle("关联史事")
                    ForEach(events) { event in
                        NavigationLink(value: AppRoute.event(event.id)) {
                            DamingCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.time.display).font(.caption).foregroundStyle(DamingTheme.accent)
                                    Text(event.title).font(.headline)
                                    Text(event.place).font(.caption).foregroundStyle(DamingTheme.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    SectionTitle("人物关系 · \(relations.count)")
                    ForEach(relations.prefix(8)) { relation in
                        let otherID = relation.from == personID ? relation.to : relation.from
                        if let other = content.peopleByID[otherID] {
                            NavigationLink(value: AppRoute.person(other.id)) {
                                HStack {
                                    Text(other.name).font(.headline)
                                    Spacer()
                                    Text(relation.types.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(DamingTheme.secondary)
                                }
                            }
                        }
                    }
                    SourceEvidenceView(refs: person.sourceRefs, title: person.contentTier == "core" ? "深度详传" : "人物档案")
                }
                .padding(20)
            }
        }
        .navigationTitle(person?.name ?? "人物")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(DamingTheme.secondary)
            Text(value).font(.subheadline)
        }
    }
}

struct PersonPortraitView: View {
    let person: Person

    private var historicalImage: UIImage? {
        PortraitAssetLoader.image(for: person)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle().fill(portraitBackground)
            if let image = historicalImage {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                VStack(spacing: -12) {
                    ZStack(alignment: .top) {
                        Ellipse().fill(Color(red: 0.84, green: 0.76, blue: 0.67)).frame(width: 54, height: 66)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DamingTheme.ink)
                            .frame(width: 72, height: 18)
                            .offset(y: -8)
                    }
                    Path { path in
                        path.move(to: CGPoint(x: 45, y: 105))
                        path.addCurve(to: CGPoint(x: 175, y: 105), control1: CGPoint(x: 65, y: 64), control2: CGPoint(x: 155, y: 64))
                        path.addLine(to: CGPoint(x: 205, y: 150))
                        path.addLine(to: CGPoint(x: 15, y: 150))
                        path.closeSubpath()
                    }
                    .fill(DamingTheme.ink)
                    .frame(width: 220, height: 96)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: 8)
            }

            Text(person.portrait.label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(DamingTheme.surface.opacity(0.94))
                .padding(12)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(historicalImage == nil ? nil : 4.0 / 5.0, contentMode: .fit)
        .frame(height: historicalImage == nil ? 190 : nil)
        .clipShape(RoundedRectangle(cornerRadius: DamingTheme.corner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DamingTheme.corner, style: .continuous)
                .stroke(DamingTheme.separator)
        }
    }

    private var portraitBackground: Color {
        if ["武将", "边将·辽东"].contains(person.side) { return Color(red: 0.84, green: 0.87, blue: 0.85) }
        if ["后妃外戚", "宗室"].contains(person.side) { return Color(red: 0.91, green: 0.85, blue: 0.83) }
        return DamingTheme.raised
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.system(.title3, design: .serif).bold()) }
}

struct SourceEvidenceView: View {
    @Environment(ContentRepository.self) private var content
    let refs: [SourceRef]
    let title: String

    var body: some View {
        DamingCard {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("史料与可信度").font(.headline)
                    Spacer()
                    Text(title).font(.caption).foregroundStyle(DamingTheme.secondary)
                }
                Text("当前来源到书目层级，卷次、篇目和页码仍需逐条校订。")
                    .font(.caption)
                    .foregroundStyle(DamingTheme.secondary)
                ForEach(refs, id: \.sourceId) { ref in
                    if let source = content.sourcesByID[ref.sourceId] {
                        Text("\(source.title) · \(ref.status)")
                            .font(.caption)
                            .foregroundStyle(DamingTheme.accent)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
