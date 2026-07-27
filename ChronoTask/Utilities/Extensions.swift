import AppKit
import SwiftUI

extension NSColor {
    /// Mirrors `Color(hex:)` for the AppKit side of the app (window chrome, status item).
    ///
    /// Uses `srgbRed:` rather than `red:` on purpose: the latter builds a `deviceRGB`
    /// colour, which is not colorimetrically identical to SwiftUI's `.sRGB` and shows
    /// up as a hue shift between AppKit-drawn and SwiftUI-drawn surfaces.
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        let digits = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: digits).scanHexInt64(&value)
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension TimeInterval {
    /// Formats seconds into "HH:MM:SS"
    var timerFormatted: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Formats seconds into compact "Xh Xm" format
    var todayFormatted: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Converts seconds to milliseconds
    var milliseconds: Int {
        Int(self * 1000)
    }
}

extension Date {
    /// Unix timestamp in milliseconds
    var millisecondsSince1970: Int {
        Int(timeIntervalSince1970 * 1000)
    }
}
