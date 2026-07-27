import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var menuBar: MenuBarCoordinator?

    /// The test target is host-based, so this delegate runs during `xcodebuild test`.
    /// Without this guard the suite would open windows and hit the network.
    private static var isRunningUnitTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningUnitTests else { return }
        NSLog("[AppDelegate] applicationDidFinishLaunching")

        let environment = AppEnvironment()
        self.environment = environment

        let menuBar = MenuBarCoordinator(environment: environment)
        menuBar.install()
        self.menuBar = menuBar

        environment.bootstrap()

        // Escape hatch for screenshots and manual debugging: launch with
        // CHRONOTASK_SHOW_PANEL=1 and the panel opens by itself.
        let debugPanel = ProcessInfo.processInfo.environment["CHRONOTASK_SHOW_PANEL"]
        if debugPanel == "1" || debugPanel == "list" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if debugPanel == "list" {
                    menuBar.presentTaskList()
                } else {
                    menuBar.presentPanel(keepOpen: true)
                }
            }
        }

        // No window is opened at launch and the app is never activated: ChronoTask
        // now lives entirely in the menu bar until the user clicks it.
        NSLog("[AppDelegate] Menu bar installed")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
