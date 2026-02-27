import Foundation
import IOKit
import IOKit.storage
import AppKit

@Observable
class DiskMonitor {
    var current: DiskMetrics?
    var history: [DiskMetrics] = []

    var cacheFolderSize: UInt64 = 0
    var cleanupCategories: [DiskCleanupCategoryStatus] = []
    var largestConsumers: [DiskSpaceConsumer] = []
    var largestCacheEntries: [DiskSpaceConsumer] = []
    var isAnalyzingSpace = false
    var isCleaningUpSpace = false
    var cleanupStatus: String?
    var lastSpaceAnalysisAt: Date?

    private var timer: Timer?
    private var previousReadBytes: UInt64 = 0
    private var previousWriteBytes: UInt64 = 0
    private var previousIOSampleTime: Date?
    private let historyStore = HistoryStore.shared

    private struct SpaceAnalysisResult {
        let cacheFolderSize: UInt64
        let cleanupCategories: [DiskCleanupCategoryStatus]
        let largestConsumers: [DiskSpaceConsumer]
        let largestCacheEntries: [DiskSpaceConsumer]
    }

    func start(interval: TimeInterval = 5.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
        update()
        refreshSpaceAnalysis()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refreshSpaceAnalysis() {
        guard !isAnalyzingSpace else { return }

        isAnalyzingSpace = true

        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let analysis = self.buildSpaceAnalysis(homeURL: homeURL)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.cacheFolderSize = analysis.cacheFolderSize
                self.cleanupCategories = analysis.cleanupCategories
                self.largestConsumers = analysis.largestConsumers
                self.largestCacheEntries = analysis.largestCacheEntries
                self.lastSpaceAnalysisAt = Date()
                self.isAnalyzingSpace = false
            }
        }
    }

    func clearLibraryCaches() {
        cleanCategory(.caches)
    }

    func cleanCategory(_ category: DiskCleanupCategoryKey) {
        guard !isCleaningUpSpace else { return }
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let targets = categoryPaths(for: category, homeURL: homeURL)
        cleanPaths(targets, title: category.title, category: category)
    }

    func revealCategory(_ category: DiskCleanupCategoryKey) {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let targets = categoryPaths(for: category, homeURL: homeURL)

        guard let firstExisting = targets.first(where: {
            FileManager.default.fileExists(atPath: URL(fileURLWithPath: $0).path)
        }) else {
            cleanupStatus = "No path found for \(category.title)."
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: firstExisting)])
    }

    func moveItemToTrash(_ consumer: DiskSpaceConsumer) {
        guard !isCleaningUpSpace else { return }

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        guard consumer.path.hasPrefix(homePath + "/") else {
            cleanupStatus = "Only items in your home directory can be moved to Trash."
            return
        }

        isCleaningUpSpace = true
        cleanupStatus = nil

        let sourceURL = URL(fileURLWithPath: consumer.path)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }

            do {
                _ = try FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.cleanupStatus = "Moved \(consumer.name) to Trash (\(self.formatBytes(consumer.size)))."
                    self.historyStore.recordEvent(TimelineEvent(
                        severity: .info,
                        category: .disk,
                        title: "Item Moved to Trash",
                        message: "\(consumer.name) (\(self.formatBytes(consumer.size)))."
                    ))
                    self.isCleaningUpSpace = false
                    self.refreshSpaceAnalysis()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.cleanupStatus = "Failed to move \(consumer.name) to Trash: \(error.localizedDescription)"
                    self.isCleaningUpSpace = false
                }
            }
        }
    }

    private func cleanPaths(_ paths: [String], title: String, category: DiskCleanupCategoryKey) {
        guard !paths.isEmpty else {
            cleanupStatus = "No paths found for \(title)."
            return
        }

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let safePaths = paths.filter { $0.hasPrefix(homePath + "/") }
        guard !safePaths.isEmpty else {
            cleanupStatus = "Cleanup is limited to paths in your home directory."
            return
        }

        isCleaningUpSpace = true
        cleanupStatus = nil

        let estimatedRemovedSize = safePaths.reduce(UInt64(0)) { partial, path in
            partial + sizeOfItem(at: URL(fileURLWithPath: path))
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let fileManager = FileManager.default

            var removedItems = 0
            var failedItems = 0

            for path in safePaths {
                let url = URL(fileURLWithPath: path)
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }

                if isDirectory.boolValue {
                    do {
                        let children = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
                        for child in children {
                            do {
                                try fileManager.removeItem(at: child)
                                removedItems += 1
                            } catch {
                                failedItems += 1
                            }
                        }
                    } catch {
                        failedItems += 1
                    }
                } else {
                    do {
                        try fileManager.removeItem(at: url)
                        removedItems += 1
                    } catch {
                        failedItems += 1
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let freedText = self.formatBytes(estimatedRemovedSize)
                if failedItems == 0 {
                    self.cleanupStatus = "Cleaned \(title) (\(freedText), \(removedItems) items)."
                } else {
                    self.cleanupStatus = "Cleaned \(title) (\(freedText), \(removedItems) items, \(failedItems) failed)."
                }

                self.historyStore.recordEvent(TimelineEvent(
                    severity: failedItems == 0 ? .info : .warning,
                    category: .disk,
                    title: "Cleanup: \(category.title)",
                    message: self.cleanupStatus ?? "Cleanup completed."
                ))

                self.isCleaningUpSpace = false
                self.refreshSpaceAnalysis()
            }
        }
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

    private func buildSpaceAnalysis(homeURL: URL) -> SpaceAnalysisResult {
        let fileManager = FileManager.default
        let candidateRelativePaths = [
            "Library/Caches",
            "Library/Application Support",
            "Library/Containers",
            "Library/Group Containers",
            "Downloads",
            "Documents",
            "Desktop",
            "Movies",
            "Pictures",
            "Developer",
            ".Trash"
        ]

        var consumers: [DiskSpaceConsumer] = []
        let cacheURL = homeURL.appendingPathComponent("Library/Caches", isDirectory: true)
        let cacheSize = sizeOfItem(at: cacheURL)

        for relativePath in candidateRelativePaths {
            let url = homeURL.appendingPathComponent(relativePath, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let size = sizeOfItem(at: url)
            guard size > 0 else { continue }

            consumers.append(DiskSpaceConsumer(
                name: relativePath,
                path: url.path,
                size: size
            ))
        }

        consumers.sort { $0.size > $1.size }
        let topConsumers = Array(consumers.prefix(8))

        let cacheEntries = largestChildren(in: cacheURL, maxCount: 6)
        let cleanupCategories = buildCleanupCategories(homeURL: homeURL)

        return SpaceAnalysisResult(
            cacheFolderSize: cacheSize,
            cleanupCategories: cleanupCategories,
            largestConsumers: topConsumers,
            largestCacheEntries: cacheEntries
        )
    }

    private func buildCleanupCategories(homeURL: URL) -> [DiskCleanupCategoryStatus] {
        DiskCleanupCategoryKey.allCases.map { key in
            let paths = categoryPaths(for: key, homeURL: homeURL).filter {
                FileManager.default.fileExists(atPath: $0)
            }
            let size = paths.reduce(UInt64(0)) { partial, path in
                partial + sizeOfItem(at: URL(fileURLWithPath: path))
            }
            return DiskCleanupCategoryStatus(key: key, paths: paths, size: size)
        }
    }

    private func categoryPaths(for category: DiskCleanupCategoryKey, homeURL: URL) -> [String] {
        switch category {
        case .caches:
            return [homeURL.appendingPathComponent("Library/Caches", isDirectory: true).path]
        case .logs:
            return [homeURL.appendingPathComponent("Library/Logs", isDirectory: true).path]
        case .derivedData:
            return [homeURL.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true).path]
        case .browserCaches:
            return [
                homeURL.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true).path,
                homeURL.appendingPathComponent("Library/Caches/Google/Chrome", isDirectory: true).path,
                homeURL.appendingPathComponent("Library/Caches/Firefox", isDirectory: true).path,
                homeURL.appendingPathComponent("Library/Caches/Microsoft Edge", isDirectory: true).path,
                homeURL.appendingPathComponent("Library/Caches/com.brave.Browser", isDirectory: true).path,
                homeURL.appendingPathComponent("Library/Application Support/Firefox/Profiles", isDirectory: true).path
            ]
        }
    }

    private func largestChildren(in directoryURL: URL, maxCount: Int) -> [DiskSpaceConsumer] {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        var consumers: [DiskSpaceConsumer] = []
        for entry in entries {
            let size = sizeOfItem(at: entry)
            guard size > 0 else { continue }
            consumers.append(DiskSpaceConsumer(
                name: entry.lastPathComponent,
                path: entry.path,
                size: size
            ))
        }

        return Array(consumers.sorted { $0.size > $1.size }.prefix(maxCount))
    }

    private func sizeOfItem(at url: URL) -> UInt64 {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .totalFileSizeKey,
            .fileSizeKey
        ]

        if !isDirectory.boolValue {
            return fileSize(for: url, keys: keys)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            autoreleasepool {
                total += fileSize(for: fileURL, keys: keys)
            }
        }
        return total
    }

    private func fileSize(for url: URL, keys: Set<URLResourceKey>) -> UInt64 {
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        guard values.isSymbolicLink != true, values.isRegularFile == true else { return 0 }

        let size = values.totalFileAllocatedSize
            ?? values.fileAllocatedSize
            ?? values.totalFileSize
            ?? values.fileSize
            ?? 0

        return UInt64(max(size, 0))
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
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
