import AppKit
import SwiftUI

/// Design tokens for the glass redesign.
///
/// Colours are backed by `NSColor(name:dynamicProvider:)` so a single definition
/// serves both worlds: SwiftUI reads `Theme.accent`, AppKit (window chrome, status
/// item, peek) reads `Theme.NS.accent`. They resolve against the *system* appearance,
/// so nothing may pin `window.appearance` — doing so freezes every token.
enum Theme {

    // MARK: - Dynamic colour plumbing

    private static func dynamic(_ name: String, light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: NSColor.Name("chrono.\(name)")) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    /// AppKit-facing tokens. Same source of truth as the SwiftUI ones below.
    enum NS {
        static let ink            = Theme.dynamic("ink", light: NSColor(hex: "141411"), dark: NSColor(hex: "FAF8F3"))
        static let accent         = Theme.dynamic("accent", light: NSColor(hex: "C56446"), dark: NSColor(hex: "E08A66"))
        static let accentFill     = Theme.dynamic("accentFill", light: NSColor(hex: "C56446", alpha: 0.92), dark: NSColor(hex: "C56446", alpha: 0.95))
        static let glassStroke    = Theme.dynamic("glassStroke", light: NSColor(white: 1, alpha: 0.55), dark: NSColor(white: 1, alpha: 0.16))
        /// Border drawn on the panel's backing layer. Softer than the SwiftUI stroke
        /// because it sits outside the tint rather than on top of it.
        static let panelBorder    = Theme.dynamic("panelBorder", light: NSColor(white: 0, alpha: 0.08), dark: NSColor(white: 1, alpha: 0.12))
    }

    // MARK: - Ink

    /// Primary text.
    static let ink = Color(nsColor: NS.ink)

    /// Secondary text — the "Hoy · …" line, inactive pill labels.
    static let inkSecondary = Color(nsColor: dynamic("inkSecondary",
        light: NSColor(hex: "141411", alpha: 0.55), dark: NSColor(hex: "FAF8F3", alpha: 0.55)))

    /// Placeholders — "Elige una tarea", "Buscar tareas…".
    static let inkTertiary = Color(nsColor: dynamic("inkTertiary",
        light: NSColor(hex: "141411", alpha: 0.45), dark: NSColor(hex: "FAF8F3", alpha: 0.45)))

    /// Inactive iconography — magnifier, chevron, idle status dot.
    static let inkQuaternary = Color(nsColor: dynamic("inkQuaternary",
        light: NSColor(hex: "141411", alpha: 0.40), dark: NSColor(hex: "FAF8F3", alpha: 0.40)))

    /// The stopwatch mark in the panel header and the peek, while stopped. Darker
    /// than the surrounding iconography: it is the app's mark, not a control.
    static let markHeader = Color(nsColor: dynamic("markHeader",
        light: NSColor(hex: "141411", alpha: 0.75), dark: NSColor(hex: "FAF8F3", alpha: 0.80)))

    /// Text and glyphs on top of an accent fill. Never inverts.
    static let onAccent = Color(nsColor: NSColor(hex: "FAF8F3"))

    // MARK: - Accent

    /// Terracotta. Lightened in dark mode — `#C56446` on dark glass sits at ~2.7:1,
    /// which is not enough for the 9pt `REC` label.
    static let accent = Color(nsColor: NS.accent)

    /// Fill for the primary button (`rgba(197,100,70,.92)` in the prototype).
    static let accentFill = Color(nsColor: NS.accentFill)

    /// Ring around the recording dot — `0 0 0 3px rgba(197,100,70,.14)`.
    static let accentHalo = Color(nsColor: dynamic("accentHalo",
        light: NSColor(hex: "C56446", alpha: 0.14), dark: NSColor(hex: "E08A66", alpha: 0.22)))

    // MARK: - Stop treatment

    /// "Detener" is tinted and outlined rather than filled. It stays unmistakably
    /// actionable without carrying the weight of the primary action: starting is the
    /// decision, stopping merely ends what is already running.
    ///
    /// These stay on the base `#C56446` in both appearances rather than following
    /// `accent`, which lightens in the dark. As a *fill* the darker terracotta is what
    /// keeps the pale label above it readable.
    static let stopFill = Color(nsColor: dynamic("stopFill",
        light: NSColor(hex: "C56446", alpha: 0.14), dark: NSColor(hex: "C56446", alpha: 0.24)))

