import Foundation

enum TimelineSeverity: String, Codable, CaseIterable {
    case info
    case warning
    case critical
}

enum TimelineCategory: String, Codable, CaseIterable {
    case alert
    case network
    case disk
    case battery
    case process
    case system
}

struct TimelineEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let severity: TimelineSeverity
    let category: TimelineCategory
    let title: String
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        severity: TimelineSeverity,
        category: TimelineCategory,
        title: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.severity = severity
        self.category = category
        self.title = title
        self.message = message
    }
}

struct MetricSnapshot: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsedPercent: Double
    let memoryPressureScore: Double
    let networkDownload: Double
    let networkUpload: Double
    let diskFreePercent: Double
    let batteryPercent: Double?
    let batteryIsCharging: Bool?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        cpuUsage: Double,
        memoryUsedPercent: Double,
        memoryPressureScore: Double,
        networkDownload: Double,
        networkUpload: Double,
        diskFreePercent: Double,
        batteryPercent: Double?,
        batteryIsCharging: Bool?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.memoryUsedPercent = memoryUsedPercent
        self.memoryPressureScore = memoryPressureScore
        self.networkDownload = networkDownload
        self.networkUpload = networkUpload
        self.diskFreePercent = diskFreePercent
        self.batteryPercent = batteryPercent
        self.batteryIsCharging = batteryIsCharging
    }
}

enum TimelineRange: String, CaseIterable, Identifiable {
    case last24h = "24h"
    case last7d = "7d"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .last24h: return 24 * 60 * 60
        case .last7d: return 7 * 24 * 60 * 60
        }
    }
}
