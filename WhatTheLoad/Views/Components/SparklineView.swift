import SwiftUI

struct SparklineView: View {
    let data: [Double]
    let color: Color
    var height: CGFloat = 32

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Gradient fill
                Path { path in
                    guard !data.isEmpty else { return }

                    let maxValue = data.max() ?? 100
                    let minValue = data.min() ?? 0
                    let range = max(maxValue - minValue, 1)
                    let xStep = geometry.size.width / CGFloat(max(data.count - 1, 1))

                    var points: [CGPoint] = []
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * xStep
                        let normalizedValue = (value - minValue) / range
                        let y = CGFloat(normalizedValue) * geometry.size.height
                        points.append(CGPoint(x: x, y: y))
                    }

                    if let first = points.first {
                        path.move(to: first)
                        points.dropFirst().forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: 0))
                        path.closeSubpath()
                    }
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.6), color.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    guard !data.isEmpty else { return }

                    let maxValue = data.max() ?? 100
                    let minValue = data.min() ?? 0
                    let range = max(maxValue - minValue, 1)
                    let xStep = geometry.size.width / CGFloat(max(data.count - 1, 1))

                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * xStep
                        let normalizedValue = (value - minValue) / range
                        let y = CGFloat(normalizedValue) * geometry.size.height

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 1.5)
            }
        }
        .frame(height: height)
        .background(Color.wtlCard)
        .cornerRadius(4)
    }
}
