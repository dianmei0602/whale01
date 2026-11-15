import Foundation

@main
enum ContentBundleDecodeSmoke {
    static func main() throws {
        let url = URL(fileURLWithPath: "DamingAtlas/Resources/content-bundle.json")
        let data = try Data(contentsOf: url)
        let bundle = try JSONDecoder().decode(ContentBundle.self, from: data)
        precondition(bundle.people.count == 208)
        precondition(bundle.events.count == 238)
        precondition(bundle.chapters.count == 20)
        precondition(bundle.people.allSatisfy { !$0.eventIds.isEmpty })
        precondition(bundle.memorials.count == 8)
        precondition(bundle.works.count == 15)
        print("content bundle decoded: \(bundle.people.count) people, \(bundle.events.count) events")
    }
}
