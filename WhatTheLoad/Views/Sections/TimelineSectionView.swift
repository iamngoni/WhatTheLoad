import SwiftUI

struct TimelineSectionView: View {
    let historyStore: HistoryStore
    @State private var range: TimelineRange = .last24h

    private var events: [TimelineEvent] {
        historyStore
            .events(in: range)
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var snapshots: [MetricSnapshot] {
        historyStore
            .snapshots(in: range)
            .sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TIMELINE")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlSecondary)
                    .tracking(0.5)

                Spacer()

                Picker("Range", selection: $range) {
                    ForEach(TimelineRange.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }

            summaryCards
            trendsSection
            eventsSection
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 8) {
            TimelineSummaryCard(
                title: "Alerts",
                value: "\(events.filter { $0.category == .alert }.count)",
                color: .orange
            )
            TimelineSummaryCard(
                title: "Incidents",
                value: "\(events.filter { $0.category == .network }.count)",
                color: .red
            )
            TimelineSummaryCard(
                title: "Cleanup",
                value: "\(events.filter { $0.category == .disk }.count)",
                color: .blue
            )
            TimelineSummaryCard(
                title: "Snapshot",
                value: latestSnapshotAge,
                color: .green
            )
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRENDS")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlTertiary)
                .tracking(0.5)

            TimelineTrendCard(title: "CPU", subtitle: "%", data: snapshots.map { $0.cpuUsage }, color: .orange)
            TimelineTrendCard(title: "MEMORY", subtitle: "%", data: snapshots.map { $0.memoryUsedPercent }, color: .blue)
            TimelineTrendCard(title: "DOWN", subtitle: "MB/s", data: snapshots.map { $0.networkDownload / 1_000_000 }, color: .green)
            TimelineTrendCard(title: "UP", subtitle: "MB/s", data: snapshots.map { $0.networkUpload / 1_000_000 }, color: .cyan)

            if snapshots.contains(where: { $0.batteryPercent != nil }) {
                TimelineTrendCard(
                    title: "BATTERY",
                    subtitle: "%",
                    data: snapshots.compactMap { $0.batteryPercent },
                    color: .yellow
                )
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EVENTS")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlTertiary)
                .tracking(0.5)

            if events.isEmpty {
                Text("No events recorded in this range.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.wtlSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.wtlCard)
                    .cornerRadius(8)
            } else {
                ForEach(events.prefix(80)) { event in
                    TimelineEventRow(event: event)
                }
            }
        }
    }

    private var latestSnapshotAge: String {
        guard let last = snapshots.last?.timestamp else { return "none" }

        let age = max(0, Int(Date().timeIntervalSince(last)))
        if age < 60 { return "\(age)s" }
        let minutes = age / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }
}

private struct TimelineSummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlTertiary)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.wtlCard)
        .cornerRadius(8)
    }
}

private struct TimelineTrendCard: View {
    let title: String
    let subtitle: String
    let data: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlTertiary)

                Spacer()

                let latest = data.last ?? 0
                Text(String(format: "%.1f %@", latest, subtitle))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.wtlSecondary)
            }

            SparklineView(data: data, color: color, height: 34)
        }
        .padding(10)
        .background(Color.wtlCard)
        .cornerRadius(8)
    }
}

private struct TimelineEventRow: View {
    let event: TimelineEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Self.timestampFormatter.string(from: event.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.wtlTertiary)

                Spacer()

                Text(event.category.rawValue.uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.wtlSecondary)

                Text(event.severity.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(event.severity.badgeColor)
                    .cornerRadius(4)
            }

            Text(event.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.wtlPrimary)

            Text(event.message)
                .font(.system(size: 10))
                .foregroundColor(Color.wtlSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.wtlCard)
        .cornerRadius(8)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d HH:mm:ss"
        return formatter
    }()
}

private extension TimelineSeverity {
    var badgeColor: Color {
        switch self {
        case .info: return Color.wtlTertiary
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
