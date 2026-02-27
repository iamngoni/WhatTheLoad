import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitors = MonitorCoordinator.shared
    private let settings = AppSettings.shared
    private let historyStore = HistoryStore.shared
    private var menuBarController: MenuBarController!
    private var alertRulesEngine: AlertRulesEngine?
    private var lowBatteryAlertTimer: Timer?
    private var lowBatteryAlertShown = false
    private var batteryAutomationTimer: Timer?
    private var batterySettingsOpenedAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitors.setPowerSaveMode(settings.powerSaveModeActive)

        // Start monitoring
        monitors.startAll()
        historyStore.start(with: monitors)

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create and start menu bar controller
        menuBarController = MenuBarController(statusItem: statusItem, monitors: monitors)
        menuBarController.startUpdating()

        startAlertRulesEngine()
        startLowBatteryAlertMonitoring()
        startBatteryAutomationMonitoring()

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: DashboardView(monitors: monitors, historyStore: historyStore)
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        alertRulesEngine?.stop()
        alertRulesEngine = nil
        lowBatteryAlertTimer?.invalidate()
        lowBatteryAlertTimer = nil
        batteryAutomationTimer?.invalidate()
        batteryAutomationTimer = nil
        historyStore.stop()
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

    private func startAlertRulesEngine() {
        let engine = AlertRulesEngine(
            monitors: monitors,
            historyStore: historyStore,
            settings: settings
        )
        engine.onAlert = { [weak self] severity, title, message in
            guard title != "Low Battery" else { return }
            self?.showBlockingAlert(severity: severity, title: title, message: message)
        }
        engine.start()
        alertRulesEngine = engine
    }

    private func startBatteryAutomationMonitoring() {
        batteryAutomationTimer?.invalidate()
        batteryAutomationTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            self?.evaluateBatteryAutomation()
        }
        evaluateBatteryAutomation()
    }

    private func checkLowBatteryAlert() {
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

    private func evaluateBatteryAutomation() {
        guard settings.batteryAutomationEnabled else {
            if settings.powerSaveModeActive {
                setPowerSaveMode(false, reason: "Low battery automation disabled.")
            }
            return
        }

        guard let metrics = monitors.battery.current else { return }
        let threshold = settings.batteryAutomationThreshold

        let shouldEnable = metrics.powerSource == .battery &&
            !metrics.isCharging &&
            metrics.chargePercent <= threshold
        let shouldDisable = metrics.isCharging ||
            metrics.powerSource != .battery ||
            metrics.chargePercent >= (threshold + 5)

        if shouldEnable && !settings.powerSaveModeActive {
            setPowerSaveMode(true, reason: String(format: "Battery reached %.0f%%.", metrics.chargePercent))
            if settings.batteryAutomationAutoOpenSettings {
                openBatterySettingsIfNeeded()
            }
        } else if shouldDisable && settings.powerSaveModeActive {
            setPowerSaveMode(false, reason: "Battery state recovered.")
        }
    }

    private func setPowerSaveMode(_ enabled: Bool, reason: String) {
        settings.powerSaveModeActive = enabled
        monitors.setPowerSaveMode(enabled)
        historyStore.recordEvent(TimelineEvent(
            severity: .info,
            category: .battery,
            title: enabled ? "Power Save Mode Enabled" : "Power Save Mode Disabled",
            message: reason
        ))
    }

    private func openBatterySettingsIfNeeded() {
        let now = Date()
        if let lastOpened = batterySettingsOpenedAt, now.timeIntervalSince(lastOpened) < 1800 {
            return
        }
        batterySettingsOpenedAt = now

        let urls = [
            "x-apple.systempreferences:com.apple.preference.battery",
            "x-apple.systempreferences:com.apple.Battery-Settings.extension"
        ]

        for rawURL in urls {
            guard let url = URL(string: rawURL) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
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

    private func showBlockingAlert(severity: TimelineSeverity, title: String, message: String) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.alertStyle = (severity == .critical) ? .critical : .warning
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "Dismiss")
            alert.runModal()
        }
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
