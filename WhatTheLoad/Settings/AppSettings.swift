import Foundation
import SwiftUI
import Combine

enum MenuBarItem: String, CaseIterable, Identifiable {
    case cpu
    case memory
    case network
    case disk
    case battery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .network: return "Network"
        case .disk: return "Disk"
        case .battery: return "Battery"
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("cpuPollInterval") var cpuPollInterval: Double = 1.0
    @AppStorage("memoryPollInterval") var memoryPollInterval: Double = 2.0
    @AppStorage("networkPollInterval") var networkPollInterval: Double = 1.0
    @AppStorage("wifiPollInterval") var wifiPollInterval: Double = 1.0
    @AppStorage("diskPollInterval") var diskPollInterval: Double = 5.0
    @AppStorage("processesPollInterval") var processesPollInterval: Double = 3.0
    @AppStorage("batteryPollInterval") var batteryPollInterval: Double = 10.0

    @AppStorage("menuBarItems") var menuBarItemsRaw: String = "network,battery"

    var menuBarItems: [MenuBarItem] {
        get {
            menuBarItemsRaw.split(separator: ",").compactMap { MenuBarItem(rawValue: String($0)) }
        }
        set {
            menuBarItemsRaw = newValue.prefix(3).map(\.rawValue).joined(separator: ",")
        }
    }

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    @AppStorage("alertsEnabled") var alertsEnabled: Bool = true
    @AppStorage("alertPopupsEnabled") var alertPopupsEnabled: Bool = false
    @AppStorage("alertsCooldownMinutes") var alertsCooldownMinutes: Double = 10.0
    @AppStorage("alertsQuietHoursEnabled") var alertsQuietHoursEnabled: Bool = false
    @AppStorage("alertsQuietHoursStartHour") var alertsQuietHoursStartHour: Double = 22.0
    @AppStorage("alertsQuietHoursEndHour") var alertsQuietHoursEndHour: Double = 7.0
    @AppStorage("cpuUsageAlertThreshold") var cpuUsageAlertThreshold: Double = 90.0
    @AppStorage("cpuTempAlertThreshold") var cpuTempAlertThreshold: Double = 90.0
    @AppStorage("packetLossAlertThreshold") var packetLossAlertThreshold: Double = 3.0
    @AppStorage("jitterAlertThreshold") var jitterAlertThreshold: Double = 30.0
    @AppStorage("lowDiskFreePercentThreshold") var lowDiskFreePercentThreshold: Double = 10.0

    @AppStorage("lowBatteryAlertsEnabled") var lowBatteryAlertsEnabled: Bool = true
    @AppStorage("lowBatteryAlertThreshold") var lowBatteryAlertThreshold: Double = 20.0
    @AppStorage("batteryAutomationEnabled") var batteryAutomationEnabled: Bool = true
    @AppStorage("batteryAutomationThreshold") var batteryAutomationThreshold: Double = 20.0
    @AppStorage("batteryAutomationAutoOpenSettings") var batteryAutomationAutoOpenSettings: Bool = false
    @AppStorage("powerSaveModeActive") var powerSaveModeActive: Bool = false
    @AppStorage("lastDiagnosticsExportStatus") var lastDiagnosticsExportStatus: String = ""

    func resetToDefaults() {
        cpuPollInterval = 1.0
        memoryPollInterval = 2.0
        networkPollInterval = 1.0
        wifiPollInterval = 1.0
        diskPollInterval = 5.0
        processesPollInterval = 3.0
        batteryPollInterval = 10.0

        menuBarItemsRaw = "network,battery"

        launchAtLogin = false
        alertsEnabled = true
        alertPopupsEnabled = false
        alertsCooldownMinutes = 10.0
        alertsQuietHoursEnabled = false
        alertsQuietHoursStartHour = 22.0
        alertsQuietHoursEndHour = 7.0
        cpuUsageAlertThreshold = 90.0
        cpuTempAlertThreshold = 90.0
        packetLossAlertThreshold = 3.0
        jitterAlertThreshold = 30.0
        lowDiskFreePercentThreshold = 10.0
        lowBatteryAlertsEnabled = true
        lowBatteryAlertThreshold = 20.0
        batteryAutomationEnabled = true
        batteryAutomationThreshold = 20.0
        batteryAutomationAutoOpenSettings = false
        powerSaveModeActive = false
        lastDiagnosticsExportStatus = ""
    }
}
