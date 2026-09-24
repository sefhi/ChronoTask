import SwiftUI

/// Hover over a whole region, the buttons inside it included.
///
/// SwiftUI's `onHover` on a container stops reporting once the pointer is over a
/// `Button` inside it. On the parallel rows that left the stop button — revealed
/// only on hover — out of reach: it never appeared, and at opacity 0 it cannot be
/// clicked either. A tracking area sits outside hit testing, so it sees the pointer
/// wherever it is. Same mechanism as the peek's `PeekHoverView`, which it reuses.
struct HoverTracker: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> PeekHoverView {
        let view = PeekHoverView()
        update(view)
        return view
    }

    func updateNSView(_ view: PeekHoverView, context: Context) {
        update(view)
    }

    private func update(_ view: PeekHoverView) {
        view.onEnter = { onChange(true) }
        view.onExit = { onChange(false) }
    }
}
