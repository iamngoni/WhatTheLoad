import Foundation

@Observable
class MonitorCoordinator {
    let cpu = CPUMonitor()
    let memory = MemoryMonitor()
    let network = NetworkMonitor()
    let wifi = WiFiMonitor()
    let disk = DiskMonitor()
    let processes = ProcessMonitor()
    let battery = BatteryMonitor()

    var systemUptime: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let days = Int(uptime / 86400)
        let hours = Int((uptime.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((uptime.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(days)d \(hours)h \(minutes)m"
    }

    func startAll() {
        cpu.start(interval: 1.0)
        memory.start(interval: 2.0)
        network.start(interval: 1.0)
        wifi.start(interval: 1.0)
        disk.start(interval: 5.0)
        processes.start(interval: 3.0)
        battery.start(interval: 10.0)
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
}
