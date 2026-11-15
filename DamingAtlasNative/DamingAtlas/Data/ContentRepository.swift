import Foundation
import Observation

enum ContentRepositoryError: LocalizedError {
    case missingBundle
    case invalidBundle(Error)

    var errorDescription: String? {
        switch self {
        case .missingBundle: "应用内缺少 content-bundle.json。"
        case .invalidBundle(let error): "内容包无法解析：\(error.localizedDescription)"
        }
    }
}

@MainActor
@Observable
final class ContentRepository {
    let bundle: ContentBundle
    let peopleByID: [String: Person]
    let eventsByID: [String: HistoryEvent]
    let chaptersByNumber: [Int: Chapter]
    let sourcesByID: [String: SourceDocument]
    let memorialsByID: [String: Memorial]
    let worksByID: [String: ReferenceWork]

    init(bundle: ContentBundle) {
        self.bundle = bundle
        peopleByID = Dictionary(uniqueKeysWithValues: bundle.people.map { ($0.id, $0) })
        eventsByID = Dictionary(uniqueKeysWithValues: bundle.events.map { ($0.id, $0) })
        chaptersByNumber = Dictionary(uniqueKeysWithValues: bundle.chapters.map { ($0.no, $0) })
        sourcesByID = Dictionary(uniqueKeysWithValues: bundle.sources.map { ($0.id, $0) })
        memorialsByID = Dictionary(uniqueKeysWithValues: bundle.memorials.map { ($0.id, $0) })
        worksByID = Dictionary(uniqueKeysWithValues: bundle.works.map { ($0.id, $0) })
    }

    static func loadBundled() throws -> ContentRepository {
        guard let url = Bundle.main.url(forResource: "content-bundle", withExtension: "json") else {
            throw ContentRepositoryError.missingBundle
        }
        do {
            let data = try Data(contentsOf: url)
            return ContentRepository(bundle: try JSONDecoder().decode(ContentBundle.self, from: data))
        } catch {
            throw ContentRepositoryError.invalidBundle(error)
        }
    }

    func search(_ query: String) -> [SearchHit] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else { return [] }
        let people = bundle.people
            .filter { "\($0.name) \($0.role) \($0.side) \($0.bio)".localizedCaseInsensitiveContains(needle) }
            .prefix(8)
            .map { SearchHit(route: .person($0.id), title: $0.name, subtitle: "\($0.role) · \($0.years)") }
        let events = bundle.events
            .filter { "\($0.title) \($0.place) \($0.text)".localizedCaseInsensitiveContains(needle) }
            .prefix(8)
            .map { SearchHit(route: .event($0.id), title: $0.title, subtitle: "\($0.time.display) · \($0.place)") }
        return Array(people) + Array(events)
    }
}

struct SearchHit: Identifiable {
    var id: String { route.id }
    let route: AppRoute
    let title: String
    let subtitle: String
}
