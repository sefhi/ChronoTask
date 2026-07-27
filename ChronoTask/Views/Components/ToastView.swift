import SwiftUI

enum ToastType {
    case success
    case error

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return Theme.success
        case .error: return Theme.error
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 12))
                .foregroundColor(toast.type.color)
            Text(toast.message)
                .font(Theme.emptyFont)
                .foregroundColor(Theme.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        // The one place a SwiftUI material earns its keep: the toast floats over the
        // panel's own content, so it needs to separate itself from what is behind it.
        .background(.regularMaterial,
                    in: RoundedRectangle(cornerRadius: Theme.radiusToast, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusToast, style: .continuous)
                .strokeBorder(Theme.glassStroke, lineWidth: Theme.strokeHairline)
        }
        .shadow(color: Theme.shadowToast, radius: Theme.shadowToastRadius, y: Theme.shadowToastY)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
