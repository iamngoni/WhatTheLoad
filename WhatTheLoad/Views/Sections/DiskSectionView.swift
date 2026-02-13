import SwiftUI

struct DiskSectionView: View {
    let monitor: DiskMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DISK")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlSecondary)
                .tracking(0.5)

            // Volumes
            if let current = monitor.current {
                ForEach(current.volumes, id: \.path) { volume in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(volume.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            if let smart = volume.smartStatus {
                                Image(systemName: smart == .verified ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(smart == .verified ? .green : .orange)
                                    .font(.system(size: 12))
                            }
                        }

                        UsageBarView(
                            label: formatBytes(volume.used),
                            percent: Double(volume.used) / Double(volume.total) * 100,
                            color: colorForDiskUsage(Double(volume.used) / Double(volume.total) * 100)
                        )

                        Text("\(formatBytes(volume.free)) free of \(formatBytes(volume.total))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.wtlCard)
                    .cornerRadius(8)
                }

                // Read/Write speeds
                VStack(alignment: .leading, spacing: 8) {
                    Text("READ")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.wtlTertiary)

                    SparklineView(
                        data: monitor.history.map { $0.readSpeed / 1_000_000 },
                        color: .blue,
                        height: 40
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("WRITE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.wtlTertiary)

                    SparklineView(
                        data: monitor.history.map { $0.writeSpeed / 1_000_000 },
                        color: .orange,
                        height: 40
                    )
                }
            }
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func colorForDiskUsage(_ percent: Double) -> Color {
        switch percent {
        case 0..<70: return .green
        case 70..<90: return .orange
        default: return .red
        }
    }
}
