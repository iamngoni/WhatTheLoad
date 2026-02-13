import SwiftUI

struct StatRowView: View {
    let label: String
    let value: String
    let valueColor: Color?

    init(label: String, value: String, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor ?? .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.wtlCard)
        .cornerRadius(6)
    }
}
