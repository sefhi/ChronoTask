import AppKit
import Combine
import Foundation

/// Composition root.
///
/// The timer used to live inside `MainView`. It cannot any more: the menu bar clock
/// and the peek both have to observe it while the panel is closed, and the panel's
/// view tree no longer outlives a session. Everything long-lived is owned here and
/// handed to whoever needs it — SwiftUI by `environmentObject`, AppKit by Combine.
@MainActor
final class AppEnvironment: ObservableObject {

    let api: ClickUpAPIClient
    let preferences: AppPreferences
    let sessionStore: SessionStore
    let pendingQueue: PendingEntryQueue
    let appState: AppState
    let timerManager: TimerManager
    let taskStore: TaskStore
    let dailyTotal: DailyTotalService

    private var cancellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var queueTimer: Timer?

    init(api: ClickUpAPIClient = ClickUpAPI.shared,
         defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init) {
        self.api = api
        self.preferences = AppPreferences(defaults: defaults)
        self.sessionStore = SessionStore(defaults: defaults)
        self.pendingQueue = PendingEntryQueue(api: api, defaults: defaults, now: now)
        self.appState = AppState()
        self.timerManager = TimerManager(api: api,
                                         sessionStore: sessionStore,
                                         pendingQueue: pendingQueue,
                                         now: now)
        self.taskStore = TaskStore(api: api, preferences: preferences, now: now)
        self.dailyTotal = DailyTotalService(api: api, now: now)
    }

    deinit {
        queueTimer?.invalidate()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: - Bootstrap

    func bootstrap() {
        wireAuth()
        wireTimer()
        wireNotifications()
        observeQueue()

        taskStore.restoreSelection()
        taskStore.onUnauthorized = { [weak self] in
            self?.appState.logout()
        }
        timerManager.restoreSession()

        Task { await flushPendingEntries() }
    }

    /// Credentials flow down to every service that needs them.
    private func wireAuth() {
        appState.$authState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self, case .authenticated(let user, let team) = state else { return }
                self.preferences.lastTeamId = team.id
                self.timerManager.configure(teamId: team.id)
                self.taskStore.configure(teamId: team.id, userId: user.id)
                self.dailyTotal.configure(teamId: team.id, userId: user.id)
                Task {
                    await self.dailyTotal.refresh(force: true)
                    await self.taskStore.loadIfStale()
                }
            }
            .store(in: &cancellables)
    }

    private func wireTimer() {
        // A synced entry lands in today's total right away, then gets confirmed by a
        // real refresh.
        timerManager.didSyncEntry
            .receive(on: RunLoop.main)
            .sink { [weak self] duration in
                guard let self else { return }
                self.dailyTotal.applyOptimistic(seconds: duration)
                Task {
                    await self.flushPendingEntries()
                    await self.dailyTotal.refresh(force: true)
                }
            }
            .store(in: &cancellables)

        // Poll the daily total only while something is being timed.
        timerManager.$state
            .map { $0 == .running }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isRunning in
                self?.dailyTotal.setPollingEnabled(isRunning)
            }
            .store(in: &cancellables)
    }

    private func wireNotifications() {
        // These used to be registered in `MainView.onAppear` and never removed, which
        // with an ephemeral panel would stack up duplicates on every open.
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification) { [weak self] in
            guard let self else { return }
            self.timerManager.recalculateElapsed()
            self.dailyTotal.rolloverIfNeeded()
            Task { await self.dailyTotal.refresh() }
        }

        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.willSleepNotification) { [weak self] in
            self?.timerManager.persistHeartbeat()
        }

        observe(NotificationCenter.default, NSApplication.willTerminateNotification) { [weak self] in
            self?.timerManager.persistHeartbeat()
        }

        observe(NotificationCenter.default, .refreshTasksRequested) { [weak self] in
            self?.requestRefresh()
        }

        observe(NotificationCenter.default, .NSCalendarDayChanged) { [weak self] in
            self?.dailyTotal.rolloverIfNeeded()
        }
    }

    private func observe(_ center: NotificationCenter,
                         _ name: Notification.Name,
                         handler: @escaping @MainActor () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            // Hopping through a Task rather than `MainActor.assumeIsolated`, which is
            // macOS 14+.
            Task { @MainActor in handler() }
        }
        observers.append(token)
    }

    // MARK: - Panel lifecycle

    /// Called by the AppKit layer whenever the panel becomes visible.
    func panelDidOpen() {
        dailyTotal.rolloverIfNeeded()
        Task {
            await taskStore.loadIfStale()
            await dailyTotal.refresh()
            await flushPendingEntries()
        }
    }

    /// Nothing is torn down on close — the timer, the cache and the totals all keep
    /// living so the next open is instant.
    func panelDidClose() {}

    func requestRefresh() {
        Task {
            await taskStore.refresh()
            await dailyTotal.refresh(force: true)
        }
    }

    // MARK: - App-level actions

    /// macOS's own About window. An agent app has no menu bar to reach it from, so
    /// this is the only way in — and it has to activate first, or the panel would be
    /// ordered above it.
    func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    /// Uploads the running stretch before terminating instead of leaving it to be
    /// recovered on next launch. A failed upload lands in the retry queue, which is on
    /// disk and survives the quit — either way the time is not lost.
    func quit() {
        Task {
            if timerManager.isRunning {
                await timerManager.stopAll()
            }
            NSApp.terminate(nil)
        }
    }

    // MARK: - Pending queue

    private func flushPendingEntries() async {
        let synced = await pendingQueue.flush()
        if synced > 0 {
            await dailyTotal.refresh(force: true)
        }
        updateQueueTimer()
    }

    /// Starts the retry ticker as soon as something lands in the queue, rather than
    /// waiting for the next flush — otherwise a failed upload with nothing else going
    /// on would sit there until the panel was next opened.
    private func observeQueue() {
        pendingQueue.$entries
            .map { !$0.isEmpty }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateQueueTimer() }
            .store(in: &cancellables)
    }

    /// Retry ticker runs only while something is actually waiting to be sent.
    private func updateQueueTimer() {
        if pendingQueue.hasPending {
            guard queueTimer == nil else { return }
            let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
                Task { @MainActor in await self?.flushPendingEntries() }
            }
            RunLoop.main.add(timer, forMode: .common)
            queueTimer = timer
        } else {
            queueTimer?.invalidate()
            queueTimer = nil
        }
    }
}
