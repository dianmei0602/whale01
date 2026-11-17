import Foundation

enum ChronicleRepositoryError: LocalizedError {
    case resourceMissing
    case invalidSchema(String)
    case duplicateID(String)
    case missingReference(String)
    case invalidRange(String)

    var errorDescription: String? {
        switch self {
        case .resourceMissing:
            return "没有找到随 App 打包的编年史资料。"
        case .invalidSchema(let version):
            return "资料版本不受支持：\(version)"
        case .duplicateID(let id):
            return "资料中存在重复标识：\(id)"
        case .missingReference(let id):
            return "资料引用了不存在的条目：\(id)"
        case .invalidRange(let name):
            return "\(name) 的起止年份顺序不正确。"
        }
    }
}

struct ChronicleRepository {
    static let supportedSchemaVersion = "1.0"

    let dataset: ChronicleDataset

    private let dynastyIndex: [String: ChronicleDynasty]
    private let eventIndex: [String: ChronicleEvent]
    private let sourceIndex: [String: ChronicleSource]
    private let personIndex: [String: ChroniclePerson]
    private let placeIndex: [String: ChroniclePlace]
    private let topicIndex: [String: ChronicleTopic]

    init(data: Data, decoder: JSONDecoder = JSONDecoder()) throws {
        let decoded = try decoder.decode(ChronicleDataset.self, from: data)
        try Self.validate(decoded)

        dataset = decoded
        dynastyIndex = Dictionary(uniqueKeysWithValues: decoded.dynasties.map { ($0.id, $0) })
        eventIndex = Dictionary(uniqueKeysWithValues: decoded.events.map { ($0.id, $0) })
        sourceIndex = Dictionary(uniqueKeysWithValues: decoded.sources.map { ($0.id, $0) })
        personIndex = Dictionary(uniqueKeysWithValues: decoded.people.map { ($0.id, $0) })
        placeIndex = Dictionary(uniqueKeysWithValues: decoded.places.map { ($0.id, $0) })
        topicIndex = Dictionary(uniqueKeysWithValues: decoded.topics.map { ($0.id, $0) })
    }

    static func bundled(bundle: Bundle = .main) throws -> ChronicleRepository {
        guard let url = bundle.url(forResource: "chronicles.v1", withExtension: "json") else {
            throw ChronicleRepositoryError.resourceMissing
        }
        return try ChronicleRepository(data: Data(contentsOf: url))
    }

    var overviewRange: String {
        "约公元前 2070 年 — 公元 1912 年"
    }

    func dynasty(id: String) -> ChronicleDynasty? {
        dynastyIndex[id]
    }

    func event(id: String) -> ChronicleEvent? {
        eventIndex[id]
    }

    func source(id: String) -> ChronicleSource? {
        sourceIndex[id]
    }

    func person(id: String) -> ChroniclePerson? {
        personIndex[id]
    }

    func place(id: String) -> ChroniclePlace? {
        placeIndex[id]
    }

    func topic(id: String) -> ChronicleTopic? {
        topicIndex[id]
    }

    func people(ids: [String]) -> [ChroniclePerson] {
        ids.compactMap { personIndex[$0] }
    }

    func places(ids: [String]) -> [ChroniclePlace] {
        ids.compactMap { placeIndex[$0] }
    }

    func topics(ids: [String]) -> [ChronicleTopic] {
        ids.compactMap { topicIndex[$0] }
    }

    func sources(ids: [String]) -> [ChronicleSource] {
        ids.compactMap { sourceIndex[$0] }
    }

    func events(for dynastyID: String) -> [ChronicleEvent] {
        dataset.events
            .filter { $0.dynastyID == dynastyID }
            .sorted { $0.date < $1.date }
    }

    func dynasties(in eraID: String) -> [ChronicleDynasty] {
        dataset.dynasties
            .filter { $0.eraID == eraID }
            .sorted { $0.startYear < $1.startYear }
    }

