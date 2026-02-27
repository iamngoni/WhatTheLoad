import Foundation
import AppKit
import UniformTypeIdentifiers

enum DiagnosticsExporter {
    static func export(
        monitors: MonitorCoordinator,
        historyStore: HistoryStore,
        settings: AppSettings = .shared
    ) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Diagnostics Bundle"
        savePanel.nameFieldStringValue = "WhatTheLoad-Diagnostics-\(timestampForFilename()).zip"
        savePanel.allowedContentTypes = [.zip]
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        let fileManager = FileManager.default
        let workingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("WhatTheLoad-Diagnostics-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

            try writeJSONObject(buildSnapshot(monitors: monitors), to: workingDirectory.appendingPathComponent("snapshot.json"))
            try writeJSON(Array(historyStore.events.prefix(1000)), to: workingDirectory.appendingPathComponent("timeline_events.json"))
            try writeJSON(Array(historyStore.snapshots.prefix(10080)), to: workingDirectory.appendingPathComponent("metric_snapshots.json"))
            try writeJSON(buildProcessTop(monitors: monitors), to: workingDirectory.appendingPathComponent("process_top.json"))
            try writeJSONObject(buildNetworkDiagnostics(monitors: monitors), to: workingDirectory.appendingPathComponent("network_diagnostics.json"))
            try writeReadme(to: workingDirectory.appendingPathComponent("README.txt"))

            try zipDirectory(workingDirectory, outputURL: destinationURL)
            settings.lastDiagnosticsExportStatus = "Exported: \(destinationURL.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
        } catch {
            settings.lastDiagnosticsExportStatus = "Export failed: \(error.localizedDescription)"
        }

