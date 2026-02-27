import Foundation

@Observable
class CPUMonitor {
    var current: CPUMetrics?
    var history: [CPUMetrics] = []

    private var timer: Timer?
    private var previousInfo: host_cpu_load_info_data_t?
    private var previousPerCoreTicks: [CPUTicks] = []
    private var smcReader: SMCReader?

    private struct CPUTicks {
        let user: Int64
        let system: Int64
        let idle: Int64
        let nice: Int64
    }

    func start(interval: TimeInterval = 1.0) {
        smcReader = SMCReader()
        timer?.invalidate()
        previousInfo = nil
        previousPerCoreTicks = []
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

        let userTime = Int64(cpuLoad.cpu_ticks.0)
        let systemTime = Int64(cpuLoad.cpu_ticks.1)
        let idleTime = Int64(cpuLoad.cpu_ticks.2)
        let niceTime = Int64(cpuLoad.cpu_ticks.3)
        let currentTicks = CPUTicks(user: userTime, system: systemTime, idle: idleTime, nice: niceTime)
        let totalUsage: Double

        if let previousInfo {
            let previousTicks = CPUTicks(
                user: Int64(previousInfo.cpu_ticks.0),
                system: Int64(previousInfo.cpu_ticks.1),
                idle: Int64(previousInfo.cpu_ticks.2),
                nice: Int64(previousInfo.cpu_ticks.3)
            )
            totalUsage = usagePercentage(from: previousTicks, to: currentTicks)
        } else {
            totalUsage = 0
        }
        previousInfo = cpuLoad

        let measuredPerCoreUsage = fetchPerCoreUsage()
        let hasPerCoreSignal = measuredPerCoreUsage.contains { $0 > 0.05 }
        let perCoreUsage = hasPerCoreSignal
            ? measuredPerCoreUsage
            : fallbackPerCoreUsage(totalUsage: totalUsage)
        let resolvedTotalUsage = perCoreUsage.isEmpty
            ? totalUsage
            : (perCoreUsage.reduce(0, +) / Double(perCoreUsage.count))

        return CPUMetrics(
            timestamp: Date(),
            totalUsage: min(max(resolvedTotalUsage, 0), 100),
            perCoreUsage: perCoreUsage,
            temperature: fetchTemperature(),
            frequency: fetchFrequency(),
            isThrottled: false
        )
    }

    private func fetchPerCoreUsage() -> [Double] {
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        var cpuCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return previousPerCoreTicks.map { _ in 0 }
        }

        let cpuStateCount = Int(CPU_STATE_MAX)
        var currentPerCoreTicks: [CPUTicks] = []
        currentPerCoreTicks.reserveCapacity(Int(cpuCount))

        for core in 0..<Int(cpuCount) {
            let base = core * cpuStateCount
            let user = Int64(cpuInfo[base + Int(CPU_STATE_USER)])
            let system = Int64(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            let idle = Int64(cpuInfo[base + Int(CPU_STATE_IDLE)])
            let nice = Int64(cpuInfo[base + Int(CPU_STATE_NICE)])
            currentPerCoreTicks.append(CPUTicks(user: user, system: system, idle: idle, nice: nice))
        }

        let deallocateSize = vm_size_t(Int(cpuInfoCount) * MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), deallocateSize)

        guard previousPerCoreTicks.count == currentPerCoreTicks.count else {
            previousPerCoreTicks = currentPerCoreTicks
            return currentPerCoreTicks.map { _ in 0 }
        }

        let usages = zip(previousPerCoreTicks, currentPerCoreTicks).map { previousTicks, currentTicks in
            usagePercentage(from: previousTicks, to: currentTicks)
        }
        previousPerCoreTicks = currentPerCoreTicks
        return usages
    }

    private func usagePercentage(from previous: CPUTicks, to current: CPUTicks) -> Double {
        let userDelta = safeDelta(current.user, previous.user)
        let systemDelta = safeDelta(current.system, previous.system)
        let idleDelta = safeDelta(current.idle, previous.idle)
        let niceDelta = safeDelta(current.nice, previous.nice)

        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else { return 0 }

        let usedDelta = userDelta + systemDelta + niceDelta
        return (Double(usedDelta) / Double(totalDelta)) * 100.0
    }

    private func safeDelta(_ current: Int64, _ previous: Int64) -> UInt64 {
        guard current >= previous else {
            return UInt64(max(current, 0))
        }
        return UInt64(current - previous)
    }

    private func fetchTemperature() -> Double? {
        return smcReader?.getCPUTemperature()
    }

    private func fetchFrequency() -> Double? {
        // Would use sysctl to get current CPU frequency
        return 3.2
    }

    private func fallbackPerCoreUsage(totalUsage: Double) -> [Double] {
        let coreCount = max(ProcessInfo.processInfo.activeProcessorCount, 1)
        let clamped = min(max(totalUsage, 0), 100)
        return Array(repeating: clamped, count: coreCount)
    }
}
