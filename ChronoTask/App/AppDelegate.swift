import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: FloatingWindow?
    private var menuBar: MenuBarController?
    private let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] applicationDidFinishLaunching")

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let width = Theme.windowWidth
        let height = Theme.windowHeight
        let windowRect = NSRect(
            x: screenFrame.maxX - width - 20,
            y: screenFrame.maxY - height - 20,
            width: width,
            height: height
        )

        let window = FloatingWindow(contentRect: windowRect)
        let hostingView = NSHostingView(rootView: ContentRouter().environmentObject(appState))
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = window

        let menuBar = MenuBarController()
        menuBar.install(appState: appState, window: window)
        self.menuBar = menuBar

        NSLog("[AppDelegate] Window created at (%f, %f) size %.0fx%.0f",
              windowRect.origin.x, windowRect.origin.y, width, height)
    }
}