        try? fileManager.removeItem(at: workingDirectory)
    }

    private static func buildSnapshot(monitors: MonitorCoordinator) -> [String: Any] {
        let cpu = monitors.cpu.current
        let memory = monitors.memory.current
        let network = monitors.network.current
        let wifi = monitors.wifi.current
        let disk = monitors.disk.current
        let battery = monitors.battery.current

        return [
            "exportedAt": isoString(Date()),
            "powerSaveMode": monitors.isPowerSaveMode,
            "cpu": [
                "usage": cpu?.totalUsage as Any,
                "temperature": cpu?.temperature as Any,
                "frequency": cpu?.frequency as Any,
                "isThrottled": cpu?.isThrottled as Any,
                "perCoreUsage": cpu?.perCoreUsage as Any
            ],
            "memory": [
                "used": memory?.used as Any,
                "wired": memory?.wired as Any,
                "compressed": memory?.compressed as Any,
                "free": memory?.free as Any,
                "pressure": memory?.pressure.description as Any,
                "swapUsed": memory?.swapUsed as Any,
                "swapTotal": memory?.swapTotal as Any,
                "total": memory?.total as Any
            ],
            "network": [
                "download": network?.downloadSpeed as Any,
                "upload": network?.uploadSpeed as Any,
                "interface": network?.interfaceName as Any,
                "localIP": network?.localIP as Any,
                "activeConnections": network?.activeConnections as Any
            ],
            "wifi": [
                "ssid": wifi?.ssid as Any,
                "routerIP": wifi?.routerIP as Any,
                "band": wifi?.band?.description as Any,
                "signal": wifi?.signalStrength as Any,
                "noise": wifi?.noiseFloor as Any,
                "routerPing": wifi?.routerPing as Any,
                "internetPing": wifi?.internetPing as Any,
                "routerLoss": wifi?.routerPacketLoss as Any,
                "internetLoss": wifi?.internetPacketLoss as Any,
                "dnsLookupTime": wifi?.dnsLookupTime as Any
            ],
            "disk": [
                "readSpeed": disk?.readSpeed as Any,
                "writeSpeed": disk?.writeSpeed as Any,
                "volumes": disk?.volumes.map { volume in
                    [
                        "name": volume.name,
                        "path": volume.path,
                        "total": volume.total,
                        "used": volume.used,
                        "free": volume.free
                    ]
                } as Any
            ],
            "battery": [
                "chargePercent": battery?.chargePercent as Any,
                "isCharging": battery?.isCharging as Any,
                "powerSource": batteryPowerSourceString(battery?.powerSource) as Any,
                "timeRemaining": battery?.timeRemaining as Any,
                "health": battery?.health as Any,
                "cycleCount": battery?.cycleCount as Any,
                "temperature": battery?.temperature as Any
            ]
        ]
    }

    private static func buildNetworkDiagnostics(monitors: MonitorCoordinator) -> [String: Any] {
        let wifi = monitors.wifi.current
        let incident = NetworkIncidentAnalyzer.detect(from: wifi)

        return [
            "exportedAt": isoString(Date()),
            "incident": [
                "type": incident?.type.rawValue as Any,
                "title": incident?.title as Any,
                "hint": incident?.hint as Any
            ],
            "localIP": monitors.network.current?.localIP as Any,
            "interfaceName": monitors.network.current?.interfaceName as Any,
            "routerIP": wifi?.routerIP as Any,
            "dnsServer": wifi?.dnsServer as Any,
            "routerPing": wifi?.routerPing as Any,
            "internetPing": wifi?.internetPing as Any,
            "routerLoss": wifi?.routerPacketLoss as Any,
            "internetLoss": wifi?.internetPacketLoss as Any,
            "dnsLookupTime": wifi?.dnsLookupTime as Any
        ]
    }

    private static func buildProcessTop(monitors: MonitorCoordinator) -> [ProcessExportEntry] {
        Array(monitors.processes.current?.processes.prefix(80) ?? []).map {
            ProcessExportEntry(
                pid: $0.id,
                name: $0.name,
                executablePath: $0.executablePath,
                cpuUsage: $0.cpuUsage,
                memoryUsage: $0.memoryUsage
            )
        }
    }

    private static func writeReadme(to url: URL) throws {
        let text = """
        WhatTheLoad Diagnostics Bundle
        Generated: \(ISO8601DateFormatter().string(from: Date()))

        Files:
        - snapshot.json: current monitor values
        - timeline_events.json: recent timeline events
        - metric_snapshots.json: recent periodic snapshots
        - process_top.json: top processes at export time
        - network_diagnostics.json: route, DNS, and incident diagnostics
        """
        try text.data(using: .utf8)?.write(to: url)
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private static func writeJSONObject(_ object: [String: Any], to url: URL) throws {
        let sanitized = sanitizeJSONObject(object)
        let data = try JSONSerialization.data(withJSONObject: sanitized, options: [.prettyPrinted])
        try data.write(to: url, options: .atomic)
    }

    private static func sanitizeJSONObject(_ object: Any) -> Any {
        let mirror = Mirror(reflecting: object)
        if mirror.displayStyle == .optional {
            guard let first = mirror.children.first else { return NSNull() }
            return sanitizeJSONObject(first.value)
        }

        switch object {
        case let dictionary as [String: Any]:
            var sanitized: [String: Any] = [:]
            for (key, value) in dictionary {
                let sanitizedValue = sanitizeJSONObject(value)
                if !(sanitizedValue is NSNull) {
                    sanitized[key] = sanitizedValue
                }
            }
            return sanitized

        case let array as [Any]:
            return array.map { sanitizeJSONObject($0) }

        case let value as NSNumber:
            return value

        case let value as String:
            return value

        case let value as Bool:
            return value

        case let value as Date:
            return isoString(value)

        default:
            return NSNull()
        }
    }

    private static func zipDirectory(_ directory: URL, outputURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory
        process.arguments = ["-r", outputURL.path, "."]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "WhatTheLoad.DiagnosticsExporter", code: Int(process.terminationStatus))
        }
    }

    private static func batteryPowerSourceString(_ source: PowerSource?) -> String? {
        guard let source else { return nil }
        switch source {
        case .battery: return "battery"
        case .ac: return "ac"
        case .unknown: return "unknown"
        }
    }

    private static func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func timestampForFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

private struct ProcessExportEntry: Encodable {
    let pid: Int32
    let name: String
    let executablePath: String
    let cpuUsage: Double
    let memoryUsage: UInt64
}
