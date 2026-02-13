import Foundation

@Observable
class CPUMonitor {
    var current: CPUMetrics?
    var history: [CPUMetrics] = []

    private var timer: Timer?
    private var previousInfo: host_cpu_load_info_data_t?
    private var smcReader: SMCReader?

    func start(interval: TimeInterval = 1.0) {
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

    private func fetchMetrics() -> CPUMetrics? {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, pointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let userTime = Double(cpuLoad.cpu_ticks.0)
        let systemTime = Double(cpuLoad.cpu_ticks.1)
        let idleTime = Double(cpuLoad.cpu_ticks.2)
        let niceTime = Double(cpuLoad.cpu_ticks.3)

        let totalTime = userTime + systemTime + idleTime + niceTime
        let usedTime = userTime + systemTime + niceTime

        let totalUsage = totalTime > 0 ? (usedTime / totalTime) * 100.0 : 0.0

        return CPUMetrics(
            timestamp: Date(),
            totalUsage: min(max(totalUsage, 0), 100),
            perCoreUsage: fetchPerCoreUsage(),
            temperature: fetchTemperature(),
            frequency: fetchFrequency(),
            isThrottled: false
        )
    }

    private func fetchPerCoreUsage() -> [Double] {
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        var usages: [Double] = []

        for core in 0..<coreCount {
            var cpuLoad = processor_cpu_load_info()
            var count = mach_msg_type_number_t(MemoryLayout<processor_cpu_load_info>.stride / MemoryLayout<natural_t>.stride)

            var host = mach_host_self()
            let result = withUnsafeMutablePointer(to: &cpuLoad) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                    processor_info(processor_t(core), PROCESSOR_CPU_LOAD_INFO, &host, pointer, &count)
                }
            }

            if result == KERN_SUCCESS {
                let user = Double(cpuLoad.cpu_ticks.0)
                let system = Double(cpuLoad.cpu_ticks.1)
                let idle = Double(cpuLoad.cpu_ticks.2)
                let nice = Double(cpuLoad.cpu_ticks.3)

                let total = user + system + idle + nice
                let used = user + system + nice

                let usage = total > 0 ? (used / total) * 100.0 : 0.0
                usages.append(min(max(usage, 0), 100))
            } else {
                usages.append(0)
            }
        }

        return usages
    }

    private func fetchTemperature() -> Double? {
        return smcReader?.getCPUTemperature()
    }

    private func fetchFrequency() -> Double? {
        // Would use sysctl to get current CPU frequency
        return 3.2
    }
}
