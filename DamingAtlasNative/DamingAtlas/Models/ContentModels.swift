import Foundation

struct ContentBundle: Codable {
    let meta: ContentMeta
    let people: [Person]
    let events: [HistoryEvent]
    let chapters: [Chapter]
    let relations: [PersonRelation]
    let places: [HistoricalPlace]
    let sources: [SourceDocument]
    let memorials: [Memorial]
    let works: [ReferenceWork]
    let editorial: EditorialContent
}

struct ContentMeta: Codable {
    let schemaVersion: String
    let contentVersion: String
    let people: Int
    let events: Int
    let chapters: Int
    let missingEventPeople: Int
    let portraitFallbacks: Int
}

struct Person: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let alias: String
    let side: String
    let years: String
    let span: [Int]
    let role: String
    let arc: String
    let bio: String
    let deeds: [[String]]
    let end: String
    let note: String
    let threads: [String]
    let eventIds: [String]
    let stages: [LifeStage]
    let memoir: String
    let editorialType: String
    let contentTier: String
    let sourceRefs: [SourceRef]
    let portrait: Portrait
}

struct LifeStage: Codable, Hashable {
    let year: String?
    let era: String?
    let title: String?
    let label: String?
    let text: String
}

struct Portrait: Codable, Hashable {
    let personId: String
    let status: String
    let src: String?
    let label: String
    let note: String
    let sourcePage: String?
    let license: String?
    let credit: String?
    let reviewStatus: String?
}

struct SourceRef: Codable, Hashable {
    let sourceId: String
    let locator: String?
    let status: String
    let note: String?
}

struct HistoryEvent: Codable, Identifiable, Hashable {
    let id: String
    let year: Int
    let date: String?
    let era: String?
    let title: String
    let cat: String
    let place: String
    let text: String
    let people: [String]
    let threads: [String]
    let cost: String?
    let hook: String?
    let sourceRefs: [SourceRef]
    let time: HistoricalTime
    let placeRefs: [PlaceRef]
    let uncertaintyFlags: [String]
}

struct HistoricalTime: Codable, Hashable {
    let year: Int
    let month: Int?
    let precision: String
    let sortValue: Int
    let display: String
    let uncertainty: String
}

struct PlaceRef: Codable, Hashable {
    let placeId: String
    let match: String
    let confidence: String
}

struct Chapter: Codable, Identifiable, Hashable {
    var id: Int { no }
    let no: Int
    let volume: String
    let title: String
    let years: String
    let from: Int
    let to: Int
    let intro: String
    let events: [String]
    let eventIds: [String]
    let people: [String]
    let thread: String
    let hook: String
    let membershipBasis: String
}

struct PersonRelation: Codable, Identifiable, Hashable {
    let id: String
    let from: String
    let to: String
    let types: [String]
    let evidenceEventIds: [String]
    let evidence: [String]
    let basis: String
    let reviewStatus: String
}

struct HistoricalPlace: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let lon: Double
    let lat: Double
    let keywords: [String]
}

struct SourceDocument: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let type: String
    let citationStatus: String
    let locator: String?
    let note: String
}

struct Memorial: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let authorId: String?
    let year: Int
    let eventId: String?
    let status: String
    let excerpt: String
    let note: String
    let sourceRefs: [String]
}

struct ReferenceWork: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let period: String
    let category: String
    let summary: String
    let note: String
}

struct EditorialContent: Codable {
    let intro: String
    let threads: [ThreadEssay]
    let institutions: [Institution]
    let acts: [ActEssay]
    let laws: [String]
}

struct ThreadEssay: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let color: String
    let logic: String
    let stages: [LifeStage]
    let cross: String
}

struct Institution: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let text: String
}

struct ActEssay: Codable, Identifiable, Hashable {
    var id: Int { no }
    let no: Int
    let years: String
    let title: String
    let opening: String
    let turning: String
    let cost: String
    let hook: String
}
