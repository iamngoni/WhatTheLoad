import Foundation

struct BatteryMetrics {
    let timestamp: Date
    let chargePercent: Double
    let isCharging: Bool
    let health: Double // max capacity percentage
    let cycleCount: Int
    let temperature: Double?
    let timeRemaining: TimeInterval? // seconds
    let powerDraw: Double? // watts
    let powerSource: PowerSource
}

enum PowerSource {
    case battery, ac, unknown
}
