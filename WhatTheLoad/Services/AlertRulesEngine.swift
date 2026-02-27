import Foundation

final class AlertRulesEngine {
    enum Rule: String, CaseIterable {
        case cpuUsageHigh
        case cpuTempHigh
        case memoryPressure
        case packetLoss
        case highJitter
        case lowDisk
        case lowBattery
        case networkIncident
    }

    private let monitors: MonitorCoordinator
    private let historyStore: HistoryStore
    private let settings: AppSettings
    private var timer: Timer?
    private var lastTriggeredAt: [Rule: Date] = [:]
    private var lastIncidentType: NetworkIncidentType?
    private var lastPresentedAlertAt: Date?

    var onAlert: ((TimelineSeverity, String, String) -> Void)?

    init(
        monitors: MonitorCoordinator,
        historyStore: HistoryStore,
        settings: AppSettings = .shared
    ) {
        self.monitors = monitors
        self.historyStore = historyStore
        self.settings = settings
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.evaluateRules()
        }
        evaluateRules()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func evaluateRules() {
        evaluateIncidentState()
        guard settings.alertsEnabled else { return }

        if let cpu = monitors.cpu.current {
            if cpu.totalUsage >= settings.cpuUsageAlertThreshold {
                trigger(
                    .cpuUsageHigh,
                    severity: .warning,
                    title: "High CPU Usage",
                    message: String(format: "CPU usage is %.0f%%.", cpu.totalUsage)
                )
            }

            if let temp = cpu.temperature, temp >= settings.cpuTempAlertThreshold {
                trigger(
                    .cpuTempHigh,
                    severity: .critical,
                    title: "High CPU Temperature",
                    message: String(format: "CPU temperature is %.0f°C.", temp)
                )
            }
        }

        if let memory = monitors.memory.current, memory.pressure == .critical {
            trigger(
                .memoryPressure,
                severity: .critical,
                title: "Critical Memory Pressure",
                message: "Memory pressure is critical. Close heavy apps."
            )
        }

        if let wifi = monitors.wifi.current {
            let packetLoss = max(wifi.routerPacketLoss ?? 0, wifi.internetPacketLoss ?? 0)
            if packetLoss >= settings.packetLossAlertThreshold {
                trigger(
                    .packetLoss,
                    severity: .warning,
                    title: "Packet Loss Detected",
                    message: String(format: "Packet loss is %.1f%%.", packetLoss)
                )
            }

            let jitter = max(wifi.routerJitter ?? 0, wifi.internetJitter ?? 0)
            if jitter >= settings.jitterAlertThreshold {
                trigger(
                    .highJitter,
                    severity: .warning,
                    title: "High Jitter Detected",
                    message: String(format: "Jitter is %.0f ms.", jitter)
                )
            }
        }

        if let firstVolume = monitors.disk.current?.volumes.first {
            let freePercent = firstVolume.total > 0 ? (Double(firstVolume.free) / Double(firstVolume.total) * 100) : 100
            if freePercent <= settings.lowDiskFreePercentThreshold {
                trigger(
                    .lowDisk,
                    severity: .critical,
                    title: "Low Disk Space",
                    message: String(format: "%@ has %.1f%% free space.", firstVolume.name, freePercent)
                )
            }
        }

        if settings.lowBatteryAlertsEnabled,
           let battery = monitors.battery.current,
           battery.powerSource == .battery,
           !battery.isCharging,
           battery.chargePercent <= settings.lowBatteryAlertThreshold {
            trigger(
                .lowBattery,
                severity: .critical,
                title: "Low Battery",
                message: String(format: "Battery is at %.0f%%.", battery.chargePercent)
            )
        }
    }

    private func evaluateIncidentState() {
        let incident = NetworkIncidentAnalyzer.detect(from: monitors.wifi.current)
        let incidentType = incident?.type

        if incidentType != lastIncidentType {
            if let incident {
                historyStore.recordEvent(TimelineEvent(
                    severity: .warning,
                    category: .network,
                    title: incident.title,
                    message: incident.hint
                ))

                trigger(
                    .networkIncident,
                    severity: .warning,
                    title: incident.title,
                    message: incident.hint
                )
            } else if lastIncidentType != nil {
                historyStore.recordEvent(TimelineEvent(
                    severity: .info,
                    category: .network,
                    title: "Network Recovered",
                    message: "Connectivity checks are back to normal."
                ))
            }
            lastIncidentType = incidentType
        }
    }

    private func trigger(
        _ rule: Rule,
        severity: TimelineSeverity,
        title: String,
        message: String
    ) {
        let now = Date()
        let cooldown = settings.alertsCooldownMinutes * 60
        if let last = lastTriggeredAt[rule], now.timeIntervalSince(last) < cooldown {
            return
        }

        lastTriggeredAt[rule] = now
        historyStore.recordEvent(TimelineEvent(
            severity: severity,
            category: category(for: rule),
            title: title,
            message: message
        ))

        guard !isInQuietHours() else { return }

        // Keep a small global spacing between popups from different rules.
        if let lastPresentedAlertAt, now.timeIntervalSince(lastPresentedAlertAt) < 5 {
            return
        }

        lastPresentedAlertAt = now
        onAlert?(severity, title, message)
    }

    private func category(for rule: Rule) -> TimelineCategory {
        switch rule {
        case .cpuUsageHigh, .cpuTempHigh, .memoryPressure:
            return .alert
        case .packetLoss, .highJitter, .networkIncident:
            return .network
        case .lowDisk:
            return .disk
        case .lowBattery:
            return .battery
        }
    }

    private func isInQuietHours() -> Bool {
        guard settings.alertsQuietHoursEnabled else { return false }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let start = Int(settings.alertsQuietHoursStartHour)
        let end = Int(settings.alertsQuietHoursEndHour)

        if start == end {
            return true
        }

        if start < end {
            return hour >= start && hour < end
        }

        // Overnight interval (e.g. 22 -> 7)
        return hour >= start || hour < end
    }
}
