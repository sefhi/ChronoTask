import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var timerManager = TimerManager()
    @State private var tasks: [ClickUpTask] = []
    @State private var selectedTask: ClickUpTask?
    @State private var isLoadingTasks = true
    @State private var loadError: String?
    @State private var toast: Toast?
    @State private var keyMonitor: Any?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                // Timer row
                timerRow
                    .padding(.horizontal, Theme.paddingXL)
                    .padding(.top, Theme.paddingLarge)

                // Task list (always visible)
                taskListSection
                    .padding(.horizontal, Theme.paddingXL)
                    .padding(.top, Theme.paddingMedium)

                // Status
                statusView
                    .padding(.horizontal, Theme.paddingXL)
                    .padding(.top, Theme.paddingMedium)

                Spacer(minLength: 0)

                footerBar
            }

            // Toast overlay
            if let toast = toast {
                VStack {
                    ToastView(toast: toast)
                        .padding(.top, 4)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadTasks() }
        .onAppear {
            configureTimer()
            observeSleepWake()
            installKeyMonitor()
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
        .onChange(of: timerManager.syncError) { error in
            if let error = error {
                showToast(message: error, type: .error)
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button(action: { appState.logout() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Settings / Logout")

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.primary)
                Text("TIMER")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .tracking(1)
            }

            Spacer()

            Button(action: closeApp) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, Theme.paddingLarge)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    // MARK: - Timer Row (unified, adapts to state)

    private var timerRow: some View {
        HStack(alignment: .center) {
            Text(timerManager.elapsed.timerFormatted)
                .font(Theme.timerFont)
                .monospacedDigit()
                .foregroundColor(timerManager.isRunning ? Theme.timerRunningColor : Theme.timerIdleColor)
                .tracking(2)

            if timerManager.isSyncing {
                Circle()
                    .fill(Theme.success)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            PlayStopButton(
                isRunning: timerManager.isRunning,
                isDisabled: !timerManager.isRunning && (selectedTask == nil || timerManager.isSyncing),
                action: toggleTimer
            )
        }
        .padding(12)
        .background(Theme.background.opacity(0.5))
        .cornerRadius(Theme.cornerRadiusLG)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusLG)
                .stroke(timerManager.isRunning ? Theme.primary.opacity(0.4) : Theme.border, lineWidth: 1)
        )
    }

    // MARK: - Task List Section

    private var taskListSection: some View {
        TaskSelector(tasks: tasks, selectedTask: $selectedTask)
            .onChange(of: selectedTask?.id) { _ in
                handleTaskChange()
            }
    }

    // MARK: - Status View

    @ViewBuilder
    private var statusView: some View {
        if let error = loadError {
            Text(error)
                .font(.system(size: 10))
                .foregroundColor(Theme.error)
                .lineLimit(2)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            // User avatar
            if case .authenticated(let user, _) = appState.authState {
                Text(user.initials)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(Theme.surfaceLight)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Theme.surface, lineWidth: 2)
                    )
            }

            Spacer()

            // Refresh button
            Button(action: { Task { await loadTasks() } }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(isLoadingTasks ? Theme.primary : Theme.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(isLoadingTasks)
            .help("Refresh tasks")

            Text("v1.0.0")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textMuted)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Actions

    private func configureTimer() {
        if case .authenticated(_, let team) = appState.authState {
            timerManager.configure(teamId: team.id)
        }
    }

    private func toggleTimer() {
        if timerManager.isRunning {
            timerManager.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if timerManager.syncError == nil && !timerManager.isSyncing {
                    showToast(message: "Time entry saved", type: .success)
                }
            }
        } else if let task = selectedTask {
            timerManager.start(task: task)
        }
    }

    private func handleTaskChange() {
        guard let newTask = selectedTask else { return }
        if timerManager.isRunning {
            timerManager.switchTask(to: newTask)
        }
    }

    private func loadTasks() async {
        guard case .authenticated(let user, let team) = appState.authState else {
            NSLog("[MainView] loadTasks: not authenticated, skipping")
            return
        }
        NSLog("[MainView] loadTasks: teamId=\(team.id) userId=\(user.id)")
        isLoadingTasks = true
        loadError = nil
        do {
            tasks = try await ClickUpAPI.shared.getTasks(teamId: team.id, userId: user.id)
            NSLog("[MainView] loadTasks: loaded \(tasks.count) tasks")
            if tasks.isEmpty {
                loadError = "No tasks assigned to you"
            }
        } catch let error as APIError {
            NSLog("[MainView] loadTasks API error: \(error)")
            if case .unauthorized = error {
                appState.logout()
                return
            }
            loadError = error.localizedDescription
        } catch {
            NSLog("[MainView] loadTasks error: \(error)")
            loadError = "Failed to load tasks: \(error.localizedDescription)"
        }
        isLoadingTasks = false
    }

    private func closeApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Toast

    private func showToast(message: String, type: ToastType) {
        withAnimation(Theme.defaultAnimation) {
            toast = Toast(message: message, type: type)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(Theme.defaultAnimation) {
                toast = nil
            }
        }
    }

    // MARK: - Keyboard Shortcut

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Space (49) or Enter (36) toggles play/stop
            guard event.keyCode == 49 || event.keyCode == 36 else { return event }

            // Don't intercept if a text field is focused (user is typing)
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSTextView {
                return event
            }

            // Only toggle if we can (task selected or timer running)
            if timerManager.isRunning || selectedTask != nil {
                toggleTimer()
                return nil
            }
            return event
        }
    }

    // MARK: - Sleep/Wake

    private func observeSleepWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            timerManager.recalculateElapsed()
        }
    }
}
