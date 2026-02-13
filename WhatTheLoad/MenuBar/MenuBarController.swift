import AppKit

class MenuBarController {
    private let statusItem: NSStatusItem
    private let monitors: MonitorCoordinator
    private var updateTimer: Timer?

    init(statusItem: NSStatusItem, monitors: MonitorCoordinator) {
        self.statusItem = statusItem
        self.monitors = monitors
    }

    func startUpdating() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatusItem()
        }
        updateStatusItem()
    }

    func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        // Get CPU history for sparkline
        let cpuData = monitors.cpu.history.map { $0.totalUsage }
        let currentCPU = monitors.cpu.current?.totalUsage ?? 0

        // Render sparkline
        let sparklineSize = NSSize(width: 50, height: 18)
        let color = SparklineRenderer.colorForValue(currentCPU)
        let sparklineImage = SparklineRenderer.render(data: cpuData, size: sparklineSize, color: color)

        // Get network speeds
        let upload = monitors.network.current?.uploadSpeed ?? 0
        let download = monitors.network.current?.downloadSpeed ?? 0

        let uploadMBps = upload / 1_000_000
        let downloadMBps = download / 1_000_000

        // Create attributed string with sparkline + network text
        let attributedString = NSMutableAttributedString()

        if let sparklineImage = sparklineImage {
            let attachment = NSTextAttachment()
            attachment.image = sparklineImage
            attachment.bounds = CGRect(x: 0, y: -3, width: sparklineSize.width, height: sparklineSize.height)
            attributedString.append(NSAttributedString(attachment: attachment))
            attributedString.append(NSAttributedString(string: "  "))
        }

        let networkText = String(format: "↑%.1f ↓%.1f MB/s", uploadMBps, downloadMBps)
        let networkAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        attributedString.append(NSAttributedString(string: networkText, attributes: networkAttributes))

        button.attributedTitle = attributedString
    }
}
