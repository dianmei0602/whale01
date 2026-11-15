import Foundation

enum StockDetailParser {
    static func parseProfile(data: Data) throws -> StockProfileSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              let marketCap = number(payload["f116"]),
              let floatCap = number(payload["f117"]),
              let pe = number(payload["f162"]),
              let pb = number(payload["f167"]),
              let totalShares = number(payload["f84"]),
              let floatShares = number(payload["f85"])
        else {
            throw StockDataError.invalidPayload
        }
        return StockProfileSnapshot(
            totalMarketCap: marketCap,
            floatMarketCap: floatCap,
            pe: pe,
            pb: pb,
            totalShares: totalShares,
            floatShares: floatShares
        )
    }

    static func parseFundFlow(data: Data) throws -> [StockFundFlowPoint] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              let rows = payload["klines"] as? [String]
        else {
            throw StockDataError.invalidPayload
        }

        return rows.compactMap { row in
            let fields = row.split(separator: ",").map(String.init)
            guard fields.count >= 6,
                  let main = Double(fields[1]),
                  let small = Double(fields[2]),
                  let medium = Double(fields[3]),
                  let large = Double(fields[4]),
                  let superLarge = Double(fields[5])
            else { return nil }
            return StockFundFlowPoint(
                date: fields[0],
                mainNet: main,
                smallNet: small,
                mediumNet: medium,
                largeNet: large,
                superLargeNet: superLarge
            )
        }
    }

    static func parseSectors(data: Data) throws -> [StockSectorSnapshot] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              let rows = payload["diff"] as? [[String: Any]]
        else {
            throw StockDataError.invalidPayload
        }

        return rows.compactMap { row in
            guard let code = row["f12"] as? String,
                  let name = row["f14"] as? String,
                  let change = number(row["f3"]),
                  let inflow = number(row["f62"]),
                  let ratio = number(row["f184"])
            else { return nil }
            return StockSectorSnapshot(
                code: code,
                name: name,
                changePercent: change,
                mainNetInflow: inflow,
                mainNetRatio: ratio
            )
        }
    }

    static func parseFinance(data: Data) throws -> StockFinanceSnapshot? {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["data"] as? [[String: Any]],
              let row = rows.first,
              let report = row["REPORT_DATE_NAME"] as? String,
              let revenue = number(row["TOTALOPERATEREVE"]),
              let netProfit = number(row["PARENTNETPROFIT"]),
              let roe = number(row["ROEJQ"]),
              let gross = number(row["XSMLL"]),
              let net = number(row["XSJLL"])
        else {
            throw StockDataError.invalidPayload
        }
        return StockFinanceSnapshot(
            reportName: report,
            revenue: revenue,
            parentNetProfit: netProfit,
            roe: roe,
            grossMargin: gross,
            netMargin: net
        )
    }

    static func parseCapital(data: Data) throws -> StockCapitalSnapshot? {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["gbjg"] as? [[String: Any]],
              let row = rows.first,
              let total = number(row["TOTAL_SHARES"]),
              let unlimited = number(row["UNLIMITED_SHARES"]),
              let limited = number(row["LIMITED_SHARES"])
        else {
            throw StockDataError.invalidPayload
        }
        return StockCapitalSnapshot(
            totalShares: total,
            unlimitedShares: unlimited,
            limitedShares: limited
        )
    }

    static func parseShareholders(data: Data) throws -> [StockShareholder] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["sdgd"] as? [[String: Any]]
        else {
            throw StockDataError.invalidPayload
        }

        return rows.compactMap { row in
            guard let rank = number(row["HOLDER_RANK"]).map(Int.init),
                  let name = row["HOLDER_NAME"] as? String,
                  let ratio = number(row["HOLD_NUM_RATIO"]),
                  let shares = number(row["HOLD_NUM"])
            else { return nil }
            return StockShareholder(
                rank: rank,
                name: name,
                ratio: ratio,
                shares: shares,
                change: row["HOLD_NUM_CHANGE"] as? String ?? ""
            )
        }
        .sorted { $0.rank < $1.rank }
        .prefix(5)
        .map { $0 }
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
}

