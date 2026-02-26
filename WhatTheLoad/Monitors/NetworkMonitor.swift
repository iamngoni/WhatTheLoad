import Foundation
import Network

@Observable
class NetworkMonitor {
    var current: NetworkMetrics?
    var history: [NetworkMetrics] = []

    private var timer: Timer?
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var pathMonitor: NWPathMonitor?
    private var cachedActiveConnections = 0
    private var lastConnectionCountRefresh = Date.distantPast

    func start(interval: TimeInterval = 1.0) {
        timer?.invalidate()
        pathMonitor = NWPathMonitor()
        pathMonitor?.start(queue: DispatchQueue.global(qos: .background))

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
        update()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    private func update() {
        guard let metrics = fetchMetrics() else { return }

        current = metrics
        history.append(metrics)

        if history.count > 120 {
            history.removeFirst()
        }
    }

    private func fetchMetrics() -> NetworkMetrics? {
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var interfaceName = "en0"

        if let addrs = getifaddrs_wrapper() {
            var ptr: UnsafeMutablePointer<ifaddrs>? = addrs
            while let current = ptr {
                defer { ptr = current.pointee.ifa_next }

                let interface = current.pointee
                let name = String(cString: interface.ifa_name)

                if name.starts(with: "en"), let data = interface.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    bytesIn += UInt64(networkData.ifi_ibytes)
                    bytesOut += UInt64(networkData.ifi_obytes)
                    interfaceName = name
                }
            }
            freeifaddrs(addrs)
        }

        let uploadSpeed = previousBytesOut > 0 ? Double(bytesOut - previousBytesOut) : 0
        let downloadSpeed = previousBytesIn > 0 ? Double(bytesIn - previousBytesIn) : 0

        previousBytesIn = bytesIn
        previousBytesOut = bytesOut

        return NetworkMetrics(
            timestamp: Date(),
            uploadSpeed: uploadSpeed,
            downloadSpeed: downloadSpeed,
            interfaceName: interfaceName,
            localIP: getLocalIP(),
            publicIP: nil, // Fetched async
            activeConnections: getActiveConnections()
        )
    }

    private func getifaddrs_wrapper() -> UnsafeMutablePointer<ifaddrs>? {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0 else { return nil }
        return addrs
    }

    private func getLocalIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" || name == "en1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }

    private func getActiveConnections() -> Int {
        let now = Date()
        if now.timeIntervalSince(lastConnectionCountRefresh) < 5 {
            return cachedActiveConnections
        }

        lastConnectionCountRefresh = now
        cachedActiveConnections = fetchActiveConnectionsViaNetstat() ?? cachedActiveConnections
        return cachedActiveConnections
    }

    private func fetchActiveConnectionsViaNetstat() -> Int? {
        let tcpOutput = runCommand("/usr/sbin/netstat", arguments: ["-an", "-p", "tcp"]) ?? ""
        let udpOutput = runCommand("/usr/sbin/netstat", arguments: ["-an", "-p", "udp"]) ?? ""

        guard !tcpOutput.isEmpty || !udpOutput.isEmpty else { return nil }

        let tcpCount = tcpOutput
            .split(whereSeparator: \.isNewline)
            .filter { line in
                let text = line.trimmingCharacters(in: .whitespaces)
                guard text.hasPrefix("tcp") else { return false }

                let cols = text.split(whereSeparator: \.isWhitespace)
                guard let state = cols.last.map(String.init) else { return false }
                return state != "LISTEN" && state != "CLOSED"
            }
            .count

        let udpCount = udpOutput
            .split(whereSeparator: \.isNewline)
            .filter { line in
                let text = line.trimmingCharacters(in: .whitespaces)
                return text.hasPrefix("udp")
            }
            .count

        return tcpCount + udpCount
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
}
