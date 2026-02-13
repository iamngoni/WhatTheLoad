import Foundation

struct DiskMetrics {
    let timestamp: Date
    let volumes: [VolumeInfo]
    let readSpeed: Double // bytes per second
    let writeSpeed: Double
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
