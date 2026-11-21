import Foundation

enum AgentPlanningPolicy {
    /// Small, broadly useful tools that must survive every relevance filter.
    static let coreToolNames: Set<String> = [
        "get_weather",
        "list_reminders",
        "create_reminder",
        "list_calendar_events",
        "search_web"
    ]

    static func batchBudget(for taskCount: Int) -> Int {
        min(10, max(3, taskCount + 2))
    }

    static func shouldRevisePlan(
        results: [ToolResultPayload],
        taskCount: Int,
        previousRevisions: Int
    ) -> Bool {
        guard taskCount > 1, previousRevisions < 1, !results.isEmpty else { return false }
        let failedStatuses: Set<String> = ["failed", "execution_unknown"]
        return results.allSatisfy { failedStatuses.contains($0.status) }
    }
}
