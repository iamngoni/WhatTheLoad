import Foundation
import CoreWLAN
import Network
import CoreLocation
import SystemConfiguration
import AppKit

@Observable
final class WiFiMonitor {
    var current: WiFiMetrics?
    var history: [WiFiMetrics] = []
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var didAttemptLocationPermissionRequest = false

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

    var shouldShowManualLocationSettingsFallback: Bool {
        isLocationPermissionDenied || (locationAuthorizationStatus == .notDetermined && didAttemptLocationPermissionRequest)
    }

    func requestLocationPermission() {
        guard let locationManager else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.didAttemptLocationPermissionRequest = true

            NSApp.activate(ignoringOtherApps: true)
            print("WiFiMonitor: Manual location permission request")
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()

            // If macOS doesn't present a prompt (common for background menu bar apps),
            // keep the UI in a state that offers manual fallback to Settings.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                if self.locationAuthorizationStatus == .notDetermined {
                    self.openLocationPrivacySettings()
                    self.update()
                }
            }
        }
    }

    func refresh() {
        update()
    }

    private func setupLocationManager() {
        let manager = CLLocationManager()
        let delegate = WiFiLocationDelegate { [weak self] status in
            guard let self else { return }
            self.locationAuthorizationStatus = status
            if status != .notDetermined {
                self.didAttemptLocationPermissionRequest = false
            }
            self.updateLocationSampling(for: status)
            self.update()
        }

        manager.delegate = delegate
        locationManager = manager
        locationDelegate = delegate

        // Check current authorization status
        let status = manager.authorizationStatus
        locationAuthorizationStatus = status
        print("WiFiMonitor: Location authorization status: \(status.rawValue)")
        updateLocationSampling(for: status)
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

    private func updateLocationSampling(for status: CLAuthorizationStatus) {
        guard let locationManager else { return }

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            locationManager.stopUpdatingLocation()
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
                dnsServer: dnsServer,
                incident: nil
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

        let metrics = WiFiMetrics(
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
            dnsServer: dnsServer,
            incident: nil
        )
        return withIncident(metrics)
    }

    private func withIncident(_ metrics: WiFiMetrics) -> WiFiMetrics {
        let incident = NetworkIncidentAnalyzer.detect(from: metrics)
        return WiFiMetrics(
            timestamp: metrics.timestamp,
            ssid: metrics.ssid,
            routerIP: metrics.routerIP,
            band: metrics.band,
            linkRate: metrics.linkRate,
            signalStrength: metrics.signalStrength,
            noiseFloor: metrics.noiseFloor,
            routerPing: metrics.routerPing,
            routerJitter: metrics.routerJitter,
            routerPacketLoss: metrics.routerPacketLoss,
            internetPing: metrics.internetPing,
            internetJitter: metrics.internetJitter,
            internetPacketLoss: metrics.internetPacketLoss,
            dnsLookupTime: metrics.dnsLookupTime,
            dnsServer: metrics.dnsServer,
            incident: incident
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

    private func openLocationPrivacySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices"
        ]

        for rawURL in urls {
            guard let url = URL(string: rawURL) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
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

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("WiFiMonitor: (legacy) location authorization changed to: \(status.rawValue)")
        onAuthorizationChange(status)
    }
}
