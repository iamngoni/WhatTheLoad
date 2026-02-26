import Foundation

struct WiFiMetrics {
    let timestamp: Date
    let ssid: String?
    let routerIP: String?
    let band: WiFiBand?
    let linkRate: Double? // Mbps
    let signalStrength: Int? // dBm
    let noiseFloor: Int? // dBm
    let routerPing: Double?
    let routerJitter: Double?
    let routerPacketLoss: Double?
    let internetPing: Double?
    let internetJitter: Double?
    let internetPacketLoss: Double?
    let dnsLookupTime: Double?
    let dnsServer: String?
}

enum WiFiBand {
    case band2_4GHz, band5GHz, band6GHz
}
