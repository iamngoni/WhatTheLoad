import Foundation

struct NetworkMetrics {
    let timestamp: Date
    let uploadSpeed: Double // bytes per second
    let downloadSpeed: Double
    let interfaceName: String
    let localIP: String?
    let publicIP: String?
    let activeConnections: Int
}
