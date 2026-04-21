import SwiftUI

enum Theme {
    // MARK: - Window
    static let windowWidth: CGFloat = 360
    static let windowHeight: CGFloat = 150

    // MARK: - Colors (warm minimal)
    static let background = Color(hex: "FAF8F3")   // warm off-white
    static let ink        = Color(hex: "141411")   // near-black, warm
    static let muted      = Color(hex: "141411").opacity(0.5)
    static let hairline   = Color(hex: "141411").opacity(0.1)
    static let accent     = Color(hex: "C56446")   // terracotta
    static let accentHalo = Color(hex: "C56446").opacity(0.13)
    static let rowHighlight = Color(hex: "141411").opacity(0.05)

    // Semantic status (used by toast, errors)
    static let success = Color(hex: "22C55E")
    static let error   = Color(hex: "EF4444")
    static let warning = Color(hex: "EAB308")

    // Legacy aliases — kept so ToastView / existing call sites still compile
    // against the new palette without a churn pass.
    static let primary       = accent
    static let textPrimary   = ink
    static let textSecondary = muted
    static let textMuted     = muted
    static let border        = hairline
    static let surface       = background
    static let surfaceLight  = background
    static let accentLight   = accent

    // MARK: - ClickUp Logo Gradient (conservado para Setup)
    static let clickUpFrom = Color(hex: "7B68EE")
    static let clickUpTo   = Color(hex: "5C4AC7")

    // MARK: - Typography (PostScript names — IBM Plex uses truncated forms)
    static let timerFont       = Font.custom("JetBrainsMono-Medium", size: 54)
    static let bodyFont        = Font.custom("IBMPlexSans-Medm", size: 13)          // Medium
    static let labelFont       = Font.custom("IBMPlexSans-SmBld", size: 9)          // SemiBold
    static let buttonFont      = Font.custom("JetBrainsMono-SemiBold", size: 10)
    static let pickerInputFont = Font.custom("IBMPlexSans", size: 12)               // Regular
    static let pickerRowFont   = Font.custom("IBMPlexSans", size: 11.5)             // Regular
    static let setupTitleFont  = Font.custom("IBMPlexSans-SmBld", size: 18)

    // MARK: - Spacing
    static let paddingWindowH: CGFloat = 22
    static let paddingTop:     CGFloat = 18
    static let paddingBottom:  CGFloat = 16
    static let gapRows:        CGFloat = 10
    static let barHeight:      CGFloat = 28
    static let dragZoneHeight: CGFloat = 14

    // MARK: - Sizing
    static let statusDotSize:  CGFloat = 5
    static let expandIconSize: CGFloat = 12
    static let searchIconSize: CGFloat = 11

    // Legacy spacing tokens used elsewhere (e.g. Setup)
    static let paddingSmall:  CGFloat = 4
    static let paddingMedium: CGFloat = 8
    static let paddingLarge:  CGFloat = 16
    static let paddingXL:     CGFloat = 20
    static let cornerRadius:  CGFloat = 8
    static let cornerRadiusLG: CGFloat = 12

    // MARK: - Animation
    static let defaultAnimation = Animation.easeInOut(duration: 0.2)
    static let hoverAnimation   = Animation.easeOut(duration: 0.2)
    static let pickerAnimation  = Animation.easeOut(duration: 0.18)
    static let barAnimation     = Animation.linear(duration: 0.15)
}
