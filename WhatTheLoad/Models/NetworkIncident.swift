import Foundation

enum NetworkIncidentType: String, Codable {
    case gatewayUnreachable
    case internetOutage
    case dnsFailure
    case unstableLink
}

struct NetworkIncident: Codable {
    let type: NetworkIncidentType
    let title: String
    let hint: String
}

enum NetworkIncidentAnalyzer {
    static func detect(from wifi: WiFiMetrics?) -> NetworkIncident? {
        guard let wifi else { return nil }

        if isGatewayUnreachable(wifi) {
            return NetworkIncident(
                type: .gatewayUnreachable,
                title: "Gateway Unreachable",
                hint: "Router is not responding. Check Wi-Fi signal/router power."
            )
        }

        if isInternetOutage(wifi) {
            return NetworkIncident(
                type: .internetOutage,
                title: "Internet Outage",
                hint: "Router is reachable but upstream internet is failing."
            )
        }

        if isDNSFailure(wifi) {
            return NetworkIncident(
                type: .dnsFailure,
                title: "DNS Failure",
                hint: "Connectivity is up but DNS lookups are failing."
            )
        }

        if isUnstableLink(wifi) {
            return NetworkIncident(
                type: .unstableLink,
                title: "Unstable Link",
                hint: "High jitter/packet loss detected. Calls and streaming may stutter."
            )
        }

        return nil
    }

    private static func isGatewayUnreachable(_ wifi: WiFiMetrics) -> Bool {
        let routerLoss = wifi.routerPacketLoss ?? 0
        if routerLoss >= 80 { return true }
        return wifi.routerPing == nil && wifi.routerIP != nil && hasRadioConnection(wifi)
    }

    private static func isInternetOutage(_ wifi: WiFiMetrics) -> Bool {
        let routerHealthy = (wifi.routerPacketLoss ?? 100) < 30 || (wifi.routerPing ?? 0) > 0
        let internetBad = (wifi.internetPacketLoss ?? 0) >= 80 || wifi.internetPing == nil
        return routerHealthy && internetBad
    }

    private static func isDNSFailure(_ wifi: WiFiMetrics) -> Bool {
        let internetHealthy = (wifi.internetPacketLoss ?? 100) < 20 || (wifi.internetPing ?? 0) > 0
        return internetHealthy && wifi.dnsLookupTime == nil
    }

    private static func isUnstableLink(_ wifi: WiFiMetrics) -> Bool {
        let loss = max(wifi.routerPacketLoss ?? 0, wifi.internetPacketLoss ?? 0)
        let jitter = max(wifi.routerJitter ?? 0, wifi.internetJitter ?? 0)
        return loss >= 2 || jitter >= 30
    }

    private static func hasRadioConnection(_ wifi: WiFiMetrics) -> Bool {
        wifi.band != nil || (wifi.linkRate ?? 0) > 0 || wifi.signalStrength != nil
    }
}
