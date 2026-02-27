import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Poll intervals
                    SectionHeader(title: "POLL INTERVALS")

                    SliderRow(title: "CPU", value: $settings.cpuPollInterval, range: 0.5...10, unit: "s")
                    SliderRow(title: "Memory", value: $settings.memoryPollInterval, range: 1...30, unit: "s")
                    SliderRow(title: "Network", value: $settings.networkPollInterval, range: 0.5...10, unit: "s")
                    SliderRow(title: "Wi-Fi", value: $settings.wifiPollInterval, range: 0.5...10, unit: "s")
                    SliderRow(title: "Disk", value: $settings.diskPollInterval, range: 1...60, unit: "s")
                    SliderRow(title: "Processes", value: $settings.processesPollInterval, range: 1...30, unit: "s")
                    SliderRow(title: "Battery", value: $settings.batteryPollInterval, range: 5...120, unit: "s")

                    Divider()
                        .padding(.vertical, 8)

                    // Menu bar customization
                    SectionHeader(title: "MENU BAR")

                    Toggle("Show Sparkline", isOn: $settings.showMenuBarSparkline)
                        .font(.system(size: 12))

                    Toggle("Show Network Speed", isOn: $settings.showMenuBarNetworkText)
                        .font(.system(size: 12))

                    Picker("Sparkline Metric", selection: $settings.menuBarSparklineMetric) {
                        Text("CPU").tag("cpu")
                        Text("Memory").tag("memory")
                        Text("Network").tag("network")
                    }
                    .pickerStyle(.segmented)
                    .font(.system(size: 11))

                    Divider()
                        .padding(.vertical, 8)

                    // Alerts
                    SectionHeader(title: "ALERTS")

                    Toggle("Low Battery Popup", isOn: $settings.lowBatteryAlertsEnabled)
                        .font(.system(size: 12))

                    if settings.lowBatteryAlertsEnabled {
                        SliderRow(title: "Battery Alert Threshold", value: $settings.lowBatteryAlertThreshold, range: 5...50, unit: "%")
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // System
                    SectionHeader(title: "SYSTEM")

                    Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                        .font(.system(size: 12))
                        .onChange(of: settings.launchAtLogin) { _, newValue in
                            toggleLaunchAtLogin(enabled: newValue)
                        }

                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                }
                .padding(16)
            }
        }
        .frame(width: 360, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)
            .tracking(0.5)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)

                Spacer()

                Text(String(format: "%.1f%@", value, unit))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Slider(value: $value, in: range)
        }
    }
}
