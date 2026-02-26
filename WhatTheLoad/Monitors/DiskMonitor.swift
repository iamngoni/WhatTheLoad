import Foundation
import IOKit
import IOKit.storage

@Observable
class DiskMonitor {
    var current: DiskMetrics?
    var history: [DiskMetrics] = []

    private var timer: Timer?
    private var previousReadBytes: UInt64 = 0
    private var previousWriteBytes: UInt64 = 0
    private var previousIOSampleTime: Date?

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
        let sampleTime = Date()
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

        let counters = readDiskIOCounters()
        let elapsed = previousIOSampleTime.map { sampleTime.timeIntervalSince($0) } ?? 0

        let readSpeed: Double
        let writeSpeed: Double
        if let counters, elapsed > 0 {
            let readDelta = counters.read >= previousReadBytes ? counters.read - previousReadBytes : 0
            let writeDelta = counters.write >= previousWriteBytes ? counters.write - previousWriteBytes : 0
            readSpeed = Double(readDelta) / elapsed
            writeSpeed = Double(writeDelta) / elapsed
            previousReadBytes = counters.read
            previousWriteBytes = counters.write
        } else {
            readSpeed = 0
            writeSpeed = 0
            if let counters {
                previousReadBytes = counters.read
                previousWriteBytes = counters.write
            }
        }
        previousIOSampleTime = sampleTime

        return DiskMetrics(
            timestamp: sampleTime,
            volumes: volumes,
            readSpeed: readSpeed,
            writeSpeed: writeSpeed
        )
    }

    private func readDiskIOCounters() -> (read: UInt64, write: UInt64)? {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else { return nil }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let statsRef = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0),
               let stats = statsRef.takeRetainedValue() as? [String: Any] {
                totalRead += uint64Value(from: stats["Bytes (Read)"])
                totalWrite += uint64Value(from: stats["Bytes (Write)"])
            }

            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return (totalRead, totalWrite)
    }

    private func uint64Value(from value: Any?) -> UInt64 {
        switch value {
        case let number as NSNumber:
            return number.uint64Value
        case let value as UInt64:
            return value
        case let value as Int:
            return UInt64(max(0, value))
        default:
            return 0
        }
    }
}
