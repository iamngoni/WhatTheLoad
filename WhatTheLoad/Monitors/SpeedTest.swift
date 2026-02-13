import Foundation
import Combine

class SpeedTest: ObservableObject {
    @Published var isRunning = false
    @Published var downloadSpeed: Double = 0 // Mbps
    @Published var uploadSpeed: Double = 0 // Mbps
    @Published var progress: Double = 0

    func run() async {
        isRunning = true
        progress = 0

        // Download test
        await testDownload()
        progress = 0.5

        // Upload test
        await testUpload()
        progress = 1.0

        isRunning = false
    }

    private func testDownload() async {
        // Simplified: Download a test file from Cloudflare
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000") else { return }

        let start = Date()
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let duration = Date().timeIntervalSince(start)
            let bytes = Double(data.count)
            let bits = bytes * 8
            let mbps = (bits / duration) / 1_000_000

            await MainActor.run {
                downloadSpeed = mbps
            }
        } catch {
            print("Download test failed: \(error)")
        }
    }

    private func testUpload() async {
        // Simplified: Upload test data to Cloudflare
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Generate 1MB of random data
        let testData = Data(repeating: 0, count: 1_000_000)
        request.httpBody = testData

        let start = Date()
        do {
            let _ = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(start)
            let bytes = Double(testData.count)
            let bits = bytes * 8
            let mbps = (bits / duration) / 1_000_000

            await MainActor.run {
                uploadSpeed = mbps
            }
        } catch {
            print("Upload test failed: \(error)")
        }
    }
}
