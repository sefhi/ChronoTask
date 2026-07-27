import Foundation

/// Which ClickUp tasks may be tracked.
///
/// This used to live as a `private static` inside `MainView`, where it could be
/// neither tested nor reused. It is domain logic, not presentation.
enum TaskEligibility {

    /// Status names that mean "not real work": ClickUp's onboarding tips and
    /// anything already finished.
    static let excludedStatusNames: Set<String> = ["tip", "closed", "recently closed"]

    static func isEligibleForTracking(_ task: ClickUpTask) -> Bool {
        // A task with no status at all is assumed to be trackable — better to show
        // one extra row than to silently hide real work.
        guard let status = task.status else { return true }

        let name = status.status.trimmingCharacters(in: .whitespaces).lowercased()
        if excludedStatusNames.contains(name) { return false }

        if status.type?.trimmingCharacters(in: .whitespaces).lowercased() == "closed" {
            return false
        }
        return true
    }

    /// Filters a list, preserving the order the API returned (already sorted by
    /// most recently updated).
    static func filter(_ tasks: [ClickUpTask]) -> [ClickUpTask] {
        tasks.filter(isEligibleForTracking)
    }
}
