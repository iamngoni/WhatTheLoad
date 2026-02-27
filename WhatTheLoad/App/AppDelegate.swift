import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitors = MonitorCoordinator()
    private var menuBarController: MenuBarController!
    private var lowBatteryAlertTimer: Timer?
    private var lowBatteryAlertShown = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start monitoring
        monitors.startAll()

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create and start menu bar controller
        menuBarController = MenuBarController(statusItem: statusItem, monitors: monitors)
        menuBarController.startUpdating()

        startLowBatteryAlertMonitoring()

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: DashboardView(monitors: monitors))
    }

    func applicationWillTerminate(_ notification: Notification) {
        lowBatteryAlertTimer?.invalidate()
        lowBatteryAlertTimer = nil
        menuBarController.stopUpdating()
        monitors.stopAll()
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func startLowBatteryAlertMonitoring() {
        lowBatteryAlertTimer?.invalidate()
        lowBatteryAlertTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.checkLowBatteryAlert()
        }
        checkLowBatteryAlert()
    }

    private func checkLowBatteryAlert() {
        let settings = AppSettings.shared
        guard settings.lowBatteryAlertsEnabled else {
            lowBatteryAlertShown = false
            return
        }

        guard let metrics = monitors.battery.current else { return }

        let threshold = settings.lowBatteryAlertThreshold
        let isDischargingOnBattery = metrics.powerSource == .battery && !metrics.isCharging

        if isDischargingOnBattery && metrics.chargePercent <= threshold {
            guard !lowBatteryAlertShown else { return }
            lowBatteryAlertShown = true
            showLowBatteryAlert(metrics: metrics, threshold: threshold)
            return
        }

        let hasRecovered = metrics.isCharging || metrics.powerSource != .battery || metrics.chargePercent >= (threshold + 5)
        if hasRecovered {
            lowBatteryAlertShown = false
        }
    }

    private func showLowBatteryAlert(metrics: BatteryMetrics, threshold: Double) {
        let levelText = String(format: "%.0f", metrics.chargePercent)
        let thresholdText = String(format: "%.0f", threshold)

        var details = "Battery level is \(levelText)% (threshold \(thresholdText)%)."
        if let remaining = metrics.timeRemaining {
            details += "\nEstimated time remaining: \(formatRemainingTime(remaining))."
        }
        details += "\nPlug in your charger soon."

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Low Battery"
        alert.informativeText = details
        alert.addButton(withTitle: "Dismiss")
        alert.runModal()
    }

    private func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
