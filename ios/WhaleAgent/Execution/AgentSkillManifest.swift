import Foundation

struct AgentSkillDefinition: Codable, Equatable {
    enum Kind: String, Codable {
        case tool
        case thinking
    }

    let id: String
    let kind: Kind
    let tools: [String]
    let guidance: String
}

struct AgentSkillManifest: Codable, Equatable {
    let version: String
    let skills: [AgentSkillDefinition]

    func definition(for skill: AgentSkill) -> AgentSkillDefinition? {
        skills.first { $0.id == skill.rawValue }
    }

    var isValid: Bool {
        let ids = Set(skills.map(\.id))
        return version == "2.0"
            && skills.count == AgentSkill.allCases.count
            && AgentSkill.allCases.allSatisfy { ids.contains($0.rawValue) }
            && skills.allSatisfy { definition in
                definition.kind == .tool ? !definition.tools.isEmpty : definition.tools.isEmpty
            }
    }
}

enum AgentSkillManifestStore {
    static func load() -> AgentSkillManifest? {
        let url = Bundle.main.url(forResource: "skills.v2", withExtension: "json")
            ?? Bundle.main.url(forResource: "skills.v2", withExtension: "json", subdirectory: "Resources")
        guard let url,
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(AgentSkillManifest.self, from: data),
              manifest.isValid else {
            return nil
        }
        return manifest
    }

    static func guidance(for skills: [AgentSkill]) -> String {
        guard let manifest = load() else { return "" }
        return skills.compactMap { manifest.definition(for: $0) }.map { definition in
            "[\(definition.id) · \(definition.kind.rawValue)] \(definition.guidance)"
        }.joined(separator: "\n")
    }
}
