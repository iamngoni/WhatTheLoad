import SwiftUI

struct ProcessesSectionView: View {
    let monitor: ProcessMonitor
    @State private var sortColumn: SortColumn = .cpu
    @State private var searchText = ""

    enum SortColumn {
        case name, pid, cpu, memory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROCESSES")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlSecondary)
                .tracking(0.5)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Search processes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
            }
            .padding(8)
            .background(Color.wtlCard)
            .cornerRadius(6)

            // Table header
            HStack(spacing: 8) {
                Text("Name")
                    .frame(width: 120, alignment: .leading)
                Text("PID")
                    .frame(width: 50, alignment: .leading)
                Text("CPU %")
                    .frame(width: 50, alignment: .trailing)
                Text("Memory")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(Color.wtlTertiary)
            .padding(.horizontal, 8)

            Divider()

            // Process list
            if let current = monitor.current {
                ScrollView {
                    ForEach(filteredProcesses(current.processes), id: \.id) { process in
                        ProcessRow(process: process)
                            .contextMenu {
                                Button("Kill Process") {
                                    killProcess(process.id)
                                }
                            }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    private func filteredProcesses(_ processes: [ProcessDetails]) -> [ProcessDetails] {
        let filtered = searchText.isEmpty ? processes : processes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }

        return filtered.sorted { p1, p2 in
            switch sortColumn {
            case .name: return p1.name < p2.name
            case .pid: return p1.id < p2.id
            case .cpu: return p1.cpuUsage > p2.cpuUsage
            case .memory: return p1.memoryUsage > p2.memoryUsage
            }
        }
    }

    private func killProcess(_ pid: Int32) {
        kill(pid, SIGTERM)
    }
}

struct ProcessRow: View {
    let process: ProcessDetails

    var body: some View {
        HStack(spacing: 8) {
            Text(process.name)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            Text("\(process.id)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Text(String(format: "%.1f", process.cpuUsage))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(colorForCPU(process.cpuUsage))
                .frame(width: 50, alignment: .trailing)

            Text(formatBytes(process.memoryUsage))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.wtlCard.opacity(0.3))
        .cornerRadius(4)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useMB, .useGB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func colorForCPU(_ usage: Double) -> Color {
        switch usage {
        case 0..<50: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
}
