import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: FloatingWindow?
    private var menuBar: MenuBarController?
    private let appState = AppState()
    private var cancellables = Set<AnyCancellable>()

    /// Window height per auth state — SetupView needs more room than MainView.
    private static let mainHeight:  CGFloat = Theme.windowHeight
    private static let setupHeight: CGFloat = 440

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] applicationDidFinishLaunching")

        let width = Theme.windowWidth
        let initialHeight = Self.targetHeight(for: appState.authState)

        let window = FloatingWindow(contentRect: Self.windowRect(width: width, height: initialHeight))
        let hostingView = NSHostingView(rootView: ContentRouter().environmentObject(appState))
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: initialHeight)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        let menuBar = MenuBarController()
        menuBar.install(appState: appState, window: window)
        self.menuBar = menuBar

        // Resize window whenever authState changes between main/setup.
        // Defer the resize by one run-loop tick so SwiftUI has a chance to
        // swap the view (SetupView → MainView) before NSWindow shrinks the
        // content area — otherwise NSHostingView can end up laid out against
        // a stale size and render as a blank window.
        appState.$authState
            .removeDuplicates(by: { Self.targetHeight(for: $0) == Self.targetHeight(for: $1) })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                DispatchQueue.main.async {
                    self?.resizeWindow(forAuthState: state)
                }
            }
            .store(in: &cancellables)

        NSLog("[AppDelegate] Window created size %.0fx%.0f", width, initialHeight)
    }

    private func resizeWindow(forAuthState state: AuthState) {
        guard let window = window else { return }
        let width = Theme.windowWidth
        let height = Self.targetHeight(for: state)

        // Keep the window's top edge fixed (user's visual anchor) and only resize.
        // Avoid recomputing origin from screenFrame — respects user drags.
        let currentFrame = window.frame
        let topY = currentFrame.origin.y + currentFrame.size.height
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: topY - height,
            width: width,
            height: height
        )
        window.setFrame(newFrame, display: true, animate: false)
    }

    private static func targetHeight(for state: AuthState) -> CGFloat {
        switch state {
        case .authenticated, .loading: return mainHeight
        case .needsAuth, .needsWorkspace: return setupHeight
        }
    }

    private static func windowRect(width: CGFloat, height: CGFloat) -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        return NSRect(
            x: screenFrame.maxX - width - 20,
            y: screenFrame.maxY - height - 20,
            width: width,
            height: height
        )
    }
}
