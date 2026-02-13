import Foundation
import Network

class PingEngine {
    private var connection: NWConnection?
    private let host: String
    private let port: UInt16

    private var measurements: [Double] = []
    private let maxSamples = 30

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
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        connection = NWConnection(to: endpoint, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.sendPing()
            case .failed:
                self?.recordFailure()
            default:
                break
            }
        }

        connection?.start(queue: .global(qos: .background))
    }

    func stop() {
        connection?.cancel()
        connection = nil
    }

    private func sendPing() {
        let start = Date()

        connection?.send(content: Data([0x00]), completion: .contentProcessed { [weak self] error in
            let latency = Date().timeIntervalSince(start) * 1000 // ms

            if error == nil {
                self?.recordSuccess(latency: latency)
            } else {
                self?.recordFailure()
            }

            // Schedule next ping
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
                self?.sendPing()
            }
        })
    }

    private func recordSuccess(latency: Double) {
        measurements.append(latency)
        if measurements.count > maxSamples {
            measurements.removeFirst()
        }
    }

    private func recordFailure() {
        // Increase packet loss counter
        packetLoss = min(packetLoss + 1.0, 100.0)
    }
}
