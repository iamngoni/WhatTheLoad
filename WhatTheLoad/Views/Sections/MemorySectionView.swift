import SwiftUI

struct MemorySectionView: View {
    let monitor: MemoryMonitor
    let processMonitor: ProcessMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with usage
            HStack {
                Text("MEMORY")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlSecondary)
                    .tracking(0.5)

                Spacer()

                if let current = monitor.current {
                    let usedGB = Double(current.used + current.wired) / 1_073_741_824
                    let totalGB = Double(current.total) / 1_073_741_824
                    Text(String(format: "%.1f / %.0f GB", usedGB, totalGB))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.wtlPrimary)
                }
            }

            if let current = monitor.current {
                // Ring chart and breakdown
                HStack(spacing: 20) {
                    RingChartView(
                        percent: Double(current.used + current.wired) / Double(current.total) * 100,
                        color: colorForPressure(current.pressure),
                        size: 100
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        MemoryRow(label: "Used", bytes: current.used, color: .green)
                        MemoryRow(label: "Wired", bytes: current.wired, color: .blue)
                        MemoryRow(label: "Compressed", bytes: current.compressed, color: .purple)
                        MemoryRow(label: "Free", bytes: current.free, color: Color.wtlTertiary)
                    }
                }

                // Memory pressure
                HStack {
                    Text("MEMORY PRESSURE")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.wtlSecondary)
                        .tracking(0.5)

                    Spacer()

                    Text(current.pressure.description.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(colorForPressure(current.pressure))
                }
                .padding(12)
                .background(Color.wtlCard)
                .cornerRadius(8)

                // Swap usage
                if current.swapUsed > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SWAP USAGE")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.wtlSecondary)
                            .tracking(0.5)

                        HStack(spacing: 8) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.wtlCard)

                                    let swapPercent = current.swapTotal > 0 ? Double(current.swapUsed) / Double(current.swapTotal) : 0
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(.orange)
                                        .frame(width: geometry.size.width * swapPercent)
                                }
                            }
                            .frame(height: 8)

                            Text(formatBytes(current.swapUsed))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.wtlPrimary)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }

                // Top consumers
                Text("TOP CONSUMERS")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlSecondary)
                    .tracking(0.5)
                    .padding(.top, 4)

                if let processes = processMonitor.current?.processes.prefix(4) {
                    ForEach(Array(processes), id: \.id) { process in
                        HStack {
                            Text(process.name)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color.wtlPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text(formatBytes(process.memoryUsage))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.wtlSecondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.wtlCard)
                        .cornerRadius(6)
                    }
                }
            }
        }
    }

    private func colorForPressure(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct MemoryRow: View {
    let label: String
    let bytes: UInt64
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlSecondary)

            Spacer()

            Text(formatBytes(bytes))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.wtlPrimary)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

extension MemoryPressure: CustomStringConvertible {
    var description: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Moderate"
        case .critical: return "Critical"
        }
    }
}
