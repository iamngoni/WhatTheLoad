import Foundation

@Observable
final class HistoryStore {
    static let shared = HistoryStore()

    var events: [TimelineEvent] = []
    var snapshots: [MetricSnapshot] = []

    private var snapshotTimer: Timer?
    private weak var monitorCoordinator: MonitorCoordinator?
    private let ioQueue = DispatchQueue(label: "WhatTheLoad.HistoryStore.IO", qos: .utility)
    private let retentionInterval: TimeInterval = 7 * 24 * 60 * 60

    private init() {
        loadFromDisk()
    }

    func start(with coordinator: MonitorCoordinator) {
        monitorCoordinator = coordinator
        snapshotTimer?.invalidate()
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.recordSnapshotFromCurrentState()
        }
        recordSnapshotFromCurrentState()
    }

    func stop() {
        snapshotTimer?.invalidate()
        snapshotTimer = nil
    }

    func recordEvent(_ event: TimelineEvent) {
        events.insert(event, at: 0)
        pruneToRetentionWindow()
        persistToDisk()
    }

    func events(in range: TimelineRange) -> [TimelineEvent] {
        let cutoff = Date().addingTimeInterval(-range.duration)
        return events.filter { $0.timestamp >= cutoff }
    }

    func snapshots(in range: TimelineRange) -> [MetricSnapshot] {
        let cutoff = Date().addingTimeInterval(-range.duration)
        return snapshots.filter { $0.timestamp >= cutoff }
    }

    private func recordSnapshotFromCurrentState() {
        guard let coordinator = monitorCoordinator else { return }
        guard
            let cpu = coordinator.cpu.current,
            let memory = coordinator.memory.current,
            let network = coordinator.network.current,
            let disk = coordinator.disk.current?.volumes.first
        else {
            return
        }

        let memoryUsedPercent = memory.total > 0
            ? ((Double(memory.used + memory.wired) / Double(memory.total)) * 100)
            : 0

        let pressureScore: Double
        switch memory.pressure {
        case .normal: pressureScore = 0
        case .warning: pressureScore = 50
        case .critical: pressureScore = 100
        }

        let diskFreePercent = disk.total > 0 ? (Double(disk.free) / Double(disk.total)) * 100 : 0

        let snapshot = MetricSnapshot(
            cpuUsage: cpu.totalUsage,
            memoryUsedPercent: memoryUsedPercent,
            memoryPressureScore: pressureScore,
            networkDownload: network.downloadSpeed,
            networkUpload: network.uploadSpeed,
            diskFreePercent: diskFreePercent,
            batteryPercent: coordinator.battery.current?.chargePercent,
            batteryIsCharging: coordinator.battery.current?.isCharging
        )

        snapshots.insert(snapshot, at: 0)
        pruneToRetentionWindow()
        persistToDisk()
    }

    private func pruneToRetentionWindow() {
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        events.removeAll { $0.timestamp < cutoff }
        snapshots.removeAll { $0.timestamp < cutoff }

        if events.count > 5000 {
            events = Array(events.prefix(5000))
        }
        if snapshots.count > 20000 {
            snapshots = Array(snapshots.prefix(20000))
        }
    }

    private func persistenceDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent("WhatTheLoad", isDirectory: true)
    }

    private func eventsURL() -> URL? {
        persistenceDirectory()?.appendingPathComponent("timeline_events.json")
    }

    private func snapshotsURL() -> URL? {
        persistenceDirectory()?.appendingPathComponent("metric_snapshots.json")
    }

    private func persistToDisk() {
        guard
            let directory = persistenceDirectory(),
            let eventsURL = eventsURL(),
            let snapshotsURL = snapshotsURL()
        else {
            return
        }

        let eventsCopy = events
        let snapshotsCopy = snapshots

        ioQueue.async {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted]

            if let encodedEvents = try? encoder.encode(eventsCopy) {
                try? encodedEvents.write(to: eventsURL, options: .atomic)
            }
            if let encodedSnapshots = try? encoder.encode(snapshotsCopy) {
                try? encodedSnapshots.write(to: snapshotsURL, options: .atomic)
            }
        }
    }

    private func loadFromDisk() {
        guard let eventsURL = eventsURL(), let snapshotsURL = snapshotsURL() else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: eventsURL),
           let decoded = try? decoder.decode([TimelineEvent].self, from: data) {
            events = decoded
        }

        if let data = try? Data(contentsOf: snapshotsURL),
           let decoded = try? decoder.decode([MetricSnapshot].self, from: data) {
            snapshots = decoded
        }

        pruneToRetentionWindow()
    }
}
