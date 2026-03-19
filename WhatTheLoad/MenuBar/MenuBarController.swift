import AppKit

class MenuBarController {
    private let statusItem: NSStatusItem
    private let monitors: MonitorCoordinator
    private let settings = AppSettings.shared
    private var updateTimer: Timer?
    private var cachedSymbols: [String: NSImage] = [:]
    private var cachedMenuBarItems: [MenuBarItem]?
    private var lastMenuBarItemsRaw: String = ""

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

        let items = resolvedMenuBarItems()
        guard !items.isEmpty else {
            button.attributedTitle = NSAttributedString(string: "WTL", attributes: baseAttributes)
            return
        }

        let attributedString = NSMutableAttributedString()

        for (index, item) in items.enumerated() {
            if index > 0 {
                attributedString.append(NSAttributedString(string: "  ", attributes: baseAttributes))
            }
            appendContent(for: item, to: attributedString)
        }

        button.attributedTitle = attributedString
    }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.white
        ]
    }

    private func appendContent(for item: MenuBarItem, to string: NSMutableAttributedString) {
        switch item {
        case .cpu:
            appendCPU(to: string)
        case .memory:
            appendMemory(to: string)
        case .network:
            appendNetwork(to: string)
        case .disk:
            appendDisk(to: string)
        case .battery:
            appendBattery(to: string)
        }
    }

    // MARK: - Item Renderers

    private func resolvedMenuBarItems() -> [MenuBarItem] {
        let raw = settings.menuBarItemsRaw
        if raw != lastMenuBarItemsRaw {
            lastMenuBarItemsRaw = raw
            cachedMenuBarItems = settings.menuBarItems
        }
        return cachedMenuBarItems ?? []
    }

    private func cachedSymbol(_ symbolName: String) -> NSImage? {
        if let cached = cachedSymbols[symbolName] { return cached }
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        image.isTemplate = true
        cachedSymbols[symbolName] = image
        return image
    }

    private func appendIcon(_ symbolName: String, to string: NSMutableAttributedString) {
        guard let image = cachedSymbol(symbolName) else { return }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -2, width: 13, height: 13)
        string.append(NSAttributedString(attachment: attachment))
        string.append(NSAttributedString(string: " ", attributes: baseAttributes))
    }

    private func appendCPU(to string: NSMutableAttributedString) {
        appendIcon(MenuBarItem.cpu.symbolName, to: string)
        let usage = monitors.cpu.current?.totalUsage ?? 0
        string.append(NSAttributedString(
            string: String(format: "%.0f%%", usage),
            attributes: baseAttributes
        ))
    }

    private func appendMemory(to string: NSMutableAttributedString) {
        appendIcon(MenuBarItem.memory.symbolName, to: string)
        guard let mem = monitors.memory.current, mem.total > 0 else {
            string.append(NSAttributedString(string: "–", attributes: baseAttributes))
            return
        }
        let usedPercent = Double(mem.used) / Double(mem.total) * 100
        string.append(NSAttributedString(
            string: String(format: "%.0f%%", usedPercent),
            attributes: baseAttributes
        ))
    }

    private func appendNetwork(to string: NSMutableAttributedString) {
        let download = monitors.network.current?.downloadSpeed ?? 0
        let upload = monitors.network.current?.uploadSpeed ?? 0

        string.append(NSAttributedString(string: "↓", attributes: baseAttributes))
        string.append(NSAttributedString(string: compactRate(download), attributes: baseAttributes))
        string.append(NSAttributedString(string: " ", attributes: baseAttributes))
        string.append(NSAttributedString(string: "↑", attributes: baseAttributes))
        string.append(NSAttributedString(string: compactRate(upload), attributes: baseAttributes))
    }

    private func appendDisk(to string: NSMutableAttributedString) {
        appendIcon(MenuBarItem.disk.symbolName, to: string)
        guard let volume = monitors.disk.current?.volumes.first, volume.total > 0 else {
            string.append(NSAttributedString(string: "–", attributes: baseAttributes))
            return
        }
        let usedPercent = Double(volume.used) / Double(volume.total) * 100
        string.append(NSAttributedString(
            string: String(format: "%.0f%%", usedPercent),
            attributes: baseAttributes
        ))
    }

    private func appendBattery(to string: NSMutableAttributedString) {
        guard let battery = monitors.battery.current else { return }

        if let batteryIcon = batteryImage(for: battery) {
            let attachment = NSTextAttachment()
            attachment.image = batteryIcon
            attachment.bounds = CGRect(x: 0, y: -2, width: 13, height: 13)
            string.append(NSAttributedString(attachment: attachment))
            string.append(NSAttributedString(string: " ", attributes: baseAttributes))
        }

        if let timeText = batteryTimeText(for: battery) {
            string.append(NSAttributedString(string: timeText, attributes: baseAttributes))
        } else {
            string.append(NSAttributedString(
                string: String(format: "%.0f%%", battery.chargePercent),
                attributes: baseAttributes
            ))
        }
    }

    // MARK: - Helpers

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

        return cachedSymbol(symbolName)
    }
}
