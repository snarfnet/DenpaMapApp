import SwiftUI
import MapKit

@MainActor
class MeasurementViewModel: ObservableObject {
    @Published var measurements: [SignalMeasurement] = []
    @Published var isScanning: Bool = false
    @Published var currentLatency: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var currentNetworkType: String = "---"
    @Published var scanCount: Int = 0
    @Published var scanLog: [String] = []

    let locationManager = LocationManager()
    private let networkMeasurer = NetworkMeasurer()
    private var scanTask: Task<Void, Never>?
    private let storageKey = "denpamap_measurements"

    init() {
        loadMeasurements()
    }

    func requestLocationPermission() {
        locationManager.requestPermission()
    }

    func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        scanLog.removeAll()
        locationManager.startUpdating()

        scanTask = Task {
            while !Task.isCancelled && isScanning {
                await performMeasurement()
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            }
        }
    }

    func stopScanning() {
        isScanning = false
        scanTask?.cancel()
        scanTask = nil
        saveMeasurements()
    }

    func clearMeasurements() {
        measurements.removeAll()
        scanCount = 0
        saveMeasurements()
    }

    func clearSession() {
        measurements.removeAll()
        scanCount = 0
    }

    private func performMeasurement() async {
        guard let coord = locationManager.currentLocation else { return }

        let result = await networkMeasurer.measure()

        let measurement = SignalMeasurement(
            coordinate: coord,
            latencyMs: result.latencyMs,
            downloadSpeedMbps: result.speedMbps,
            networkType: networkMeasurer.currentNetworkType,
            ssid: networkMeasurer.getSSID()
        )

        measurements.append(measurement)
        currentLatency = result.latencyMs
        currentSpeed = result.speedMbps
        currentNetworkType = networkMeasurer.currentNetworkType
        scanCount += 1

        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let q = measurement.quality
        let label: String = switch q {
        case .excellent: "EXCELLENT"
        case .good: "GOOD"
        case .fair: "FAIR"
        case .poor: "POOR"
        case .dead: "DEAD"
        }
        let line = "[\(ts)] \(networkMeasurer.currentNetworkType) \(String(format: "%.0fms", result.latencyMs)) \(String(format: "%.1fMbps", result.speedMbps)) [\(label)]"
        scanLog.append(line)
    }

    // MARK: - Stats

    var averageLatency: Double {
        guard !measurements.isEmpty else { return 0 }
        return measurements.map(\.latencyMs).reduce(0, +) / Double(measurements.count)
    }

    var averageSpeed: Double {
        guard !measurements.isEmpty else { return 0 }
        return measurements.map(\.downloadSpeedMbps).reduce(0, +) / Double(measurements.count)
    }

    var worstSpot: SignalMeasurement? {
        measurements.max(by: { $0.latencyMs < $1.latencyMs })
    }

    var bestSpot: SignalMeasurement? {
        measurements.min(by: { $0.latencyMs < $1.latencyMs })
    }

    var qualityDistribution: [SignalQuality: Int] {
        var dist: [SignalQuality: Int] = [:]
        for m in measurements {
            dist[m.quality, default: 0] += 1
        }
        return dist
    }

    // MARK: - Persistence

    private func saveMeasurements() {
        if let data = try? JSONEncoder().encode(measurements) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadMeasurements() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([SignalMeasurement].self, from: data) else { return }
        measurements = saved
        scanCount = saved.count
    }
}
