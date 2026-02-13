import SwiftUI
import Combine

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

            // Show not connected message if no WiFi
            if monitor.current == nil || monitor.current?.ssid == nil {
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
