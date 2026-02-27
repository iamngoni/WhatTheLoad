import SwiftUI
import AppKit

struct ProcessesSectionView: View {
    let monitor: ProcessMonitor

    @State private var sortColumn: SortColumn = .cpu
    @State private var searchText = ""
    @State private var selectedProcessID: Int32?
    @State private var inspectorSnapshot: ProcessInspectorSnapshot?
    @State private var isInspectingSelectedProcess = false
    @State private var pendingSignalAction: PendingSignalAction?

    enum SortColumn {
        case name, pid, cpu, memory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROCESSES")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlSecondary)
                .tracking(0.5)

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

            HStack(spacing: 8) {
                sortableHeader("Name", width: 118, column: .name, alignment: .leading)
                sortableHeader("PID", width: 44, column: .pid, alignment: .leading)
                sortableHeader("CPU %", width: 54, column: .cpu, alignment: .trailing)
                sortableHeader("Memory", width: 66, column: .memory, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(Color.wtlTertiary)
            .padding(.horizontal, 8)

            Divider()

            if let current = monitor.current {
                ScrollView {
                    ForEach(filteredProcesses(current.processes), id: \.id) { process in
                        ProcessRow(process: process, isSelected: process.id == selectedProcessID)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedProcessID = process.id
                                inspectProcess(process)
                            }
                            .contextMenu {
                                Button("Reveal in Finder") {
                                    revealProcessInFinder(process)
                                }
                                Divider()
                                Button("Quit") {
                                    scheduleSignalAction(for: process, signal: SIGTERM)
                                }
                                Button("Force Quit") {
                                    scheduleSignalAction(for: process, signal: SIGKILL)
                                }
                            }
                    }
                }
                .frame(height: 210)

                detailPanel(for: current)
            }
        }
        .onChange(of: monitor.current?.timestamp) { _, _ in
            refreshSelectionIfNeeded()
        }
        .alert(item: $pendingSignalAction) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .destructive(Text(action.confirmTitle)) {
                    kill(action.process.id, action.signal)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func sortableHeader(_ title: String, width: CGFloat, column: SortColumn, alignment: Alignment) -> some View {
        Button {
            sortColumn = column
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if sortColumn == column {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 7))
                }
            }
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
        .foregroundColor(sortColumn == column ? Color.wtlSecondary : Color.wtlTertiary)
    }

