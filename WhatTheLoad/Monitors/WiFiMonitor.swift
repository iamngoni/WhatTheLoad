import Foundation
import CoreWLAN
import Network
import CoreLocation
import SystemConfiguration

@Observable
final class WiFiMonitor {
    var current: WiFiMetrics?
    var history: [WiFiMetrics] = []
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    private var timer: Timer?
    private let client = CWWiFiClient.shared()
    private var routerPingEngine: PingEngine?
    private var internetPingEngine: PingEngine?
    private var locationManager: CLLocationManager?
    private var locationDelegate: WiFiLocationDelegate?
    private var dynamicStore: SCDynamicStore?
    private var currentRouterIP: String = "192.168.1.1"

    init() {
        dynamicStore = SCDynamicStoreCreate(nil, "WhatTheLoad.WiFiMonitor" as CFString, nil, nil)
        setupLocationManager()
    }

    var isLocationPermissionDenied: Bool {
        locationAuthorizationStatus == .denied || locationAuthorizationStatus == .restricted
    }

    var canRequestLocationPermission: Bool {
        locationAuthorizationStatus == .notDetermined
    }

    func requestLocationPermission() {
        guard let locationManager else { return }
        print("WiFiMonitor: Manual location permission request")
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func refresh() {
        update()
    }

    private func setupLocationManager() {
        let manager = CLLocationManager()
        let delegate = WiFiLocationDelegate { [weak self] status in
            guard let self else { return }
            self.locationAuthorizationStatus = status
            self.update()
        }

        manager.delegate = delegate
        locationManager = manager
        locationDelegate = delegate

        // Check current authorization status
        let status = manager.authorizationStatus
        locationAuthorizationStatus = status
        print("WiFiMonitor: Location authorization status: \(status.rawValue)")

        if status == .notDetermined {
            print("WiFiMonitor: Requesting location authorization")
            manager.requestWhenInUseAuthorization()
        }

        // Start location updates to trigger permission dialog and maintain authorization
        manager.startUpdatingLocation()
    }

    func start(interval: TimeInterval = 1.0) {
        timer?.invalidate()

        // Start ping engines
        currentRouterIP = getRouterIP() ?? currentRouterIP
        routerPingEngine = PingEngine(host: currentRouterIP)
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
        refreshRouterPingEngineIfNeeded()
        guard let metrics = fetchMetrics() else { return }

        current = metrics
        history.append(metrics)

        if history.count > 120 {
            history.removeFirst()
        }
    }

    private func fetchMetrics() -> WiFiMetrics? {
        let routerIP = getRouterIP()
        let dnsServer = getDNSServer()

        guard let interface = client.interface() else {
            print("WiFiMonitor: No WiFi interface available")
            // Return empty metrics if no WiFi interface available
            return WiFiMetrics(
                timestamp: Date(),
                ssid: nil,
                routerIP: routerIP,
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
                dnsServer: dnsServer
            )
        }

        let ssid = interface.ssid()
        let channel = interface.wlanChannel()
        print("WiFiMonitor: interface=\(interface.interfaceName ?? "unknown"), ssid=\(ssid ?? "nil"), channel=\(channel?.channelNumber ?? 0), band=\(channel?.channelBand.rawValue ?? 0)")

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
            ssid: ssid,
            routerIP: routerIP,
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
            dnsServer: dnsServer
        )
    }

    private func refreshRouterPingEngineIfNeeded() {
        guard let routerIP = getRouterIP(), routerIP != currentRouterIP else { return }

        currentRouterIP = routerIP
        routerPingEngine?.stop()
        routerPingEngine = PingEngine(host: routerIP)
        routerPingEngine?.start()
    }

    private func getRouterIP() -> String? {
        guard let store = dynamicStore else { return nil }

        if let primaryService = primaryServiceID(from: store),
           let ipv4 = SCDynamicStoreCopyValue(store, "State:/Network/Service/\(primaryService)/IPv4" as CFString) as? [String: Any],
           let router = ipv4["Router"] as? String,
           !router.isEmpty {
            return router
        }

        if let globalIPv4 = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
           let router = globalIPv4["Router"] as? String,
           !router.isEmpty {
            return router
        }

        return nil
    }

    private func primaryServiceID(from store: SCDynamicStore) -> String? {
        guard let globalIPv4 = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any] else {
            return nil
        }
        return globalIPv4["PrimaryService"] as? String
    }


    private func measureDNSLookup() -> Double? {
        let start = Date()
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo("google.com", nil, nil, &result)
        if let result {
            freeaddrinfo(result)
        }
        guard status == 0 else { return nil }
        return Date().timeIntervalSince(start) * 1000
    }

    private func getDNSServer() -> String? {
        guard let store = dynamicStore else { return nil }

        if let primaryService = primaryServiceID(from: store),
           let dns = SCDynamicStoreCopyValue(store, "State:/Network/Service/\(primaryService)/DNS" as CFString) as? [String: Any],
           let servers = dns["ServerAddresses"] as? [String],
           let first = servers.first,
           !first.isEmpty {
            return first
        }

        if let globalDNS = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any],
           let servers = globalDNS["ServerAddresses"] as? [String],
           let first = servers.first,
           !first.isEmpty {
            return first
        }

        return nil
    }
}

private final class WiFiLocationDelegate: NSObject, CLLocationManagerDelegate {
    private let onAuthorizationChange: (CLAuthorizationStatus) -> Void

    init(onAuthorizationChange: @escaping (CLAuthorizationStatus) -> Void) {
        self.onAuthorizationChange = onAuthorizationChange
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("WiFiMonitor: Location authorization changed to: \(status.rawValue)")
        onAuthorizationChange(status)
    }
}
