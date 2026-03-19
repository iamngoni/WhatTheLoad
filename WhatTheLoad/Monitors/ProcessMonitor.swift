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

        // First call to get actual PID count
        let pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else { return nil }

        // Allocate buffer with some headroom for new processes
        let bufferSize = Int(pidCount) + 64
        var pids = [pid_t](repeating: 0, count: bufferSize)
        let count = proc_listallpids(&pids, Int32(bufferSize * MemoryLayout<pid_t>.size))
        guard count > 0 else { return nil }

        let actualCount = Int(count)
        let processes = pids.prefix(actualCount).compactMap { pid -> ProcessDetails? in
            guard pid > 0 else { return nil }

            var info = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.size
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))

            guard result == Int32(size) else { return nil }

            let name = processName(for: pid)

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
                name: name,
                executablePath: "",
                cpuUsage: cpuUsage,
                memoryUsage: memoryUsage,
                state: .running
            )
        }

        // Use a single combined score sort to avoid two full O(n log n) sorts.
        // Normalize CPU and memory into 0-1 range and combine.
        let maxMem = processes.max(by: { $0.memoryUsage < $1.memoryUsage })?.memoryUsage ?? 1
        let maxCPU = processes.max(by: { $0.cpuUsage < $1.cpuUsage })?.cpuUsage ?? 1

        let scored = processes.map { p -> (ProcessDetails, Double) in
            let memScore = maxMem > 0 ? Double(p.memoryUsage) / Double(maxMem) : 0
            let cpuScore = maxCPU > 0 ? p.cpuUsage / maxCPU : 0
            return (p, memScore + cpuScore)
        }

        let topProcesses = scored
            .sorted { $0.1 > $1.1 }
            .prefix(100)
            .map(\.0)

        previousCPUTimesByPID = currentCPUTimesByPID
        previousSampleTimestamp = sampleTime

        return ProcessMetrics(
            timestamp: sampleTime,
            processes: topProcesses
        )
    }

    private func processName(for pid: pid_t) -> String {
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let result = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        guard result > 0 else { return "Unknown" }
        return String(cString: nameBuffer)
    }

    static func executablePath(for pid: pid_t) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let result = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        guard result > 0 else { return nil }
        return String(cString: pathBuffer)
    }
}
