import Foundation
import SwiftUI
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("cpuPollInterval") var cpuPollInterval: Double = 1.0
    @AppStorage("memoryPollInterval") var memoryPollInterval: Double = 2.0
    @AppStorage("networkPollInterval") var networkPollInterval: Double = 1.0
    @AppStorage("wifiPollInterval") var wifiPollInterval: Double = 1.0
    @AppStorage("diskPollInterval") var diskPollInterval: Double = 5.0
    @AppStorage("processesPollInterval") var processesPollInterval: Double = 3.0
    @AppStorage("batteryPollInterval") var batteryPollInterval: Double = 10.0

    @AppStorage("showMenuBarSparkline") var showMenuBarSparkline: Bool = true
    @AppStorage("showMenuBarNetworkText") var showMenuBarNetworkText: Bool = true
    @AppStorage("menuBarSparklineMetric") var menuBarSparklineMetric: String = "cpu"

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("lowBatteryAlertsEnabled") var lowBatteryAlertsEnabled: Bool = true
    @AppStorage("lowBatteryAlertThreshold") var lowBatteryAlertThreshold: Double = 20.0

    func resetToDefaults() {
        cpuPollInterval = 1.0
        memoryPollInterval = 2.0
        networkPollInterval = 1.0
        wifiPollInterval = 1.0
        diskPollInterval = 5.0
        processesPollInterval = 3.0
        batteryPollInterval = 10.0

        showMenuBarSparkline = true
        showMenuBarNetworkText = true
        menuBarSparklineMetric = "cpu"

        launchAtLogin = false
        lowBatteryAlertsEnabled = true
        lowBatteryAlertThreshold = 20.0
    }
}
