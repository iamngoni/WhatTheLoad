import SwiftUI

struct CPUSectionView: View {
    let monitor: CPUMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with percentage
            HStack {
                Text("CPU USAGE")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlSecondary)
                    .tracking(0.5)

                Spacer()

                if let current = monitor.current {
                    Text(String(format: "%.0f%%", current.totalUsage))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(colorForCPU(current.totalUsage))
                }
            }

            // Large sparkline
            SparklineView(
                data: monitor.history.map { $0.totalUsage },
                color: colorForCPU(monitor.current?.totalUsage ?? 0),
                height: 100
            )

            // Stats row - dark cards
            HStack(spacing: 12) {
                if let temp = monitor.current?.temperature {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TEMP")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.wtlTertiary)
                            .tracking(0.5)
                        Text(String(format: "%.0f°C", temp))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(colorForTemp(temp))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.wtlCard)
                    .cornerRadius(8)
                }

                if let freq = monitor.current?.frequency {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FREQ")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.wtlTertiary)
                            .tracking(0.5)
                        Text(String(format: "%.1f GHz", freq))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.wtlPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.wtlCard)
                    .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("THROTTLE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.wtlTertiary)
                        .tracking(0.5)
                    Text(monitor.current?.isThrottled ?? false ? "Yes" : "None")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(monitor.current?.isThrottled ?? false ? .red : .green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.wtlCard)
                .cornerRadius(8)
            }

            // Per-core usage
            if let current = monitor.current {
                Text("PER-CORE USAGE")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlSecondary)
                    .tracking(0.5)
                    .padding(.top, 4)

                ForEach(Array(current.perCoreUsage.enumerated()), id: \.offset) { index, usage in
                    HStack(spacing: 8) {
                        Text("Core \(index)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.wtlTertiary)
                            .frame(width: 50, alignment: .leading)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.wtlCard)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(colorForCPU(usage))
                                    .frame(width: geometry.size.width * (usage / 100))
                            }
                        }
                        .frame(height: 8)

                        Text(String(format: "%.0f%%", usage))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.wtlSecondary)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func colorForCPU(_ value: Double) -> Color {
        switch value {
        case 0..<50: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }

    private func colorForTemp(_ temp: Double) -> Color {
        switch temp {
        case 0..<70: return .green
        case 70..<85: return .orange
        default: return .red
        }
    }
}
