import Foundation

/// Small, non-secret preferences. The API token stays in the Keychain.
///
/// These matter more than they used to: the panel is now ephemeral, so anything
/// held only in a view's `@State` is lost every time the user clicks away.
final class AppPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    enum Key: String {
        case selectedTaskId       = "chronotask.selectedTaskId"
        case selectedTaskSnapshot = "chronotask.selectedTaskSnapshot"
        case lastTeamId           = "chronotask.lastTeamId"
        case activeSession        = "chronotask.activeSession"
        case pendingEntries       = "chronotask.pendingEntries"
    }

    var selectedTaskId: String? {
        get { defaults.string(forKey: Key.selectedTaskId.rawValue) }
        set { defaults.set(newValue, forKey: Key.selectedTaskId.rawValue) }
    }

    var lastTeamId: String? {
        get { defaults.string(forKey: Key.lastTeamId.rawValue) }
        set { defaults.set(newValue, forKey: Key.lastTeamId.rawValue) }
    }

    /// The whole selected task, not just its id, so a cold start can render the task
    /// name immediately instead of showing a placeholder until the network answers.
    var selectedTaskSnapshot: ClickUpTask? {
        get {
            guard let data = defaults.data(forKey: Key.selectedTaskSnapshot.rawValue) else { return nil }
            return try? JSONDecoder().decode(ClickUpTask.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                defaults.removeObject(forKey: Key.selectedTaskSnapshot.rawValue)
                return
            }
            defaults.set(data, forKey: Key.selectedTaskSnapshot.rawValue)
        }
    }

    /// Stores id and snapshot together — they must never disagree.
    func setSelectedTask(_ task: ClickUpTask?) {
        selectedTaskId = task?.id
        selectedTaskSnapshot = task
    }
}
