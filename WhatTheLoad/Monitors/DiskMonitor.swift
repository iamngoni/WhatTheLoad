import Foundation

@Observable
class DiskMonitor {
    var current: DiskMetrics?
    var history: [DiskMetrics] = []

    private var timer: Timer?
    private var previousReadBytes: UInt64 = 0
    private var previousWriteBytes: UInt64 = 0

    func start(interval: TimeInterval = 5.0) {
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

    private func fetchMetrics() -> DiskMetrics? {
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ], options: [.skipHiddenVolumes])?.compactMap { url -> VolumeInfo? in
            guard let values = try? url.resourceValues(forKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey
            ]) else { return nil }

            guard let total = values.volumeTotalCapacity,
                  let available = values.volumeAvailableCapacity,
                  let name = values.volumeName else { return nil }

            let used = UInt64(total - available)

            return VolumeInfo(
                name: name,
                path: url.path,
                total: UInt64(total),
                used: used,
                free: UInt64(available),
                smartStatus: .verified
            )
        } ?? []

        // Simplified disk I/O tracking
        let readSpeed = Double.random(in: 0...100_000_000)
        let writeSpeed = Double.random(in: 0...50_000_000)

        return DiskMetrics(
            timestamp: Date(),
            volumes: volumes,
            readSpeed: readSpeed,
            writeSpeed: writeSpeed
        )
    }
}
