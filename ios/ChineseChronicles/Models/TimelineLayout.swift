import Foundation

struct DynastyBand: Identifiable {
    let dynasty: ChronicleDynasty
    let lane: Int

    var id: String {
        dynasty.id
    }
}

struct TimelineScale {
    let startYear: Int
    let endYear: Int
    let width: Double

    init(
        startYear: Int = -2200,
        endYear: Int = 1950,
        width: Double = 1_560
    ) {
        self.startYear = startYear
        self.endYear = endYear
        self.width = width
    }

    func x(for year: Int) -> Double {
        let span = Double(max(endYear - startYear, 1))
        let clamped = min(max(year, startYear), endYear)
        return Double(clamped - startYear) / span * width
    }

    func width(from startYear: Int, to endYear: Int, minimum: Double = 44) -> Double {
        max(x(for: endYear) - x(for: startYear), minimum)
    }

    func bands(for dynasties: [ChronicleDynasty], gap: Int = 12) -> [DynastyBand] {
        let sorted = dynasties.sorted {
            if $0.startYear == $1.startYear {
                return $0.endYear < $1.endYear
            }
            return $0.startYear < $1.startYear
        }

        var laneEnds: [Int] = []
        var result: [DynastyBand] = []

        for dynasty in sorted {
            if let lane = laneEnds.firstIndex(where: { $0 + gap < dynasty.startYear }) {
                laneEnds[lane] = dynasty.endYear
                result.append(DynastyBand(dynasty: dynasty, lane: lane))
            } else {
                result.append(DynastyBand(dynasty: dynasty, lane: laneEnds.count))
                laneEnds.append(dynasty.endYear)
            }
        }

        return result
    }
}
