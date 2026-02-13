import Foundation
import CoreWLAN
import Network

@Observable
class WiFiMonitor {
    var current: WiFiMetrics?
    var history: [WiFiMetrics] = []

    private var timer: Timer?
    private let client = CWWiFiClient.shared()
    private var routerPingEngine: PingEngine?
    private var internetPingEngine: PingEngine?

    func start(interval: TimeInterval = 1.0) {
        timer?.invalidate()

        // Start ping engines
        routerPingEngine = PingEngine(host: getRouterIP())
        routerPingEngine?.start()

        internetPingEngine = PingEngine(host: "1.1.1.1")
        internetPingEngine?.start()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
        update()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        routerPingEngine?.stop()
        internetPingEngine?.stop()
        routerPingEngine = nil
        internetPingEngine = nil
    }

    private func update() {
        guard let metrics = fetchMetrics() else { return }

        current = metrics
        history.append(metrics)

        if history.count > 120 {
            history.removeFirst()
        }
    }

    private func fetchMetrics() -> WiFiMetrics? {
        guard let interface = client.interface() else {
            // Return empty metrics if no WiFi interface available
            return WiFiMetrics(
                timestamp: Date(),
                ssid: nil,
                band: nil,
                linkRate: nil,
                signalStrength: nil,
                noiseFloor: nil,
                routerPing: nil,
                routerJitter: nil,
                routerPacketLoss: nil,
                internetPing: nil,
                internetJitter: nil,
                internetPacketLoss: nil,
                dnsLookupTime: nil,
                dnsServer: nil
            )
        }

        let band: WiFiBand?
        if let channel = interface.wlanChannel() {
            switch channel.channelBand {
            case .band2GHz: band = .band2_4GHz
            case .band5GHz: band = .band5GHz
            case .band6GHz: band = .band6GHz
            default: band = nil
            }
        } else {
            band = nil
        }

        return WiFiMetrics(
            timestamp: Date(),
            ssid: interface.ssid(),
            band: band,
            linkRate: Double(interface.transmitRate()),
            signalStrength: interface.rssiValue(),
            noiseFloor: interface.noiseMeasurement(),
            routerPing: routerPingEngine?.currentPing,
            routerJitter: routerPingEngine?.jitter,
            routerPacketLoss: routerPingEngine?.packetLoss,
            internetPing: internetPingEngine?.currentPing,
            internetJitter: internetPingEngine?.jitter,
            internetPacketLoss: internetPingEngine?.packetLoss,
            dnsLookupTime: measureDNSLookup(),
            dnsServer: getDNSServer()
        )
    }

    private func getRouterIP() -> String {
        // Simplified: would parse route table
        return "192.168.1.1"
    }


    private func measureDNSLookup() -> Double? {
        let start = Date()
        let _ = try? getaddrinfo("google.com", nil, nil, nil)
        return Date().timeIntervalSince(start) * 1000
    }

    private func getDNSServer() -> String? {
        // Simplified placeholder
        return "8.8.8.8"
    }
}
