import SwiftUI
import UIKit

struct PeopleView: View {
    @Environment(ContentRepository.self) private var content
    @State private var query = ""
    @State private var group = PeopleGroup.all

    private enum PeopleGroup: String, CaseIterable, Identifiable {
        case all = "全部"
        case generals = "名将"
        case ministers = "能臣"
        case court = "权臣阉党"
        var id: String { rawValue }
    }

    private var people: [Person] {
        content.bundle.people.filter { person in
            let groupMatch: Bool = switch group {
            case .all: true
            case .generals: ["武将", "边将·辽东"].contains(person.side)
            case .ministers: ["文臣", "言官·东林"].contains(person.side)
            case .court: ["宦官", "阉党"].contains(person.side) || person.name == "周延儒" || person.name == "严嵩"
            }
            let queryMatch = query.isEmpty || "\(person.name) \(person.role) \(person.side) \(person.bio)".localizedCaseInsensitiveContains(query)
            return groupMatch && queryMatch
        }
    }

    var body: some View {
        List {
            Picker("人物分组", selection: $group) {
                ForEach(PeopleGroup.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section("\(group.rawValue) · \(people.count) 人") {
                ForEach(people) { person in
                    NavigationLink(value: AppRoute.person(person.id)) {
                        HStack(spacing: 12) {
                            PortraitThumbnail(person: person)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name).font(.headline)
                                Text("\(person.role) · \(person.years)")
                                    .font(.caption)
                                    .foregroundStyle(DamingTheme.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "姓名、身份、事件或地点")
        .navigationTitle("人物")
        .background(DamingTheme.ground)
    }
}

struct PortraitThumbnail: View {
    let person: Person

    var body: some View {
        ZStack {
            Circle().fill(DamingTheme.raised)
            if let image = PortraitAssetLoader.image(for: person) {
                Image(uiImage: image).resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(String(person.name.prefix(1)))
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(DamingTheme.accent)
            }
        }
        .frame(width: 44, height: 44)
        .overlay(Circle().stroke(DamingTheme.separator, lineWidth: 1))
    }
}

enum PortraitAssetLoader {
    static func image(for person: Person) -> UIImage? {
        guard person.portrait.status == "historical",
              let src = person.portrait.src else { return nil }
        let url = URL(fileURLWithPath: src)
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        if let bundled = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "portraits")
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "assets/portraits")
            ?? Bundle.main.url(forResource: name, withExtension: ext) {
            return UIImage(contentsOfFile: bundled.path)
        }
        return nil
    }
}
