import XCTest
@testable import ChineseChronicles

final class ChronicleTests: XCTestCase {
    private var repository: ChronicleRepository!
    private var sourceData: Data!

    override func setUpWithError() throws {
        sourceData = try bundledData()
        repository = try ChronicleRepository(data: sourceData)
    }

    func testBundledCorpusHasReviewedCoverage() {
        XCTAssertEqual(repository.dataset.schemaVersion, "1.0")
        XCTAssertEqual(repository.dataset.dynasties.count, 23)
        XCTAssertEqual(repository.dataset.events.count, 57)
        XCTAssertEqual(repository.dataset.sources.count, 25)
        XCTAssertEqual(repository.dataset.people.count, 66)
        XCTAssertEqual(repository.dataset.places.count, 23)
        XCTAssertEqual(repository.dataset.topics.count, 31)
        XCTAssertFalse(repository.dataset.editorialNote.isEmpty)
    }

    func testSearchFindsDynastyAndEvent() {
        let luoyang = repository.search("洛阳")
        XCTAssertTrue(luoyang.contains { result in
            if case .dynasty(let dynasty) = result {
                return dynasty.id == "eastern-han"
            }
            return false
        })

        let unification = repository.search("统一")
        XCTAssertTrue(unification.contains { result in
            if case .event(let event) = result {
                return event.id == "qin-unification"
            }
            return false
        })
    }

    func testDynastyEventsAreChronological() {
        let events = repository.events(for: "qing")
        XCTAssertEqual(events.map(\.date.year), [1636, 1644, 1840, 1842, 1894, 1911, 1912])
    }

    func testSearchFindsPeopleAndPlaces() {
        XCTAssertTrue(repository.search("赵构").contains { result in
            if case .person(let person) = result {
                return person.id == "song-gaozong"
            }
            return false
        })

        XCTAssertTrue(repository.search("今河南洛阳").contains { result in
            if case .place(let place) = result {
                return place.id == "luoyang"
            }
            return false
        })

        XCTAssertTrue(repository.search("郡县制").contains { result in
            if case .topic(let topic) = result {
                return topic.id == "county-system"
            }
            return false
        })
    }

    func testEveryEventHasContextAndLinks() {
        for event in repository.dataset.events {
            XCTAssertFalse(event.background.isEmpty, event.id)
            XCTAssertFalse(event.process.isEmpty, event.id)
            XCTAssertFalse(event.consequence.isEmpty, event.id)
            XCTAssertFalse(event.significance.isEmpty, event.id)
            XCTAssertFalse(event.topicIDs.isEmpty, event.id)
            XCTAssertGreaterThanOrEqual(event.sourceIDs.count, 2, event.id)
        }
    }

    func testEveryDynastyHasContextAndConnections() {
        for dynasty in repository.dataset.dynasties {
            XCTAssertFalse(dynasty.structure.isEmpty, dynasty.id)
            XCTAssertFalse(dynasty.society.isEmpty, dynasty.id)
            XCTAssertFalse(dynasty.legacy.isEmpty, dynasty.id)
            XCTAssertFalse(dynasty.peopleIDs.isEmpty, dynasty.id)
            XCTAssertFalse(dynasty.topicIDs.isEmpty, dynasty.id)
        }
    }

    func testHistoricalDatesSortWithoutYearZero() {
        let bce = HistoricalDate(
            year: -221,
            month: nil,
            day: nil,
            display: "前 221 年",
            precision: .year
        )
        let ce = HistoricalDate(
            year: 618,
            month: nil,
            day: nil,
            display: "公元 618 年",
            precision: .year
        )
        XCTAssertLessThan(bce, ce)
    }

    func testTimelineScaleMapsFullRange() {
        let scale = TimelineScale(startYear: -2200, endYear: 1950, width: 1560)
        XCTAssertEqual(scale.x(for: -2200), 0, accuracy: 0.001)
        XCTAssertEqual(scale.x(for: 1950), 1560, accuracy: 0.001)
        XCTAssertEqual(scale.x(for: 0), 826.988, accuracy: 0.01)
    }

    func testParallelDynastiesReceiveDifferentLanes() {
        let scale = TimelineScale()
        let bands = scale.bands(for: repository.dataset.dynasties)
        let song = try! XCTUnwrap(bands.first { $0.dynasty.id == "northern-song" })
        let liao = try! XCTUnwrap(bands.first { $0.dynasty.id == "liao" })
        XCTAssertNotEqual(song.lane, liao.lane)
        XCTAssertEqual(Set(bands.map(\.id)).count, repository.dataset.dynasties.count)
    }

    func testBrokenSourceReferenceIsRejected() throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: sourceData) as? [String: Any]
        )
        object["sources"] = []
        let broken = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try ChronicleRepository(data: broken))
    }

    private func bundledData() throws -> Data {
        let candidates = [
            Bundle.main,
            Bundle(for: Self.self)
        ]
        for bundle in candidates {
            if let url = bundle.url(forResource: "chronicles.v1", withExtension: "json") {
                return try Data(contentsOf: url)
            }
        }
        throw ChronicleRepositoryError.resourceMissing
    }
}
