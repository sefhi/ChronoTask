import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: FloatingWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] applicationDidFinishLaunching")

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let windowRect = NSRect(
            x: screenFrame.maxX - Theme.windowWidth - 20,
            y: screenFrame.maxY - Theme.windowHeight - 20,
            width: Theme.windowWidth,
            height: Theme.windowHeight
        )

        let window = FloatingWindow(contentRect: windowRect)
        let hostingView = NSHostingView(rootView: ContentRouter())
        hostingView.frame = NSRect(x: 0, y: 0, width: Theme.windowWidth, height: Theme.windowHeight)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        NSLog("[AppDelegate] Window created at (%f, %f)", windowRect.origin.x, windowRect.origin.y)
    }
}