    @ViewBuilder
    private func detailPanel(for metrics: ProcessMetrics) -> some View {
        let selected = metrics.processes.first { $0.id == selectedProcessID }

        VStack(alignment: .leading, spacing: 10) {
            Text("PROCESS DETAILS")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlTertiary)
                .tracking(0.5)

            if let selected {
                HStack {
                    Text(selected.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text("PID \(selected.id)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.wtlSecondary)
                }

                Text(abbreviatedPath(selected.executablePath))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.wtlTertiary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CPU TREND")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.wtlTertiary)
                        SparklineView(data: cpuTrend(for: selected.id), color: .orange, height: 34)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MEM TREND")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.wtlTertiary)
                        SparklineView(data: memoryTrend(for: selected.id), color: .blue, height: 34)
                    }
                }

                HStack(spacing: 14) {
                    StatInline(label: "CPU", value: String(format: "%.1f%%", selected.cpuUsage))
                    StatInline(label: "Memory", value: formatBytes(selected.memoryUsage))
                    StatInline(label: "Open Files", value: inspectorValue { "\($0.openFiles)" })
                    StatInline(label: "Sockets", value: inspectorValue { "\($0.sockets)" })
                }

                HStack(spacing: 8) {
                    Button("Reveal") {
                        revealProcessInFinder(selected)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Quit") {
                        scheduleSignalAction(for: selected, signal: SIGTERM)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Force Quit", role: .destructive) {
                        scheduleSignalAction(for: selected, signal: SIGKILL)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    if isInspectingSelectedProcess {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } else {
                Text("Select a process to inspect path, open files, and socket usage.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.wtlSecondary)
            }
        }
        .padding(10)
        .background(Color.wtlCard)
        .cornerRadius(8)
    }

    private func filteredProcesses(_ processes: [ProcessDetails]) -> [ProcessDetails] {
        let filtered = searchText.isEmpty ? processes : processes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }

        return filtered.sorted { p1, p2 in
            switch sortColumn {
            case .name: return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
            case .pid: return p1.id < p2.id
            case .cpu: return p1.cpuUsage > p2.cpuUsage
            case .memory: return p1.memoryUsage > p2.memoryUsage
            }
        }
    }

    private func cpuTrend(for pid: Int32) -> [Double] {
        monitor.history.map { sample in
            sample.processes.first(where: { $0.id == pid })?.cpuUsage ?? 0
        }
    }

    private func memoryTrend(for pid: Int32) -> [Double] {
        monitor.history.map { sample in
            Double(sample.processes.first(where: { $0.id == pid })?.memoryUsage ?? 0) / 1_048_576
        }
    }

    private func inspectProcess(_ process: ProcessDetails) {
        isInspectingSelectedProcess = true
        inspectorSnapshot = nil

        let pid = process.id
        DispatchQueue.global(qos: .utility).async {
            let output = runCommand("/usr/sbin/lsof", arguments: ["-n", "-P", "-p", "\(pid)"]) ?? ""
            let lines = output.split(whereSeparator: \.isNewline)
            let rows = lines.dropFirst()

            let openFiles = rows.count
            let sockets = rows.filter { line in
                line.contains("TCP") || line.contains("UDP") || line.contains("IPv4") || line.contains("IPv6")
            }.count

            let snapshot = ProcessInspectorSnapshot(openFiles: openFiles, sockets: sockets, inspectedAt: Date())

            DispatchQueue.main.async {
                guard selectedProcessID == pid else { return }
                inspectorSnapshot = snapshot
                isInspectingSelectedProcess = false
            }
        }
    }

    private func refreshSelectionIfNeeded() {
        guard let selectedProcessID else { return }
        guard let selected = monitor.current?.processes.first(where: { $0.id == selectedProcessID }) else {
            self.selectedProcessID = nil
            inspectorSnapshot = nil
            return
        }

        if !isInspectingSelectedProcess {
            inspectProcess(selected)
        }
    }

    private func scheduleSignalAction(for process: ProcessDetails, signal: Int32) {
        let (title, message, confirmTitle): (String, String, String)
        if signal == SIGKILL {
            title = "Force Quit Process?"
            message = "Force quit \(process.name) (PID \(process.id)) immediately?"
            confirmTitle = "Force Quit"
        } else {
            title = "Quit Process?"
            message = "Send a quit signal to \(process.name) (PID \(process.id))?"
            confirmTitle = "Quit"
        }

        pendingSignalAction = PendingSignalAction(
            process: process,
            signal: signal,
            title: title,
            message: message,
            confirmTitle: confirmTitle
        )
    }

    private func revealProcessInFinder(_ process: ProcessDetails) {
        let url = URL(fileURLWithPath: process.executablePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    private func inspectorValue(_ value: (ProcessInspectorSnapshot) -> String) -> String {
        if let snapshot = inspectorSnapshot {
            return value(snapshot)
        }
        return isInspectingSelectedProcess ? "..." : "-"
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useMB, .useGB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

private struct ProcessRow: View {
    let process: ProcessDetails
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(process.name)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 118, alignment: .leading)

            Text("\(process.id)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)

            Text(String(format: "%.1f", process.cpuUsage))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(colorForCPU(process.cpuUsage))
                .frame(width: 54, alignment: .trailing)

            Text(formatBytes(process.memoryUsage))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 66, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.18) : Color.wtlCard.opacity(0.3))
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

private struct StatInline: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlTertiary)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.wtlSecondary)
        }
    }
}

private struct ProcessInspectorSnapshot {
    let openFiles: Int
    let sockets: Int
    let inspectedAt: Date
}

private struct PendingSignalAction: Identifiable {
    let id = UUID()
    let process: ProcessDetails
    let signal: Int32
    let title: String
    let message: String
    let confirmTitle: String
}

private func runCommand(_ executable: String, arguments: [String]) -> String? {
    let process = Process()
    let pipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = errorPipe

    do {
        try process.run()
    } catch {
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else { return nil }
    return String(data: data, encoding: .utf8)
}
