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

    @State private var isHovered = false
    @State private var pickerOpen = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: Theme.paddingTop)

                TimerDisplay(elapsed: timerManager.elapsed)
                    .padding(.horizontal, Theme.paddingWindowH)

                Spacer().frame(height: Theme.gapRows)

                taskRow
                    .padding(.horizontal, Theme.paddingWindowH)

                Spacer(minLength: 0)

                StartStopBar(
                    isRunning: timerManager.isRunning,
                    isDisabled: !timerManager.isRunning
                        && (selectedTask == nil || tasks.isEmpty || timerManager.isSyncing),
                    action: toggleTimer
                )
            }

            // Drag affordance (reveal on hover)
            VStack {
                dragDots
                    .frame(height: Theme.dragZoneHeight)
                    .frame(maxWidth: .infinity)
                    .opacity(isHovered ? 0.5 : 0)
                    .animation(Theme.hoverAnimation, value: isHovered)
                Spacer()
            }

            // Status pill top-right
            VStack {
                HStack {
                    Spacer()
                    StatusPill(state: pillState)
                }
                .padding(.trailing, 16)
                .padding(.top, 12)
                Spacer()
            }

            // Task picker overlay
            if pickerOpen {
                TaskPickerOverlay(
                    tasks: tasks,
                    selectedTask: $selectedTask,
                    isOpen: $pickerOpen
                )
                .transition(.opacity.combined(with: .offset(y: 6)))
                .zIndex(10)
            }

            // Toast (over the bar, above picker when relevant)
            if let toast = toast {
                VStack {
                    Spacer()
                    ToastView(toast: toast)
                        .padding(.bottom, Theme.barHeight + 8)
                }
                .frame(maxWidth: .infinity)
                .zIndex(20)
            }
        }
        .frame(width: Theme.windowWidth, height: Theme.windowHeight)
        .preferredColorScheme(.light)
        .onHover { hovering in isHovered = hovering }
        .contextMenu { windowContextMenu }
        .task { await loadTasks() }
        .onAppear {
            configureTimer()
            observeSleepWake()
            observeMenuBarRefresh()
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
        .onChange(of: selectedTask?.id) { _ in
            handleTaskChange()
        }
        .onChange(of: pickerOpen) { open in
            if open { isHovered = true }
        }
    }

    // MARK: - Subviews

    private var dragDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Theme.ink)
                    .frame(width: 2.5, height: 2.5)
            }
        }
    }

    private var taskRow: some View {
        Button(action: { openPicker() }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(timerManager.isRunning ? Theme.accent : Theme.muted)
                    .frame(width: Theme.statusDotSize, height: Theme.statusDotSize)

                if tasks.isEmpty && !isLoadingTasks {
                    Text("No tasks — retry")
                        .font(Theme.bodyFont)
                        .italic()
                        .foregroundColor(Theme.muted)
                } else {
                    Text(selectedTask?.name ?? "Pick a task")
                        .font(Theme.bodyFont)
                        .foregroundColor(selectedTask == nil ? Theme.muted : Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.muted)
                    .frame(width: Theme.expandIconSize, height: Theme.expandIconSize)
            }
            .frame(minHeight: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var windowContextMenu: some View {
        Button("Refresh tasks") {
            Task { await loadTasks() }
        }
        Divider()
        Button("Settings / Logout") {
            appState.logout()
        }
        Divider()
        Button("Quit ChronoTask") {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Computed

    private var pillState: PillState {
        if timerManager.isRunning { return .running }
        if tasks.isEmpty && !isLoadingTasks { return .empty }
        return .idle
    }

    // MARK: - Actions

    private func openPicker() {
        withAnimation(Theme.pickerAnimation) { pickerOpen = true }
    }

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
            let fetched = try await ClickUpAPI.shared.getTasks(teamId: team.id, userId: user.id)
            tasks = fetched.filter { Self.isEligibleForTracking($0) }
            NSLog("[MainView] loadTasks: loaded \(fetched.count) tasks, \(tasks.count) eligible")
            if tasks.isEmpty {
                loadError = fetched.isEmpty
                    ? "No tasks assigned to you"
                    : "No tasks — all are closed or TIP"
            }
        } catch let error as APIError {
            NSLog("[MainView] loadTasks API error: \(error)")
            if case .unauthorized = error {
                appState.logout()
                return
            }
            loadError = error.localizedDescription
            showToast(message: loadError ?? "Failed to load tasks", type: .error)
        } catch {
            NSLog("[MainView] loadTasks error: \(error)")
            loadError = "Failed to load tasks: \(error.localizedDescription)"
            showToast(message: loadError ?? "Failed to load tasks", type: .error)
        }
        isLoadingTasks = false
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

    // MARK: - Task eligibility

    private static let excludedStatusNames: Set<String> = ["tip", "closed", "recently closed"]

    private static func isEligibleForTracking(_ task: ClickUpTask) -> Bool {
        guard let status = task.status else { return true }
        let name = status.status.trimmingCharacters(in: .whitespaces).lowercased()
        if excludedStatusNames.contains(name) { return false }
        if status.type?.trimmingCharacters(in: .whitespaces).lowercased() == "closed" {
            return false
        }
        return true
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't intercept while picker is open — it has its own handler.
            if pickerOpen { return event }

            // Space (49) or Enter (36) toggles play/stop
            guard event.keyCode == 49 || event.keyCode == 36 else { return event }

            // Don't intercept if a text field is focused (user is typing)
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSTextView {
                return event
            }

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

    // MARK: - Menu bar refresh

    private func observeMenuBarRefresh() {
        NotificationCenter.default.addObserver(
            forName: .refreshTasksRequested,
            object: nil,
            queue: .main
        ) { _ in
            Task { await loadTasks() }
        }
    }
}

extension Notification.Name {
    static let refreshTasksRequested = Notification.Name("refreshTasksRequested")
}
