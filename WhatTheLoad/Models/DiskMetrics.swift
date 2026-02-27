import Foundation

struct DiskMetrics {
    let timestamp: Date
    let volumes: [VolumeInfo]
    let readSpeed: Double // bytes per second
    let writeSpeed: Double
}

struct DiskSpaceConsumer: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let size: UInt64
}

enum DiskCleanupCategoryKey: String, CaseIterable, Codable, Identifiable {
    case caches
    case logs
    case derivedData
    case browserCaches

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caches: return "Caches"
        case .logs: return "Logs"
        case .derivedData: return "Xcode DerivedData"
        case .browserCaches: return "Browser Caches"
        }
    }
}

struct DiskCleanupCategoryStatus: Identifiable {
    let key: DiskCleanupCategoryKey
    let paths: [String]
    let size: UInt64

    var id: String { key.id }
    var title: String { key.title }
}

struct VolumeInfo {
    let name: String
    let path: String
    let total: UInt64
    let used: UInt64
    let free: UInt64
    let smartStatus: SMARTStatus?
}

enum SMARTStatus {
    case verified, failing, unknown
}
