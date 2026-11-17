import Foundation

enum DynastyRole: String, Codable, CaseIterable {
    case mainline
    case divided
    case parallel
    case disputed

    var label: String {
        switch self {
        case .mainline:
            return "主线王朝"
        case .divided:
            return "分裂时期"
        case .parallel:
            return "并立政权"
        case .disputed:
            return "纪年有争议"
        }
    }
}

enum ChronicleSourceKind: String, Codable {
    case primary
    case reference

    var label: String {
        switch self {
        case .primary:
            return "传统文献"
        case .reference:
            return "研究参考"
        }
    }
}

struct ChronicleDynasty: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let startYear: Int
    let endYear: Int
    let startLabel: String
    let endLabel: String
    let role: DynastyRole
    let eraID: String
    let accent: String
    let capital: String
    let founder: String
    let summary: String
    let structure: String
    let society: String
    let legacy: String
    let aliases: [String]
    let peopleIDs: [String]
    let placeIDs: [String]
    let topicIDs: [String]
    let sourceIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subtitle
        case startYear
        case endYear
        case startLabel
        case endLabel
        case role
        case eraID = "eraId"
        case accent
        case capital
        case founder
        case summary
        case structure
        case society
        case legacy
        case aliases
        case peopleIDs = "peopleIds"
        case placeIDs = "placeIds"
        case topicIDs = "topicIds"
        case sourceIDs = "sourceIds"
    }

    var periodLabel: String {
        "\(startLabel) — \(endLabel)"
    }
}

struct ChronicleEra: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let range: String
    let startYear: Int
    let endYear: Int
    let summary: String
}

struct ChronicleEvent: Codable, Identifiable, Hashable {
    let id: String
    let dynastyID: String
    let date: HistoricalDate
    let title: String
    let summary: String
    let background: String
    let process: String
    let consequence: String
    let significance: String
    let importance: Int
    let tags: [String]
    let peopleIDs: [String]
    let placeIDs: [String]
    let topicIDs: [String]
    let relatedDynastyIDs: [String]
    let sourceIDs: [String]
    let caveat: String?

    enum CodingKeys: String, CodingKey {
        case id
        case dynastyID = "dynastyId"
        case date
        case title
        case summary
        case background
        case process
        case consequence
        case significance
        case importance
        case tags
        case peopleIDs = "peopleIds"
        case placeIDs = "placeIds"
        case topicIDs = "topicIds"
        case relatedDynastyIDs = "relatedDynastyIds"
        case sourceIDs = "sourceIds"
        case caveat
    }
}

struct ChronicleSource: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let kind: ChronicleSourceKind
    let citation: String
    let note: String
}

enum ChroniclePersonKind: String, Codable {
    case ruler
    case statesman
    case general
    case reformer
    case thinker
    case artist
    case scientist
    case technologist
    case navigator
    case leader

    var label: String {
        switch self {
        case .ruler: return "君主"
        case .statesman: return "政治人物"
        case .general: return "军事人物"
        case .reformer: return "改革者"
        case .thinker: return "思想人物"
        case .artist: return "文化人物"
        case .scientist: return "科学人物"
        case .technologist: return "技术人物"
        case .navigator: return "航海人物"
        case .leader: return "历史人物"
        }
    }
}

struct ChroniclePerson: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let aliases: [String]
    let kind: ChroniclePersonKind
    let periodLabel: String
    let summary: String
    let dynastyIDs: [String]
    let eventIDs: [String]
    let sourceIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case aliases
        case kind
        case periodLabel
        case summary
        case dynastyIDs = "dynastyIds"
        case eventIDs = "eventIds"
        case sourceIDs = "sourceIds"
    }
}

struct ChroniclePlace: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let modernName: String
    let summary: String
    let dynastyIDs: [String]
    let eventIDs: [String]
    let sourceIDs: [String]
    let caveat: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case modernName
        case summary
        case dynastyIDs = "dynastyIds"
        case eventIDs = "eventIds"
        case sourceIDs = "sourceIds"
        case caveat
    }
}

enum ChronicleTopicCategory: String, Codable {
    case governance
    case society
    case military
    case economy
    case culture
    case technology
    case environment

    var label: String {
        switch self {
        case .governance: return "制度"
        case .society: return "社会"
        case .military: return "军事"
        case .economy: return "经济"
        case .culture: return "文化"
        case .technology: return "技术"
        case .environment: return "环境"
        }
    }
}

struct ChronicleTopic: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: ChronicleTopicCategory
    let summary: String
    let dynastyIDs: [String]
    let eventIDs: [String]
    let sourceIDs: [String]
    let keywords: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case summary
        case dynastyIDs = "dynastyIds"
        case eventIDs = "eventIds"
        case sourceIDs = "sourceIds"
        case keywords
    }
}

struct ChronicleDataset: Codable {
    let schemaVersion: String
    let contentVersion: String
    let title: String
    let subtitle: String
    let editorialNote: String
    let reviewedAt: String
    let eras: [ChronicleEra]
    let dynasties: [ChronicleDynasty]
    let events: [ChronicleEvent]
    let sources: [ChronicleSource]
    let people: [ChroniclePerson]
    let places: [ChroniclePlace]
    let topics: [ChronicleTopic]
}

enum ChronicleSearchResult: Identifiable, Hashable {
    case dynasty(ChronicleDynasty)
    case event(ChronicleEvent)
    case person(ChroniclePerson)
    case place(ChroniclePlace)
    case topic(ChronicleTopic)

    var id: String {
        switch self {
        case .dynasty(let dynasty):
            return "dynasty-\(dynasty.id)"
        case .event(let event):
            return "event-\(event.id)"
        case .person(let person):
            return "person-\(person.id)"
        case .place(let place):
            return "place-\(place.id)"
        case .topic(let topic):
            return "topic-\(topic.id)"
        }
    }
}
