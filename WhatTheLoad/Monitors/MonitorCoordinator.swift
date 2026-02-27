import Foundation

@Observable
class MonitorCoordinator {
    static let shared = MonitorCoordinator()

    let cpu = CPUMonitor()
    let memory = MemoryMonitor()
    let network = NetworkMonitor()
    let wifi = WiFiMonitor()
    let disk = DiskMonitor()
    let processes = ProcessMonitor()
    let battery = BatteryMonitor()
    private let settings = AppSettings.shared
    private(set) var isPowerSaveMode = false

    private struct PollingProfile {
        let cpu: Double
        let memory: Double
        let network: Double
        let wifi: Double
        let disk: Double
        let processes: Double
        let battery: Double
    }

    var systemUptime: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let days = Int(uptime / 86400)
        let hours = Int((uptime.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((uptime.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(days)d \(hours)h \(minutes)m"
    }

    func startAll() {
        applyPollingProfile()
    }

    func restartAll() {
        stopAll()
        applyPollingProfile()
    }

    func setPowerSaveMode(_ enabled: Bool) {
        guard enabled != isPowerSaveMode else { return }
        isPowerSaveMode = enabled
        restartAll()
    }

    func stopAll() {
        cpu.stop()
        memory.stop()
        network.stop()
        wifi.stop()
        disk.stop()
        processes.stop()
        battery.stop()
    }

    private func applyPollingProfile() {
        let profile = currentPollingProfile()
        cpu.start(interval: profile.cpu)
        memory.start(interval: profile.memory)
        network.start(interval: profile.network)
        wifi.start(interval: profile.wifi)
        disk.start(interval: profile.disk)
        processes.start(interval: profile.processes)
        battery.start(interval: profile.battery)
    }

    private func currentPollingProfile() -> PollingProfile {
        guard isPowerSaveMode else {
            return PollingProfile(
                cpu: settings.cpuPollInterval,
                memory: settings.memoryPollInterval,
                network: settings.networkPollInterval,
                wifi: settings.wifiPollInterval,
                disk: settings.diskPollInterval,
                processes: settings.processesPollInterval,
                battery: settings.batteryPollInterval
            )
        }

        // Low-power profile: reduce monitor update rates significantly.
        return PollingProfile(
            cpu: max(settings.cpuPollInterval * 3.0, 3.0),
            memory: max(settings.memoryPollInterval * 2.5, 5.0),
            network: max(settings.networkPollInterval * 4.0, 5.0),
            wifi: max(settings.wifiPollInterval * 4.0, 5.0),
            disk: max(settings.diskPollInterval * 2.0, 15.0),
            processes: max(settings.processesPollInterval * 2.0, 8.0),
            battery: max(settings.batteryPollInterval * 0.8, 10.0)
        )
    }
}
