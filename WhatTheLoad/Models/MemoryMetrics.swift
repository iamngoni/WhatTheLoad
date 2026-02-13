import Foundation

struct MemoryMetrics {
    let timestamp: Date
    let used: UInt64
    let wired: UInt64
    let compressed: UInt64
    let free: UInt64
    let total: UInt64
    let pressure: MemoryPressure
    let swapUsed: UInt64
    let swapTotal: UInt64
}

enum MemoryPressure {
    case normal, warning, critical
}
