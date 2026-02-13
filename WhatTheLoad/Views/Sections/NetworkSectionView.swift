import SwiftUI

struct NetworkSectionView: View {
    let monitor: NetworkMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NETWORK")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlSecondary)
                .tracking(0.5)

            // Upload speed
            VStack(alignment: .leading, spacing: 8) {
                Text("UPLOAD")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlTertiary)

                SparklineView(
                    data: monitor.history.map { $0.uploadSpeed / 1_000_000 },
                    color: .green,
                    height: 50
                )

                Text(formatSpeed(monitor.current?.uploadSpeed ?? 0))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            // Download speed
            VStack(alignment: .leading, spacing: 8) {
                Text("DOWNLOAD")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlTertiary)

                SparklineView(
                    data: monitor.history.map { $0.downloadSpeed / 1_000_000 },
                    color: .blue,
                    height: 50
                )

                Text(formatSpeed(monitor.current?.downloadSpeed ?? 0))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            if let current = monitor.current {
                StatRowView(label: "Interface", value: current.interfaceName)

                if let localIP = current.localIP {
                    StatRowView(label: "Local IP", value: localIP)
                }

                StatRowView(label: "Connections", value: "\(current.activeConnections)")
            }
        }
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let mbps = bytesPerSecond / 1_000_000
        return String(format: "%.1f MB/s", mbps)
    }
}
