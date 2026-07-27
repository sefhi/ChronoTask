import AppKit
import SwiftUI

/// Hosts the SwiftUI tree and reports its preferred height upwards.
///
/// This replaces the two hard-coded window heights (150 for the timer, 440 for setup)
/// and the deferred double-`async` resize that worked around blank renders. The order
/// is now inverted and the old race cannot happen: SwiftUI swaps the view, measures
/// itself, and only then are we told to resize.
final class ContentSizingHostingController<Content: View>: NSViewController {

    private let hosting: NSHostingController<Content>

    /// Called whenever the SwiftUI content wants a different size.
    var onPreferredSizeChange: ((CGSize) -> Void)?

    private let cornerRadius: CGFloat
    private let material: NSVisualEffectView.Material

    init(rootView: Content,
         cornerRadius: CGFloat = Theme.radiusPanel,
         material: NSVisualEffectView.Material = .popover) {
        hosting = NSHostingController(rootView: rootView)
        // macOS 13+. Makes the controller publish an intrinsic size for its content.
        hosting.sizingOptions = [.preferredContentSize]
        self.cornerRadius = cornerRadius
        self.material = material
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    var rootView: Content {
        get { hosting.rootView }
        set { hosting.rootView = newValue }
    }

    override func loadView() {
        // The glass lives *here*, not on the window: assigning a window's
        // `contentViewController` replaces whatever `contentView` it had, which would
        // silently throw away the visual effect view and leave the panel unblurred.
        view = GlassPanelContentView(cornerRadius: cornerRadius, material: material)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// AppKit calls this on the *parent* when a child's preferred size changes.
    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        super.preferredContentSizeDidChange(for: viewController)
        guard viewController === hosting else { return }
        onPreferredSizeChange?(hosting.preferredContentSize)
    }

    /// Size SwiftUI asked for. Read from the child, since a container view controller
    /// does not publish one of its own.
    var measuredSize: CGSize { hosting.preferredContentSize }

    /// Measured height, or `nil` if SwiftUI has not produced one yet. A `ScrollView`
    /// with no explicit height reports zero, which is why the list panel sets one.
    var measuredHeight: CGFloat? {
        let height = hosting.preferredContentSize.height
        return height > 1 ? height : nil
    }

    /// Forces a layout pass — used right before showing the panel so the first frame
    /// is already at the right size.
    func layoutNow() {
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }
}