    func era(id: String) -> ChronicleEra? {
        dataset.eras.first { $0.id == id }
    }

    func search(_ rawQuery: String) -> [ChronicleSearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let dynastyResults = dataset.dynasties.compactMap { dynasty -> ChronicleSearchResult? in
            let searchable = ([dynasty.name, dynasty.subtitle, dynasty.founder, dynasty.capital]
                + dynasty.aliases
                + [dynasty.summary]).joined(separator: " ")
            return searchable.localizedCaseInsensitiveContains(query) ? .dynasty(dynasty) : nil
        }

        let eventResults = dataset.events.compactMap { event -> ChronicleSearchResult? in
            let searchable = (
                [event.title, event.summary, event.background, event.process, event.consequence, event.significance, event.date.display]
                    + event.tags
            ).joined(separator: " ")
            return searchable.localizedCaseInsensitiveContains(query) ? .event(event) : nil
        }

        let peopleResults = dataset.people.compactMap { person -> ChronicleSearchResult? in
            let searchable = ([person.name, person.periodLabel, person.summary] + person.aliases)
                .joined(separator: " ")
            return searchable.localizedCaseInsensitiveContains(query) ? .person(person) : nil
        }

        let placeResults = dataset.places.compactMap { place -> ChronicleSearchResult? in
            [place.name, place.modernName, place.summary]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query) ? .place(place) : nil
        }

