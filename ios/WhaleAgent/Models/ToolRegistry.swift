import Foundation

struct ToolContract: Decodable {
    struct Tool: Decodable {
        let name: String
        let skill: String
        let description: String
        let requiresConfirmation: Bool
        let inputSchema: JSONValue
    }

    let tools: [Tool]
}

enum ToolRegistry {
    static let tools: [ToolContract.Tool] = load()

    static var names: Set<String> {
        Set(tools.map(\.name))
    }

    static func availableToolNames(for skill: AgentSkill) -> Set<String> {
        let financeNames: Set<String> = [
            "get_stock_quote", "search_stock", "get_stock_kline", "get_stock_intraday",
            "add_to_watchlist", "remove_from_watchlist", "list_watchlist"
        ]
        if skill == .finance {
            return names.intersection(financeNames)
        }
        let acceptedSkills: Set<String>
        switch skill {
        case .messaging:
            acceptedSkills = ["messaging", "communication"]
        case .research:
            acceptedSkills = ["research"]
        case .finance:
            acceptedSkills = []
        case .general, .writing, .coding, .entertainment:
            return []
        default:
            acceptedSkills = [skill.rawValue]
        }
        return Set(
            tools
                .filter { acceptedSkills.contains($0.skill) && !financeNames.contains($0.name) }
                .map(\.name)
        )
    }

    private static func load() -> [ToolContract.Tool] {
        let url = Bundle.main.url(forResource: "tools.v1", withExtension: "json")
            ?? Bundle.main.url(forResource: "tools.v1", withExtension: "json", subdirectory: "Resources")
        guard let url,
              let data = try? Data(contentsOf: url),
              let contract = try? JSONDecoder().decode(ToolContract.self, from: data) else {
            return []
        }
        return contract.tools.filter { $0.name != "summarize_shared_content" }
    }
}
