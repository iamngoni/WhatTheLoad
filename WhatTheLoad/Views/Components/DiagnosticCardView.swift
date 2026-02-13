import SwiftUI

struct DiagnosticCardView: View {
    let icon: String
    let message: String
    let type: DiagnosticType

    enum DiagnosticType {
        case success, warning, error

        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }

        var iconName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .foregroundColor(type.color)
                .font(.system(size: 16))

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(12)
        .background(type.color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
    }
}