        let topicResults = dataset.topics.compactMap { topic -> ChronicleSearchResult? in
            ([topic.title, topic.summary] + topic.keywords)
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query) ? .topic(topic) : nil
        }

        return dynastyResults
            + eventResults.sorted { $0.id < $1.id }
            + peopleResults
            + placeResults
            + topicResults
    }

    private static func validate(_ dataset: ChronicleDataset) throws {
        guard dataset.schemaVersion == supportedSchemaVersion else {
            throw ChronicleRepositoryError.invalidSchema(dataset.schemaVersion)
        }

        try assertUnique(dataset.eras.map(\.id), label: "时代")
        try assertUnique(dataset.dynasties.map(\.id), label: "朝代")
        try assertUnique(dataset.events.map(\.id), label: "事件")
        try assertUnique(dataset.sources.map(\.id), label: "来源")
        try assertUnique(dataset.people.map(\.id), label: "人物")
        try assertUnique(dataset.places.map(\.id), label: "地点")
        try assertUnique(dataset.topics.map(\.id), label: "主题")

        let eraIDs = Set(dataset.eras.map(\.id))
        let dynastyIDs = Set(dataset.dynasties.map(\.id))
        let eventIDs = Set(dataset.events.map(\.id))
        let sourceIDs = Set(dataset.sources.map(\.id))
        let personIDs = Set(dataset.people.map(\.id))
        let placeIDs = Set(dataset.places.map(\.id))
        let topicIDs = Set(dataset.topics.map(\.id))

        for dynasty in dataset.dynasties {
            guard dynasty.startYear <= dynasty.endYear else {
                throw ChronicleRepositoryError.invalidRange(dynasty.name)
            }
            guard eraIDs.contains(dynasty.eraID) else {
                throw ChronicleRepositoryError.missingReference("\(dynasty.id).eraId=\(dynasty.eraID)")
            }
            guard !dynasty.sourceIDs.isEmpty else {
                throw ChronicleRepositoryError.missingReference("\(dynasty.id).sourceIds")
            }
            for sourceID in dynasty.sourceIDs where !sourceIDs.contains(sourceID) {
                throw ChronicleRepositoryError.missingReference("\(dynasty.id).sourceIds=\(sourceID)")
            }
            for personID in dynasty.peopleIDs where !personIDs.contains(personID) {
                throw ChronicleRepositoryError.missingReference("\(dynasty.id).peopleIds=\(personID)")
            }
            for placeID in dynasty.placeIDs where !placeIDs.contains(placeID) {
                throw ChronicleRepositoryError.missingReference("\(dynasty.id).placeIds=\(placeID)")
            }
            for topicID in dynasty.topicIDs where !topicIDs.contains(topicID) {
                throw ChronicleRepositoryError.missingReference("\(dynasty.id).topicIds=\(topicID)")
            }
        }

        for event in dataset.events {
            guard dynastyIDs.contains(event.dynastyID) else {
                throw ChronicleRepositoryError.missingReference("\(event.id).dynastyId=\(event.dynastyID)")
            }
            guard !event.sourceIDs.isEmpty else {
                throw ChronicleRepositoryError.missingReference("\(event.id).sourceIds")
            }
            for sourceID in event.sourceIDs where !sourceIDs.contains(sourceID) {
                throw ChronicleRepositoryError.missingReference("\(event.id).sourceIds=\(sourceID)")
            }
            for personID in event.peopleIDs where !personIDs.contains(personID) {
                throw ChronicleRepositoryError.missingReference("\(event.id).peopleIds=\(personID)")
            }
            for placeID in event.placeIDs where !placeIDs.contains(placeID) {
                throw ChronicleRepositoryError.missingReference("\(event.id).placeIds=\(placeID)")
            }
            for topicID in event.topicIDs where !topicIDs.contains(topicID) {
                throw ChronicleRepositoryError.missingReference("\(event.id).topicIds=\(topicID)")
            }
            for dynastyID in event.relatedDynastyIDs where !dynastyIDs.contains(dynastyID) {
                throw ChronicleRepositoryError.missingReference("\(event.id).relatedDynastyIds=\(dynastyID)")
            }
        }

        for person in dataset.people {
            for dynastyID in person.dynastyIDs where !dynastyIDs.contains(dynastyID) {
                throw ChronicleRepositoryError.missingReference("\(person.id).dynastyIds=\(dynastyID)")
            }
            for eventID in person.eventIDs where !eventIDs.contains(eventID) {
                throw ChronicleRepositoryError.missingReference("\(person.id).eventIds=\(eventID)")
            }
            for sourceID in person.sourceIDs where !sourceIDs.contains(sourceID) {
                throw ChronicleRepositoryError.missingReference("\(person.id).sourceIds=\(sourceID)")
            }
        }

        for place in dataset.places {
            for dynastyID in place.dynastyIDs where !dynastyIDs.contains(dynastyID) {
                throw ChronicleRepositoryError.missingReference("\(place.id).dynastyIds=\(dynastyID)")
            }
            for eventID in place.eventIDs where !eventIDs.contains(eventID) {
                throw ChronicleRepositoryError.missingReference("\(place.id).eventIds=\(eventID)")
            }
            for sourceID in place.sourceIDs where !sourceIDs.contains(sourceID) {
                throw ChronicleRepositoryError.missingReference("\(place.id).sourceIds=\(sourceID)")
            }
        }

        for topic in dataset.topics {
            for dynastyID in topic.dynastyIDs where !dynastyIDs.contains(dynastyID) {
                throw ChronicleRepositoryError.missingReference("\(topic.id).dynastyIds=\(dynastyID)")
            }
            for eventID in topic.eventIDs where !eventIDs.contains(eventID) {
                throw ChronicleRepositoryError.missingReference("\(topic.id).eventIds=\(eventID)")
            }
            for sourceID in topic.sourceIDs where !sourceIDs.contains(sourceID) {
                throw ChronicleRepositoryError.missingReference("\(topic.id).sourceIds=\(sourceID)")
            }
        }
    }

    private static func assertUnique(_ ids: [String], label: String) throws {
        var seen = Set<String>()
        for id in ids {
            guard seen.insert(id).inserted else {
                throw ChronicleRepositoryError.duplicateID("\(label)：\(id)")
            }
        }
    }
}
