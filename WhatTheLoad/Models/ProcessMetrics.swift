import Foundation

struct ProcessMetrics {
    let timestamp: Date
    let processes: [ProcessDetails]
}

struct ProcessDetails: Identifiable {
    let id: Int32 // PID
    let name: String
    let cpuUsage: Double
    let memoryUsage: UInt64
    let state: ProcessState
}

enum ProcessState {
    case running, sleeping, stopped, zombie, unknown
}
