import SwiftUI

struct ContentRouter: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var taskStore: TaskStore
    @EnvironmentObject private var timerManager: TimerManager

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                loadingView
            case .needsAuth, .needsWorkspace:
                SetupView()
            case .authenticated:
                MainView(taskStore: taskStore, timerManager: timerManager)
            }
        }
        // Width is fixed, height follows the content so the panel can size itself.
        .frame(width: Theme.panelWidth)
        // Tint, border and top highlight. The blur and the shadow come from the
        // window; this is the other half of the glass.
        .glassSurface(radius: Theme.radiusPanel)
    }

    private var loadingView: some View {
        ProgressView()
            .scaleEffect(0.8)
            .tint(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
    }
}
