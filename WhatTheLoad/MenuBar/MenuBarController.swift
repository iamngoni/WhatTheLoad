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

        // Get network speeds
        let upload = monitors.network.current?.uploadSpeed ?? 0
        let download = monitors.network.current?.downloadSpeed ?? 0

        // Create attributed string with network + battery text
        let attributedString = NSMutableAttributedString()
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.white
        ]

        attributedString.append(NSAttributedString(string: "↓", attributes: baseAttributes))
        attributedString.append(NSAttributedString(string: compactRate(download), attributes: baseAttributes))
        attributedString.append(NSAttributedString(string: " ", attributes: baseAttributes))
        attributedString.append(NSAttributedString(string: "↑", attributes: baseAttributes))
        attributedString.append(NSAttributedString(string: compactRate(upload), attributes: baseAttributes))

        if let battery = monitors.battery.current, let batteryTimeText = batteryTimeText(for: battery) {
            attributedString.append(NSAttributedString(string: "  ", attributes: baseAttributes))

            if let batteryIcon = batteryImage(for: battery) {
                let attachment = NSTextAttachment()
                attachment.image = batteryIcon
                attachment.bounds = CGRect(x: 0, y: -2, width: 13, height: 13)
                attributedString.append(NSAttributedString(attachment: attachment))
                attributedString.append(NSAttributedString(string: " ", attributes: baseAttributes))
            }

            attributedString.append(NSAttributedString(string: batteryTimeText, attributes: baseAttributes))
        }

        button.attributedTitle = attributedString
    }

    private func compactRate(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "K/s", "M/s", "G/s"]
        var value = max(bytesPerSecond, 0)
        var unitIndex = 0

        while value >= 1000, unitIndex < units.count - 1 {
            value /= 1000
            unitIndex += 1
        }

        let decimals: Int
        switch value {
        case 0..<10: decimals = 1
        case 10..<100: decimals = 1
        default: decimals = 0
        }

        return String(format: "%.\(decimals)f%@", value, units[unitIndex])
    }

    private func batteryTimeText(for battery: BatteryMetrics) -> String? {
        if let timeRemaining = battery.timeRemaining {
            return formatShortTime(timeRemaining)
        }

        if battery.powerSource == .ac {
            return battery.chargePercent >= 99 ? "Full" : "AC"
        }

        return nil
    }

    private func formatShortTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }

    private func batteryImage(for battery: BatteryMetrics) -> NSImage? {
        let symbolName: String

        if battery.isCharging {
            symbolName = "battery.100.bolt"
        } else {
            switch battery.chargePercent {
            case 75...: symbolName = "battery.100"
            case 50..<75: symbolName = "battery.75"
            case 25..<50: symbolName = "battery.50"
            default: symbolName = "battery.25"
            }
        }

        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }
}
