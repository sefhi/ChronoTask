import Foundation

/// A timing session that outlived the app process.
struct PersistedSession: Codable, Equatable {
    let taskId: String
    let taskName: String
    let teamId: String
    let startedAt: Date
    /// Heartbeat: the last moment we know the app was alive and still timing.
    /// Everything after this is unaccounted for — the Mac may have been asleep.
    var savedAt: Date
}

protocol SessionPersisting: AnyObject {
    func save(_ session: PersistedSession)
    func load() -> PersistedSession?
    func clear()
}

final class SessionStore: SessionPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard,
         key: String = AppPreferences.Key.activeSession.rawValue) {
        self.defaults = defaults
        self.key = key
    }

    func save(_ session: PersistedSession) {
        guard let data = try? Self.encoder.encode(session) else { return }
        defaults.set(data, forKey: key)
    }

    func load() -> PersistedSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        // Corrupt payloads are dropped rather than thrown: a bad blob must never
        // stop the app from launching.
        return try? Self.decoder.decode(PersistedSession.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
}

/// What to do with a session found at launch.
///
/// The guiding rule: logging time the user did not work is worse than losing time
/// they did. Anything uncertain is offered to them rather than filed silently.
enum SessionRecoveryPolicy {
    /// Reopened this quickly and it is almost certainly a crash-and-relaunch.
    static let resumeGraceGap: TimeInterval = 120
    /// Nobody times a single task for half a day without touching the app.
    static let maxSessionDuration: TimeInterval = 12 * 3600
    /// Below this the entry is noise, not work.
    static let minimumSalvageable: TimeInterval = 60

    enum Outcome: Equatable {
        /// Keep counting from the original start.
        case resume
        /// Ask the user, offering only the stretch we can vouch for.
        case prompt(knownDuration: TimeInterval)
        case discard(DiscardReason)
    }

    enum DiscardReason: Equatable {
        case tooLong
        case tooShort
        case clockWentBackwards
    }

    static func evaluate(_ session: PersistedSession, now: Date) -> Outcome {
        if session.startedAt > now {
            return .discard(.clockWentBackwards)
        }
        if now.timeIntervalSince(session.startedAt) > maxSessionDuration {
            return .discard(.tooLong)
        }

        // Resume is checked before the "too short" rule on purpose: if the app was
        // reopened seconds later, the user is still working and we should keep
        // counting — even if only twenty seconds had been logged so far.
        if now.timeIntervalSince(session.savedAt) <= resumeGraceGap {
            return .resume
        }

        let knownDuration = session.savedAt.timeIntervalSince(session.startedAt)
        // Below this there is nothing worth asking about.
        if knownDuration < minimumSalvageable {
            return .discard(.tooShort)
        }
        return .prompt(knownDuration: knownDuration)
    }
}
