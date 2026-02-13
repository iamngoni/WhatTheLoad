import SwiftUI

struct RingChartView: View {
    let percent: Double
    let color: Color
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.wtlCard, lineWidth: 6)

            // Progress ring
            Circle()
                .trim(from: 0, to: percent / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center value
            Text(String(format: "%.0f%%", percent))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .frame(width: size, height: size)
    }
}
