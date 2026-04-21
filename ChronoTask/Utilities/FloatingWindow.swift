import AppKit

final class FloatingWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = NSColor(red: 0.980, green: 0.972, blue: 0.952, alpha: 1.0) // FAF8F3
        isOpaque = false
        hasShadow = true

        // Keep on top across spaces
        collectionBehavior = [.canJoinAllSpaces, .stationary]
    }

    // Allow the window to become key for text input
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
