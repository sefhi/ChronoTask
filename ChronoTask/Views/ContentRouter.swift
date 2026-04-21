import SwiftUI

struct ContentRouter: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                loadingView
            case .needsAuth, .needsWorkspace:
                SetupView()
            case .authenticated:
                MainView()
            }
        }
        .frame(width: Theme.windowWidth)
        .frame(minHeight: Theme.windowHeight)
        .preferredColorScheme(.light)
    }

    private var loadingView: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ProgressView()
                .scaleEffect(0.8)
                .tint(Theme.ink)
        }
    }
}
