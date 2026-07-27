import SwiftUI

/// Presentation helpers for task rows.
///
/// Rescued from `TaskPickerOverlay`, where they were private to a view that is being
/// replaced. As model extensions they survive the redesign and can be tested.
extension ClickUpTask {

    /// Leading emoji of the task name, if the name starts with one.
    var leadingEmoji: String? { Self.splitEmoji(name).emoji }

    /// Task name with any leading emoji removed.
    var strippedName: String { Self.splitEmoji(name).rest }

    /// Colour ClickUp assigns to the task's status, used for the row dot when the
    /// name carries no emoji. Falls back to muted ink when the API sends nothing.
    var statusTint: Color {
        if let hex = status?.color, !hex.isEmpty { return Color(hex: hex) }
        return Theme.inkQuaternary
    }

    /// Splits a leading emoji from the rest of the name.
    ///
    /// The `value > 0x238C` guard keeps characters that merely *can* render as emoji
    /// (digits, `#`, `*`) from being mistaken for one.
    static func splitEmoji(_ name: String) -> (emoji: String?, rest: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.unicodeScalars.first,
              first.properties.isEmojiPresentation ||
              (first.properties.isEmoji && first.value > 0x238C) else {
            return (nil, trimmed)
        }
        let emoji = String(trimmed.prefix(1))
        let rest = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        // A name that is nothing but an emoji keeps its original text, so the row
        // never renders blank.
        return (emoji, rest.isEmpty ? trimmed : rest)
    }
}
