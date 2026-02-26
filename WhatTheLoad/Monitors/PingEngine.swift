import Foundation
import Network

class PingEngine {
    private var connection: NWConnection?
    private let host: String
    private let port: UInt16
    private let queue = DispatchQueue(label: "wtl.pingengine", qos: .background)
    private var isRunning = false
    private var reconnectScheduled = false

    private var measurements: [Double] = []
    private let maxSamples = 30
    private var attempts = 0
    private var failures = 0

    var currentPing: Double? {
        measurements.last
    }

    var averagePing: Double? {
        guard !measurements.isEmpty else { return nil }
        return measurements.reduce(0, +) / Double(measurements.count)
    }

    var jitter: Double? {
        guard measurements.count > 1 else { return nil }

        var deltas: [Double] = []
        for i in 1..<measurements.count {
            deltas.append(abs(measurements[i] - measurements[i-1]))
        }

        return deltas.reduce(0, +) / Double(deltas.count)
    }

    var packetLoss: Double = 0

    init(host: String, port: UInt16 = 80) {
        self.host = host
        self.port = port
    }

    func start() {
        isRunning = true
        reconnectScheduled = false
        startConnection()
    }

    func stop() {
        isRunning = false
        reconnectScheduled = false
        connection?.cancel()
        connection = nil
    }

    private func startConnection() {
        guard isRunning else { return }

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        let newConnection = NWConnection(to: endpoint, using: .tcp)
        connection = newConnection

        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            guard let self, let connection = newConnection else { return }

            switch state {
            case .ready:
                self.sendPing(on: connection)
            case .failed:
                self.recordFailure()
                self.scheduleReconnect()
            case .cancelled:
                break
            default:
                break
            }
        }

        newConnection.start(queue: queue)
    }

    private func sendPing(on connection: NWConnection) {
        let start = Date()
        attempts += 1

        connection.send(content: Data([0x00]), completion: .contentProcessed { [weak self, weak connection] error in
            guard let self else { return }
            let latency = Date().timeIntervalSince(start) * 1000 // ms

            if error == nil {
                self.recordSuccess(latency: latency)
            } else {
                self.recordFailure()
            }

            connection?.cancel()
            self.scheduleReconnect()
        })
    }

    private func scheduleReconnect() {
        guard isRunning, !reconnectScheduled else { return }
        reconnectScheduled = true

        queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.reconnectScheduled = false
            guard self.isRunning else { return }
            self.connection?.cancel()
            self.connection = nil
            self.startConnection()
        }
    }

    private func recordSuccess(latency: Double) {
        measurements.append(latency)
        if measurements.count > maxSamples {
            measurements.removeFirst()
        }

        // Decay packet loss after successful samples
        packetLoss = calculatedPacketLoss()
    }

    private func recordFailure() {
        failures += 1
        packetLoss = calculatedPacketLoss()
    }

    private func calculatedPacketLoss() -> Double {
        guard attempts > 0 else { return 0 }
        return min(max((Double(failures) / Double(attempts)) * 100.0, 0), 100)
    }
}
