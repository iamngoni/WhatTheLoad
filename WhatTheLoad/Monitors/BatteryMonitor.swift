import Foundation
import IOKit.ps
import IOKit

@Observable
class BatteryMonitor {
    var current: BatteryMetrics?
    var history: [BatteryMetrics] = []

    private var timer: Timer?
    private var smcReader: SMCReader?

    func start(interval: TimeInterval = 10.0) {
        smcReader = SMCReader()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
        update()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        guard let metrics = fetchMetrics() else { return }

        current = metrics
        history.append(metrics)

        if history.count > 120 {
            history.removeFirst()
        }
    }

    private func fetchMetrics() -> BatteryMetrics? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return nil
        }

        var batteryInfo: [String: Any]?

        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
               let type = info[kIOPSTypeKey] as? String,
               type == kIOPSInternalBatteryType {
                batteryInfo = info
                break
            }
        }

        guard let info = batteryInfo else { return nil }

        let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let _ = info[kIOPSMaxCapacityKey] as? Int ?? 100
        let isCharging = (info[kIOPSIsChargingKey] as? Bool) ?? false
        let timeRemaining = info[kIOPSTimeToEmptyKey] as? Int ?? -1
        let powerSource = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue ? PowerSource.ac : PowerSource.battery

        // Try to get cycle count and health from IOKit
        var cycleCount = 0
        var health = 100.0

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            if let cycleCountRef = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0) {
                cycleCount = (cycleCountRef.takeRetainedValue() as? Int) ?? 0
            }

            // MaxCapacity from IORegistry is already a percentage (0-100)!
            if let maxCapacityRef = IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0) {
                health = Double((maxCapacityRef.takeRetainedValue() as? Int) ?? 100)
            }

            IOObjectRelease(service)
        }

        let chargePercent = Double(currentCapacity)

        return BatteryMetrics(
            timestamp: Date(),
            chargePercent: chargePercent,
            isCharging: isCharging,
            health: health,
            cycleCount: cycleCount,
            temperature: smcReader?.getBatteryTemperature(),
            timeRemaining: timeRemaining > 0 ? TimeInterval(timeRemaining * 60) : nil,
            powerDraw: nil,
            powerSource: powerSource
        )
    }
}
