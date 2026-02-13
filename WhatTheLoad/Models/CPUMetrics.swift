import Foundation

struct CPUMetrics {
    let timestamp: Date
    let totalUsage: Double
    let perCoreUsage: [Double]
    let temperature: Double?
    let frequency: Double?
    let isThrottled: Bool
}
