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
    let aliases: [String]
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
        case aliases
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
    let importance: Int
    let tags: [String]
    let sourceIDs: [String]
    let caveat: String?

    enum CodingKeys: String, CodingKey {
        case id
        case dynastyID = "dynastyId"
        case date
        case title
        case summary
        case importance
        case tags
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
}

enum ChronicleSearchResult: Identifiable, Hashable {
    case dynasty(ChronicleDynasty)
    case event(ChronicleEvent)

    var id: String {
        switch self {
        case .dynasty(let dynasty):
            return "dynasty-\(dynasty.id)"
        case .event(let event):
            return "event-\(event.id)"
        }
    }
}
