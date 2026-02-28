import SwiftUI

enum Theme {
    // MARK: - Window
    static let windowWidth: CGFloat = 380
    static let windowHeight: CGFloat = 340

    // MARK: - Colors (Stitch design)
    static let primary = Color(hex: "0066CC")
    static let background = Color(hex: "0F1923")
    static let surface = Color(hex: "1A242F")
    static let surfaceLight = Color(hex: "1B2430")
    static let border = Color(hex: "2A3645")
    static let accent = Color(hex: "0066CC")
    static let accentLight = Color(hex: "3388DD")
    static let textPrimary = Color(hex: "F1F5F9")
    static let textSecondary = Color(hex: "94A3B8")
    static let textMuted = Color(hex: "475569")
    static let success = Color(hex: "22C55E")
    static let error = Color(hex: "EF4444")
    static let warning = Color(hex: "EAB308")

    // MARK: - ClickUp Logo Gradient
    static let clickUpFrom = Color(hex: "7B68EE")
    static let clickUpTo = Color(hex: "5C4AC7")

    // MARK: - Timer
    static let timerFont = Font.system(size: 28, weight: .bold, design: .monospaced)
    static let timerLargeFont = Font.system(size: 48, weight: .bold, design: .monospaced)
    static let timerRunningColor = Color.white
    static let timerIdleColor = Color(hex: "F1F5F9")

    // MARK: - Play/Stop Button
    static let playColor = Color(hex: "0066CC")
    static let stopColor = Color(hex: "EF4444")
    static let buttonSize: CGFloat = 48

    // MARK: - Spacing
    static let paddingSmall: CGFloat = 4
    static let paddingMedium: CGFloat = 8
    static let paddingLarge: CGFloat = 16
    static let paddingXL: CGFloat = 20
    static let cornerRadius: CGFloat = 8
    static let cornerRadiusLG: CGFloat = 12

    // MARK: - Animation
    static let defaultAnimation = Animation.easeInOut(duration: 0.2)
}
