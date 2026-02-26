import SwiftUI

struct DashboardView: View {
    let monitors: MonitorCoordinator
    @State private var selectedTab = 0
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("WhatTheLoad")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("uptime \(monitors.systemUptime)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingSettings) {
                    SettingsView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Tab strip
            HStack(spacing: 12) {
                TabButton(icon: "cpu", isSelected: selectedTab == 0) { selectedTab = 0 }
                TabButton(icon: "memorychip", isSelected: selectedTab == 1) { selectedTab = 1 }
                TabButton(icon: "arrow.up.arrow.down", isSelected: selectedTab == 2) { selectedTab = 2 }
                TabButton(icon: "wifi", isSelected: selectedTab == 3) { selectedTab = 3 }
                TabButton(icon: "internaldrive", isSelected: selectedTab == 4) { selectedTab = 4 }
                TabButton(icon: "list.bullet", isSelected: selectedTab == 5) { selectedTab = 5 }
                TabButton(icon: "battery.100", isSelected: selectedTab == 6) { selectedTab = 6 }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content area
            ScrollView {
                Group {
                    switch selectedTab {
                    case 0: CPUSectionView(monitor: monitors.cpu)
                    case 1: MemorySectionView(monitor: monitors.memory, processMonitor: monitors.processes)
                    case 2: NetworkSectionView(monitor: monitors.network)
                    case 3: WiFiSectionView(monitor: monitors.wifi)
                    case 4: DiskSectionView(monitor: monitors.disk)
                    case 5: ProcessesSectionView(monitor: monitors.processes)
                    case 6: BatterySectionView(monitor: monitors.battery)
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            }

            Divider()

            // Footer
            Text(footerStatusText)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .frame(width: 360, height: 520)
        .background(Color.wtlBackground)
        .preferredColorScheme(.dark)
    }

    private var footerStatusText: String {
        guard let latest = latestSampleTimestamp else {
            return "Waiting for samples"
        }

        let age = max(0, Int(Date().timeIntervalSince(latest)))
        if age < 2 { return "Updated just now" }
        if age < 60 { return "Updated \(age)s ago" }

        let minutes = age / 60
        if minutes < 60 { return "Updated \(minutes)m ago" }

        let hours = minutes / 60
        return "Updated \(hours)h ago"
    }

    private var latestSampleTimestamp: Date? {
        [
            monitors.cpu.current?.timestamp,
            monitors.memory.current?.timestamp,
            monitors.network.current?.timestamp,
            monitors.wifi.current?.timestamp,
            monitors.disk.current?.timestamp,
            monitors.processes.current?.timestamp,
            monitors.battery.current?.timestamp
        ]
        .compactMap { $0 }
        .max()
    }
}

struct TabButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .blue : .secondary)
                .frame(width: 40, height: 32)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
