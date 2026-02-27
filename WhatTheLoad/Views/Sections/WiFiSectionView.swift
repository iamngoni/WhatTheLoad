import SwiftUI
import Combine
import AppKit

struct WiFiSectionView: View {
    let monitor: WiFiMonitor
    @StateObject private var speedTest = SpeedTest()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("WI-FI")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                Spacer()

                if let current = monitor.current, let band = current.band {
                    Text(band.description)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
            }

            if monitor.current == nil {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.9)

                    Text("Loading Wi-Fi diagnostics")
                        .font(.system(size: 14))
                        .foregroundColor(Color.wtlSecondary)

                    Text("Waiting for the first Wi-Fi sample")
                        .font(.system(size: 11))
                        .foregroundColor(Color.wtlTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else if let current = monitor.current, !hasActiveWiFiConnection(current) {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 48))
                        .foregroundColor(Color.wtlTertiary)

                    Text("Not connected to Wi-Fi")
                        .font(.system(size: 14))
                        .foregroundColor(Color.wtlSecondary)

                    Text("Connect to a Wi-Fi network to view diagnostics")
                        .font(.system(size: 11))
                        .foregroundColor(Color.wtlTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else if let current = monitor.current {
                if let ssid = current.ssid {
                    StatRowView(label: "SSID", value: ssid)
                } else {
                    DiagnosticCardView(
                        icon: "location",
                        message: monitor.isLocationPermissionDenied
                            ? "Connected to Wi-Fi, but SSID is hidden. Allow Location access in System Settings to show the network name."
                            : monitor.didAttemptLocationPermissionRequest
                                ? "Connected to Wi-Fi, but macOS did not show the Location prompt. Open Location Settings and allow access for WhatTheLoad."
                            : "Connected to Wi-Fi. SSID is unavailable, but radio diagnostics are still shown.",
                        type: .warning
                    )

                    HStack(spacing: 8) {
                        if monitor.canRequestLocationPermission {
                            Button("Request Access") {
                                monitor.requestLocationPermission()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        }

                        if monitor.shouldShowManualLocationSettingsFallback {
                            Button("Open Location Settings") {
                                openLocationPrivacySettings()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                        }

                        Button("Refresh") {
                            monitor.refresh()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.wtlCard)
                        .foregroundColor(Color.wtlPrimary)
                        .cornerRadius(6)

                        Spacer()
                    }
                }

                // Three metric cards in a row
                HStack(spacing: 12) {
                    if let linkRate = current.linkRate {
                        MetricCard(
                            title: "LINK RATE",
                            value: String(format: "%.0f Mbps", linkRate),
                            color: Color.wtlPrimary
                        )
                    }

                    if let signal = current.signalStrength {
                        MetricCard(
                            title: "SIGNAL",
                            value: "\(signal) dBm",
                            color: colorForSignal(signal)
                        )
                    }

                    if let noise = current.noiseFloor {
                        MetricCard(
                            title: "NOISE",
                            value: "\(noise) dBm",
                            color: colorForNoise(noise)
                        )
                    }
                }

                // Router health
                Text("ROUTER HEALTH")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                HStack(spacing: 12) {
                    if let ping = current.routerPing {
                        MetricCard(title: "PING", value: String(format: "%.0f ms", ping), color: colorForPing(ping))
                    }
                    if let jitter = current.routerJitter {
                        MetricCard(title: "JITTER", value: String(format: "%.0f ms", jitter), color: .primary)
                    }
                    if let loss = current.routerPacketLoss {
                        MetricCard(title: "LOSS", value: String(format: "%.1f%%", loss), color: colorForLoss(loss))
                    }
                }

                // Internet health
                Text("INTERNET HEALTH (1.1.1.1)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                HStack(spacing: 12) {
                    if let ping = current.internetPing {
                        MetricCard(title: "PING", value: String(format: "%.0f ms", ping), color: colorForPing(ping))
                    }
                    if let jitter = current.internetJitter {
                        MetricCard(title: "JITTER", value: String(format: "%.0f ms", jitter), color: .primary)
                    }
                    if let loss = current.internetPacketLoss {
                        MetricCard(title: "LOSS", value: String(format: "%.1f%%", loss), color: colorForLoss(loss))
                    }
                }

                if let routerIP = current.routerIP {
                    StatRowView(label: "Router", value: routerIP)
                }

                if let dnsServer = current.dnsServer {
                    StatRowView(label: "DNS Server", value: dnsServer)
                }

                // DNS
                if let dnsTime = current.dnsLookupTime {
                    StatRowView(label: "DNS Lookup", value: String(format: "%.0f ms", dnsTime))
                }

                // Speed test
                Text("SPEED TEST")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                if speedTest.downloadSpeed > 0 || speedTest.uploadSpeed > 0 {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                            Text("↓ DOWN")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.7))
                            Text(String(format: "%.0f Mbps", speedTest.downloadSpeed))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                            Text("↑ UP")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.7))
                            Text(String(format: "%.0f Mbps", speedTest.uploadSpeed))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                Button(action: {
                    Task {
                        await speedTest.run()
                    }
                }) {
                    HStack {
                        if speedTest.isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "speedometer")
                        }

                        Text(speedTest.isRunning ? "Testing..." : "Run Speed Test")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(speedTest.isRunning)

                // Diagnostic card
                if let signal = current.signalStrength {
                    DiagnosticCardView(
                        icon: "wifi",
                        message: diagnosticMessage(for: signal),
                        type: diagnosticType(for: signal)
                    )
                }

                // Jitter diagnostic
                if let jitter = current.routerJitter, jitter > 30 {
                    DiagnosticCardView(
                        icon: "wifi",
                        message: "Jitter > 30ms — video calls may be choppy",
                        type: .warning
                    )
                }

                // Packet loss diagnostic
                if let loss = current.routerPacketLoss, loss > 2 {
                    DiagnosticCardView(
                        icon: "wifi",
                        message: "Packet loss > 2% — connection is unstable",
                        type: .error
                    )
                }
            }
        }
    }

    private func colorForSignal(_ dbm: Int) -> Color {
        switch dbm {
        case -50...0: return .green
        case -70..<(-50): return .orange
        default: return .red
        }
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

    private func hasActiveWiFiConnection(_ metrics: WiFiMetrics) -> Bool {
        metrics.band != nil ||
        (metrics.linkRate ?? 0) > 0 ||
        metrics.signalStrength != nil ||
        metrics.noiseFloor != nil
    }

    private func colorForNoise(_ dbm: Int) -> Color {
        switch dbm {
        case ...(-90): return .green
        case -90..<(-80): return .orange
        default: return .red
        }
    }

    private func colorForPing(_ ms: Double) -> Color {
        switch ms {
        case 0..<30: return .green
        case 30..<100: return .orange
        default: return .red
        }
    }

    private func colorForLoss(_ percent: Double) -> Color {
        switch percent {
        case 0..<1: return .green
        case 1..<5: return .orange
        default: return .red
        }
    }

    private func diagnosticMessage(for signal: Int) -> String {
        switch signal {
        case -50...0: return "Signal is strong. Connection looks healthy."
        case -60..<(-50): return "Signal between -60 and -75 dBm — functional but not ideal. Moving closer can help."
        default: return "Signal is weak. Consider moving closer to the router or adjusting antenna."
        }
    }

    private func diagnosticType(for signal: Int) -> DiagnosticCardView.DiagnosticType {
        switch signal {
        case -50...0: return .success
        case -70..<(-50): return .warning
        default: return .error
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlTertiary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.wtlCard)
        .cornerRadius(6)
    }
}

extension WiFiBand: CustomStringConvertible {
    var description: String {
        switch self {
        case .band2_4GHz: return "2.4 GHz"
        case .band5GHz: return "5 GHz"
        case .band6GHz: return "6 GHz"
        }
    }
}
