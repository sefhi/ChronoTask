import AppKit
import SwiftUI

enum ChronoKey: Equatable {
    case escape, up, down, enter, space
    /// `/` and `⌘K` / `⌘F` — the three habits people already have for "search here".
    case slash, findShortcut
    /// `⌘Q`. An agent app has no main menu, so nothing handles this for us.
    case quit
    /// `⌘1`…`⌘9`: jump straight to one of the first tasks.
    case quickPick(Int)

    init?(event: NSEvent) {
        let command = event.modifierFlags.contains(.command)

        switch event.keyCode {
        case 53:  self = .escape; return
        case 126: self = .up; return
        case 125: self = .down; return
        case 36, 76: self = .enter; return   // Return and the numeric Enter
        case 49:  self = .space; return
        default: break
        }

        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              let first = characters.first else { return nil }

        if command, first == "q" {
            self = .quit
            return
        }
        if command, first == "k" || first == "f" {
            self = .findShortcut
            return
        }
        if !command, first == "/" {
            self = .slash
            return
        }
        if command, let digit = first.wholeNumberValue, (1...9).contains(digit) {
            self = .quickPick(digit - 1)
            return
        }
        return nil
    }
}

enum ArrowDirection {
    case up, down
}

/// Single keyboard entry point for the panel.
///
/// Replaces the three independent `keyDown` monitors the app used to install (main
/// view, task picker, and now the panel), whose relative invocation order is
/// undocumented and was effectively a race for the ESC key.
///
/// The handler returns `true` to swallow the event.
struct KeyCatcher: NSViewRepresentable {
    let handler: (ChronoKey) -> Bool

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.handler = handler
    }

    static func dismantleNSView(_ nsView: KeyCatcherView, coordinator: ()) {
        nsView.teardown()
    }
}

final class KeyCatcherView: NSView {
    var handler: ((ChronoKey) -> Bool)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        teardown()
        guard window != nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let host = self.window else { return event }
            // `host.isKeyWindow`, not `NSApp.keyWindow === host`: this app is an
            // agent, so `NSApp.keyWindow` is nil whenever it is not the active app —
            // which would disable every shortcut.
            guard host.isKeyWindow else { return event }
            guard let key = ChronoKey(event: event) else { return event }

            // SPACE must reach the search field while the user is typing. The first
            // responder is the authority here — it describes where the key is
            // actually going, which `@FocusState` only approximates.
            //
            // `isEditing` also demands that the field editor is actually accepting
            // input: an empty, hidden field editor can linger as first responder after
            // the list collapses, and that would silently disable the shortcut.
            if key == .space, self.isEditing(in: host) { return event }

            return (self.handler?(key) ?? false) ? nil : event
        }
    }

    /// True only when a text field is genuinely editable and on screen.
    private func isEditing(in window: NSWindow) -> Bool {
        guard let text = window.firstResponder as? NSTextView else { return false }
        guard text.isEditable else { return false }
        // A collapsed list is clipped to zero height; its field editor is not really
        // available to type into.
        let visible = text.window != nil && !text.isHiddenOrHasHiddenAncestor
            && text.visibleRect.height > 1
        return visible
    }

    func teardown() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        // `deinit` can run off the main thread; the monitor token is safe to remove
        // from anywhere, and capturing it locally avoids touching `self` further.
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
