import SwiftUI

struct BatterySectionView: View {
    let monitor: BatteryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BATTERY")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlSecondary)
                .tracking(0.5)

            if let current = monitor.current {
                HStack(spacing: 20) {
                    RingChartView(
                        percent: current.chargePercent,
                        color: colorForCharge(current.chargePercent),
                        size: 100
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: current.isCharging ? "bolt.fill" : "battery.100")
                                .foregroundColor(current.isCharging ? .yellow : .primary)
                                .font(.system(size: 16))

                            Text(current.isCharging ? "Charging" : "On Battery")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                        }

                        if let timeRemaining = current.timeRemaining {
                            Text(formatTimeEstimate(timeRemaining, isCharging: current.isCharging))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                StatRowView(
                    label: "Health",
                    value: String(format: "%.0f%%", current.health),
                    valueColor: colorForHealth(current.health)
                )

                StatRowView(
                    label: "Cycle Count",
                    value: "\(current.cycleCount)"
                )

                if let temp = current.temperature {
                    StatRowView(
                        label: "Temperature",
                        value: String(format: "%.0f°C", temp),
                        valueColor: colorForTemp(temp)
                    )
                }

                if let power = current.powerDraw {
                    StatRowView(
                        label: "Power Draw",
                        value: String(format: "%.1fW", power)
                    )
                }
            } else {
                Text("No battery detected")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(40)
            }
        }
    }

    private func colorForCharge(_ percent: Double) -> Color {
        switch percent {
        case 20...: return .green
        case 10..<20: return .orange
        default: return .red
        }
    }

    private func colorForHealth(_ percent: Double) -> Color {
        switch percent {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    private func colorForTemp(_ temp: Double) -> Color {
        switch temp {
        case 0..<35: return .green
        case 35..<45: return .orange
        default: return .red
        }
    }

    private func formatTimeEstimate(_ seconds: TimeInterval, isCharging: Bool) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        return isCharging
            ? String(format: "%d:%02d until full", hours, minutes)
            : String(format: "%d:%02d remaining", hours, minutes)
    }
}
