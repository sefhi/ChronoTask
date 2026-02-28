import AppKit

final class FloatingWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        backgroundColor = NSColor(red: 0.059, green: 0.098, blue: 0.137, alpha: 1.0) // 0F1923
        isOpaque = false
        hasShadow = true

        // Hide traffic light buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // Keep on top
        collectionBehavior = [.canJoinAllSpaces, .stationary]
    }

    // Allow the window to become key for text input
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
