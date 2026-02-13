import Foundation

@Observable
class ProcessMonitor {
    var current: ProcessMetrics?
    var history: [ProcessMetrics] = []

    private var timer: Timer?

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

            // Only include processes with significant memory usage
            guard memoryUsage > 1_000_000 else { return nil } // > 1MB

            // Simple CPU percentage (not perfect but good enough for display)
            let cpuUsage = Double(info.pti_total_user + info.pti_total_system) / 10_000_000.0

            return ProcessDetails(
                id: pid,
                name: name.isEmpty ? "Unknown" : name,
                cpuUsage: min(cpuUsage, 100.0),
                memoryUsage: memoryUsage,
                state: .running
            )
        }

        // Sort by memory usage and take top 20
        let topProcesses = processes
            .sorted { $0.memoryUsage > $1.memoryUsage }
            .prefix(20)
            .map { $0 }

        return ProcessMetrics(
            timestamp: Date(),
            processes: topProcesses
        )
    }
}
