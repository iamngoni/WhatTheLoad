import Foundation

@Observable
class MemoryMonitor {
    var current: MemoryMetrics?
    var history: [MemoryMetrics] = []

    private var timer: Timer?

    func start(interval: TimeInterval = 2.0) {
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

    private func fetchMetrics() -> MemoryMetrics? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, pointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize

        let used = active + inactive

        var size: UInt64 = 0
        var sizeLength = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &sizeLength, nil, 0)

        let pressure: MemoryPressure
        let usedPercentage = Double(used + wired) / Double(size)
        if usedPercentage > 0.9 {
            pressure = .critical
        } else if usedPercentage > 0.7 {
            pressure = .warning
        } else {
            pressure = .normal
        }

        return MemoryMetrics(
            timestamp: Date(),
            used: used,
            wired: wired,
            compressed: compressed,
            free: free,
            total: size,
            pressure: pressure,
            swapUsed: UInt64(stats.swapins) * pageSize,
            swapTotal: UInt64(stats.swapins + stats.swapouts) * pageSize
        )
    }
}
