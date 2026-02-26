import Foundation

@Observable
class ProcessMonitor {
    var current: ProcessMetrics?
    var history: [ProcessMetrics] = []

    private var timer: Timer?
    private var previousCPUTimesByPID: [pid_t: UInt64] = [:]
    private var previousSampleTimestamp: Date?

    func start(interval: TimeInterval = 3.0) {
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

    private func fetchMetrics() -> ProcessMetrics? {
        let sampleTime = Date()
        let elapsed = previousSampleTimestamp.map { sampleTime.timeIntervalSince($0) } ?? 0
        let maxCPUPercent = Double(ProcessInfo.processInfo.activeProcessorCount) * 100.0
        var currentCPUTimesByPID: [pid_t: UInt64] = [:]

        var pids = [pid_t](repeating: 0, count: 1024)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))

        guard count > 0 else { return nil }

        let actualCount = Int(count) / MemoryLayout<pid_t>.size
        let processes = pids.prefix(actualCount).compactMap { pid -> ProcessDetails? in
            guard pid > 0 else { return nil }

            var info = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.size
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))

            guard result == Int32(size) else { return nil }

            var pathBuffer = [CChar](repeating: 0, count: Int(4096))
            proc_pidpath(pid, &pathBuffer, UInt32(4096))

            let path = String(cString: pathBuffer)
            let name = (path as NSString).lastPathComponent

            let memoryUsage = info.pti_resident_size
            let totalCPUTime = UInt64(info.pti_total_user + info.pti_total_system)
            currentCPUTimesByPID[pid] = totalCPUTime

            // Only include processes with significant memory usage
            guard memoryUsage > 1_000_000 else { return nil } // > 1MB

            let cpuUsage: Double
            if elapsed > 0, let previousCPUTime = previousCPUTimesByPID[pid], totalCPUTime >= previousCPUTime {
                let deltaCPUTime = totalCPUTime - previousCPUTime
                let deltaSeconds = Double(deltaCPUTime) / 1_000_000_000.0 // proc_taskinfo time is ns
                cpuUsage = min(max((deltaSeconds / elapsed) * 100.0, 0), maxCPUPercent)
            } else {
                cpuUsage = 0
            }

            return ProcessDetails(
                id: pid,
                name: name.isEmpty ? "Unknown" : name,
                cpuUsage: cpuUsage,
                memoryUsage: memoryUsage,
                state: .running
            )
        }

        // Keep a useful working set for both memory and CPU-oriented views.
        let topByMemory = processes.sorted { $0.memoryUsage > $1.memoryUsage }.prefix(60)
        let topByCPU = processes.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(60)

        var seen = Set<pid_t>()
        var topProcesses: [ProcessDetails] = []
        for process in Array(topByCPU) + Array(topByMemory) {
            if seen.insert(process.id).inserted {
                topProcesses.append(process)
            }
            if topProcesses.count >= 100 {
                break
            }
        }

        previousCPUTimesByPID = currentCPUTimesByPID
        previousSampleTimestamp = sampleTime

        return ProcessMetrics(
            timestamp: sampleTime,
            processes: topProcesses
        )
    }
}
