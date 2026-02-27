import SwiftUI
import AppKit

struct DiskSectionView: View {
    let monitor: DiskMonitor

    @State private var showingClearCachesConfirmation = false
    @State private var pendingTrashTarget: DiskSpaceConsumer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DISK")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.wtlSecondary)
                .tracking(0.5)

            if let current = monitor.current {
                volumesSection(current)
                throughputSection
            }

            spaceAnalysisSection
        }
        .alert("Clear Library Caches?", isPresented: $showingClearCachesConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                monitor.clearLibraryCaches()
            }
        } message: {
            Text("This removes files inside ~/Library/Caches. Apps may rebuild them later.")
        }
        .alert("Move Item to Trash?", isPresented: Binding(
            get: { pendingTrashTarget != nil },
            set: { isPresented in
                if !isPresented { pendingTrashTarget = nil }
            }
        )) {
            Button("Cancel", role: .cancel) {
                pendingTrashTarget = nil
            }
            Button("Move to Trash", role: .destructive) {
                if let pendingTrashTarget {
                    monitor.moveItemToTrash(pendingTrashTarget)
                }
                pendingTrashTarget = nil
            }
        } message: {
            if let pendingTrashTarget {
                Text("Move \(pendingTrashTarget.name) to Trash?\n\(abbreviatedPath(pendingTrashTarget.path))")
            } else {
                Text("Move selected item to Trash?")
            }
        }
    }

    @ViewBuilder
    private func volumesSection(_ current: DiskMetrics) -> some View {
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
    }

    private var throughputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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

    private var spaceAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SPACE ANALYSIS")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlSecondary)
                    .tracking(0.5)

                Spacer()

                if monitor.isAnalyzingSpace {
                    ProgressView()
                        .controlSize(.small)
                } else if let last = monitor.lastSpaceAnalysisAt {
                    Text(relativeTimestamp(last))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color.wtlTertiary)
                }
            }

            HStack {
                Text("Library/Caches")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)

                Spacer()

                Text(formatBytes(monitor.cacheFolderSize))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.wtlSecondary)
            }

            HStack(spacing: 8) {
                Button("Refresh") {
                    monitor.refreshSpaceAnalysis()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(monitor.isAnalyzingSpace || monitor.isCleaningUpSpace)

                Button("Clear Library Caches", role: .destructive) {
                    showingClearCachesConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(monitor.isCleaningUpSpace)

                if monitor.isCleaningUpSpace {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if !monitor.cleanupCategories.isEmpty {
                Text("CLEANUP CATEGORIES")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlTertiary)
                    .tracking(0.5)
                    .padding(.top, 4)

                ForEach(monitor.cleanupCategories) { category in
                    cleanupCategoryRow(category)
                }

                Text("Only paths inside your home directory are cleaned. Protected system paths are excluded.")
                    .font(.system(size: 9))
                    .foregroundColor(Color.wtlTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let cleanupStatus = monitor.cleanupStatus, !cleanupStatus.isEmpty {
                Text(cleanupStatus)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.wtlSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !monitor.largestConsumers.isEmpty {
                Text("TOP SPACE USERS")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlTertiary)
                    .tracking(0.5)
                    .padding(.top, 2)

                ForEach(monitor.largestConsumers) { consumer in
                    consumerRow(consumer)
                }
            }

            if !monitor.largestCacheEntries.isEmpty {
                Text("LARGEST CACHE SUBFOLDERS")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.wtlTertiary)
                    .tracking(0.5)
                    .padding(.top, 4)

                ForEach(monitor.largestCacheEntries) { consumer in
                    consumerRow(consumer)
                }
            }
        }
        .padding(12)
        .background(Color.wtlCard)
        .cornerRadius(8)
    }

    private func consumerRow(_ consumer: DiskSpaceConsumer) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(consumer.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(abbreviatedPath(consumer.path))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.wtlTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(formatBytes(consumer.size))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.wtlSecondary)

            Button {
                revealInFinder(consumer.path)
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(Color.wtlSecondary)

            Button(role: .destructive) {
                pendingTrashTarget = consumer
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .disabled(monitor.isCleaningUpSpace)
        }
    }

    private func cleanupCategoryRow(_ category: DiskCleanupCategoryStatus) -> some View {
        HStack(spacing: 8) {
            Text(category.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)

            Spacer(minLength: 8)

            Text(formatBytes(category.size))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.wtlSecondary)

            Button("Reveal") {
                monitor.revealCategory(category.key)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(category.paths.isEmpty)

            Button("Clean", role: .destructive) {
                monitor.cleanCategory(category.key)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(category.paths.isEmpty || monitor.isCleaningUpSpace)
        }
    }

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
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

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    private func relativeTimestamp(_ date: Date) -> String {
        let age = max(0, Int(Date().timeIntervalSince(date)))
        if age < 2 { return "just now" }
        if age < 60 { return "\(age)s ago" }

        let minutes = age / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }
}
