import Foundation

extension Notification.Name {
    /// Posted by the menu bar's "Refresh tasks" item (⌘R).
    static let refreshTasksRequested = Notification.Name("refreshTasksRequested")

    /// Posted by the AppKit layer each time the panel becomes visible.
    ///
    /// `onAppear` cannot stand in for this: the SwiftUI view now outlives individual
    /// presentations of the panel, so it only fires once.
    static let panelDidPresent = Notification.Name("panelDidPresent")

    /// Posted by the SwiftUI layer to ask the AppKit layer to close the panel,
    /// e.g. when ESC is pressed with no list open.
    static let panelDismissRequested = Notification.Name("panelDismissRequested")

    /// Debug/screenshot aid: asks the panel to expand its task list.
    static let openTaskListRequested = Notification.Name("openTaskListRequested")
}
