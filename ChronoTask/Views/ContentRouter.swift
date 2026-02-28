import SwiftUI

struct ContentRouter: View {
    @StateObject private var appState = AppState()

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
        .environmentObject(appState)
        .frame(width: Theme.windowWidth)
        .frame(minHeight: Theme.windowHeight)
    }

    private var loadingView: some View {
        ZStack {
            Theme.background
            ProgressView()
                .scaleEffect(0.8)
        }
    }
}
