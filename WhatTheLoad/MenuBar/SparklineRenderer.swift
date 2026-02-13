import AppKit

class SparklineRenderer {
    static func render(data: [Double], size: NSSize, color: NSColor = .systemGreen) -> NSImage? {
        guard !data.isEmpty else { return nil }

        let image = NSImage(size: size)
        image.lockFocus()

        let context = NSGraphicsContext.current?.cgContext
        context?.clear(CGRect(origin: .zero, size: size))

        // Find min/max for scaling
        let maxValue = data.max() ?? 100
        let minValue = data.min() ?? 0
        let range = max(maxValue - minValue, 1)

        // Create path
        let path = NSBezierPath()
        let xStep = size.width / CGFloat(max(data.count - 1, 1))

        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * xStep
            let normalizedValue = (value - minValue) / range
            let y = CGFloat(normalizedValue) * size.height

            if index == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }

        // Draw gradient fill
        let gradientColors = [
            color.withAlphaComponent(0.6),
            color.withAlphaComponent(0.0)
        ]
        let gradient = NSGradient(colors: gradientColors)

        context?.saveGState()

        // Create fill path
        let fillPath = path.copy() as! NSBezierPath
        fillPath.line(to: NSPoint(x: size.width, y: 0))
        fillPath.line(to: NSPoint(x: 0, y: 0))
        fillPath.close()

        fillPath.addClip()
        gradient?.draw(from: NSPoint(x: 0, y: size.height), to: NSPoint(x: 0, y: 0), options: [])

        context?.restoreGState()

        // Draw line
        color.setStroke()
        path.lineWidth = 1.5
        path.stroke()

        image.unlockFocus()
        return image
    }

    static func colorForValue(_ value: Double) -> NSColor {
        switch value {
        case 0..<50: return .systemGreen
        case 50..<80: return .systemOrange
        default: return .systemRed
        }
    }
}