    static let stopStroke = Color(nsColor: dynamic("stopStroke",
        light: NSColor(hex: "C56446", alpha: 0.55), dark: NSColor(hex: "D67C5F", alpha: 0.62)))

    /// Deep terracotta, not the accent itself: the label sits on a pale wash of that
    /// very accent, so `#C56446` on `#C56446 @14%` would barely separate.
    static let stopLabel = Color(nsColor: dynamic("stopLabel",
        light: NSColor(hex: "9C4A31"), dark: NSColor(hex: "F0C3B2")))

    /// `inset 0 1px 0` along the top edge, as on the glass surfaces.
    static let stopHighlight = Color(nsColor: dynamic("stopHighlight",
        light: NSColor(white: 1.0, alpha: 0.40), dark: NSColor(white: 1.0, alpha: 0.12)))

    // MARK: - Glass surface (panel + peek)

    /// Tint laid over the window's blur. Carries no blur of its own.
    static let glassTint = Color(nsColor: dynamic("glassTint",
        light: NSColor(white: 1.0, alpha: 0.34), dark: NSColor(hex: "181816", alpha: 0.50)))

    /// Opaque stand-in used when "Reduce transparency" is on.
    static let glassTintOpaque = Color(nsColor: dynamic("glassTintOpaque",
        light: NSColor(hex: "F4F1EA"), dark: NSColor(hex: "1B1B19")))

    static let glassStroke = Color(nsColor: NS.glassStroke)

    /// `inset 0 1px 0` — light catching the top edge.
    static let glassHighlight = Color(nsColor: dynamic("glassHighlight",
        light: NSColor(white: 1.0, alpha: 0.60), dark: NSColor(white: 1.0, alpha: 0.14)))

    /// `0 18px 40px`. Only used where the window does not cast its own shadow.
    static let glassShadow = Color(nsColor: dynamic("glassShadow",
        light: NSColor(srgbRed: 30 / 255, green: 35 / 255, blue: 45 / 255, alpha: 0.28),
        dark: NSColor(white: 0, alpha: 0.45)))

    // MARK: - Inset surface (task caption, search field, daily chip)

    static let insetFill = Color(nsColor: dynamic("insetFill",
        light: NSColor(white: 1.0, alpha: 0.40), dark: NSColor(white: 1.0, alpha: 0.10)))

    static let insetFillHover = Color(nsColor: dynamic("insetFillHover",
        light: NSColor(white: 1.0, alpha: 0.52), dark: NSColor(white: 1.0, alpha: 0.15)))

    static let insetStroke = Color(nsColor: dynamic("insetStroke",
        light: NSColor(white: 1.0, alpha: 0.50), dark: NSColor(white: 1.0, alpha: 0.14)))

    // MARK: - Panel menu (the "…" popover in the header)

    /// Near-opaque on purpose, unlike the panel it sits on. A translucent menu over
    /// translucent glass would stack two washes of desktop and stop being readable —
    /// which is also how AppKit's own menus behave.
    static let menuFill = Color(nsColor: dynamic("menuFill",
        light: NSColor(hex: "F7F4F0", alpha: 0.97), dark: NSColor(hex: "262623", alpha: 0.97)))

    static let menuStroke = Color(nsColor: dynamic("menuStroke",
        light: NSColor(hex: "141411", alpha: 0.10), dark: NSColor(white: 1.0, alpha: 0.12)))

    static let menuRowHover = Color(nsColor: dynamic("menuRowHover",
        light: NSColor(hex: "141411", alpha: 0.07), dark: NSColor(white: 1.0, alpha: 0.10)))

    /// Quit gets the accent on hover — enough to mark it apart from the two harmless
    /// items above without dressing it up as a destructive red it is not.
    static let menuRowDangerHover = Color(nsColor: dynamic("menuRowDangerHover",
        light: NSColor(hex: "C56446", alpha: 0.16), dark: NSColor(hex: "C56446", alpha: 0.26)))

    static let menuSeparator = Color(nsColor: dynamic("menuSeparator",
        light: NSColor(hex: "141411", alpha: 0.12), dark: NSColor(white: 1.0, alpha: 0.14)))

    static let menuShadow = Color(nsColor: dynamic("menuShadow",
        light: NSColor(srgbRed: 30 / 255, green: 35 / 255, blue: 45 / 255, alpha: 0.26),
        dark: NSColor(white: 0, alpha: 0.50)))

    // MARK: - List rows

    /// Row holding keyboard focus.
    static let rowFocused = Color(nsColor: dynamic("rowFocused",
        light: NSColor(white: 1.0, alpha: 0.55), dark: NSColor(white: 1.0, alpha: 0.14)))

    /// Row under the pointer — softer than focus so the two read apart.
    static let rowHover = Color(nsColor: dynamic("rowHover",
        light: NSColor(white: 1.0, alpha: 0.32), dark: NSColor(white: 1.0, alpha: 0.08)))

    /// A task in the "en paralelo" list under the pointer (`.sat:hover`).
    static let parallelRowHover = Color(nsColor: dynamic("parallelRowHover",
        light: NSColor(white: 1.0, alpha: 0.45), dark: NSColor(white: 1.0, alpha: 0.10)))

    /// Separators over glass are made of *light*, never ink: ink at 10% simply
    /// vanishes against a translucent backdrop.
    static let separator = Color(nsColor: dynamic("separator",
        light: NSColor(white: 1.0, alpha: 0.45), dark: NSColor(white: 1.0, alpha: 0.10)))

    // MARK: - Semantic

    static let success = Color(nsColor: dynamic("success",
        light: NSColor(hex: "22C55E"), dark: NSColor(hex: "4ADE80")))

    static let error = Color(nsColor: dynamic("error",
        light: NSColor(hex: "EF4444"), dark: NSColor(hex: "F87171")))

    // MARK: - Brand (Setup only)

    static let clickUpFrom = Color(hex: "7B68EE")
    static let clickUpTo   = Color(hex: "5C4AC7")

    // MARK: - Radii

    static let radiusPanel:   CGFloat = 22
    static let radiusPeek:    CGFloat = 20
    static let radiusSurface: CGFloat = 12   // inset surfaces + large buttons
    static let radiusControl: CGFloat = 12
    static let radiusField:   CGFloat = 11   // search field
    static let radiusRow:     CGFloat = 10
    static let radiusToast:   CGFloat = 10

    // MARK: - Strokes

    static let strokeHairline:  CGFloat = 0.5   // one physical pixel on Retina
    static let strokeHighlight: CGFloat = 1
    /// The stop button's outline. Heavier than the hairline on purpose: with only a
    /// 14% wash behind it, the edge is what makes the shape read as a control.
    static let strokeStop:      CGFloat = 1

    // MARK: - Shadows

    static let shadowGlassRadius: CGFloat = 20  // CSS blur 40 ÷ 2
    static let shadowGlassY:      CGFloat = 14
    static let shadowToast              = Color.black.opacity(0.18)
    static let shadowToastRadius: CGFloat = 8
    static let shadowToastY:      CGFloat = 3

    // MARK: - Typography (PostScript names — IBM Plex uses truncated forms)

    static let timerFont    = Font.custom("JetBrainsMono-Medium", size: 40)
    static let subtitleFont = Font.custom("IBMPlexSans", size: 11)
    static let captionFont  = Font.custom("IBMPlexSans-Medm", size: 12.5)
    static let labelFont    = Font.custom("IBMPlexSans-SmBld", size: 9)
    static let searchFont   = Font.custom("IBMPlexSans", size: 12)
    static let rowFont      = Font.custom("IBMPlexSans", size: 12)
    static let emptyFont    = Font.custom("IBMPlexSans", size: 11.5)
    static let ctaFont      = Font.custom("IBMPlexSans-SmBld", size: 12)
    static let hintFont     = Font.custom("JetBrainsMono-Medium", size: 9)
    static let syncedFont   = Font.custom("IBMPlexSans", size: 10)
    static let menuRowFont  = Font.custom("IBMPlexSans-Medm", size: 12)
    static let menuKeyFont  = Font.custom("JetBrainsMono-Medium", size: 10)
    static let chipFont     = Font.custom("JetBrainsMono-Medium", size: 12)
    static let peekTimeFont = Font.custom("JetBrainsMono-Medium", size: 15)

    // Multitasking
    /// The focused task's clock, a step down from `timerFont` to make room for the
    /// task name above it and the parallel list below.
    static let timerFontCompact = Font.custom("JetBrainsMono-Medium", size: 34)
    static let focusNameFont    = Font.custom("IBMPlexSans-SmBld", size: 13)
    static let subtitleFigure   = Font.custom("JetBrainsMono-SemiBold", size: 11)
    static let captionHintFont  = Font.custom("IBMPlexSans-Medm", size: 9)
    static let parallelRowFont  = Font.custom("IBMPlexSans", size: 11.5)
    static let parallelTimeFont = Font.custom("JetBrainsMono-Medium", size: 11.5)
    static let goFont           = Font.custom("IBMPlexSans-SmBld", size: 10)
    static let peekRowFont      = Font.custom("IBMPlexSans", size: 11.5)
    static let peekRowTimeFont  = Font.custom("JetBrainsMono-Medium", size: 11.5)
    static let peekTotalFont    = Font.custom("JetBrainsMono-Medium", size: 13)

    // Setup
    static let setupTitleFont = Font.custom("IBMPlexSans-SmBld", size: 18)
    static let bodyFont       = Font.custom("IBMPlexSans-Medm", size: 13)
    static let monoLabelFont  = Font.custom("JetBrainsMono-SemiBold", size: 10)
    static let tokenFieldFont = Font.custom("JetBrainsMono-Medium", size: 13)
    static let errorFont      = Font.custom("IBMPlexSans", size: 11)

    // MARK: - Tracking

    static let trackingLabel: CGFloat = 1.8
    static let trackingHint:  CGFloat = 1.5
    static let trackingEsc:   CGFloat = 0.8
    static let trackingCta:   CGFloat = 2.5
    static let trackingTimer: CGFloat = -0.5
    static let trackingCaption: CGFloat = 1.6

    // MARK: - Layout

    static let panelWidth:     CGFloat = 300
    static let panelPadH:      CGFloat = 18
    static let panelPadTop:    CGFloat = 18
    static let panelPadBottom: CGFloat = 16
    /// 260 rather than 230 since the list gained its "Actualizado hace…" footer,
    /// matching the prototype's `#listwrap.open{max-height:260px}`.
    static let listMaxHeight:  CGFloat = 260
    static let listScrollMax:  CGFloat = 150
    static let controlHeight:  CGFloat = 36
    static let chipWidth:      CGFloat = 92
    static let controlGap:     CGFloat = 10
    static let peekWidth:      CGFloat = 250

    /// Gap between the status item and the panel/peek below it.
    static let anchorGap:        CGFloat = 6
    static let screenEdgeMargin: CGFloat = 8
    static let minPanelHeight:   CGFloat = 120

    // MARK: - Sizing

    static let dotSize:        CGFloat = 5
    static let haloRing:       CGFloat = 3   // halo diameter = dotSize + haloRing * 2
    static let rowIconWidth:   CGFloat = 14
    static let searchIconSize:  CGFloat = 11
    static let refreshIconSize: CGFloat = 12
    static let chevronSize:    CGFloat = 10
    static let menuWidth:      CGFloat = 196
    static let menuIconSize:   CGFloat = 12
    static let radiusMenu:     CGFloat = 12
    static let radiusMenuRow:  CGFloat = 8
    static let glyphSize:      CGFloat = 7   // play triangle / stop square
    /// Task dots in lists — a touch larger than the status dots, as in `.ico i`.
    static let taskDotSize:    CGFloat = 6
    /// Round stop buttons: inside a parallel row, and beside the focused task.
    static let rowStopSize:    CGFloat = 18
    static let focusStopSize:  CGFloat = 22

    // MARK: - Animation

    static let listAnimation   = Animation.easeOut(duration: 0.22)
    static let panelAnimation  = Animation.easeOut(duration: 0.18)
    static let hoverAnimation  = Animation.easeOut(duration: 0.12)
    static let pressAnimation  = Animation.easeOut(duration: 0.08)
    static let toastAnimation  = Animation.easeInOut(duration: 0.20)
    static let menuAnimation   = Animation.easeOut(duration: 0.14)
    static let scrollAnimation = Animation.easeInOut(duration: 0.10)
    /// Half of the prototype's 1.8s `pl` cycle, auto-reversed.
    static let livePulseAnimation = Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true)
    static let panelOffset:    CGFloat = 8

    /// One turn of the refresh glyph while a load is in flight (`sp .7s linear`).
    static let spinAnimation = Animation.linear(duration: 0.7).repeatForever(autoreverses: false)

    /// How often the "Actualizado hace…" line re-reads the clock. The prototype uses
    /// 20s: often enough that the minute count is never visibly wrong, rare enough to
    /// cost nothing.
    static let syncedLabelRefresh: TimeInterval = 20

}
