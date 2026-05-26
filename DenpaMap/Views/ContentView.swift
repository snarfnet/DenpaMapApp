import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = MeasurementViewModel()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showStats = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                mapView
                overlayUI
            }

            BannerAdView()
                .frame(height: 50)
                .background(Color.black)
        }
        .onAppear {
            viewModel.requestLocationPermission()
        }
        .sheet(isPresented: $showStats) {
            StatsView(viewModel: viewModel)
        }
    }

    private var mapView: some View {
        Map(position: $position) {
            UserAnnotation()

            ForEach(viewModel.measurements) { m in
                Annotation("", coordinate: m.coordinate) {
                    Circle()
                        .fill(qualityColor(m.quality))
                        .frame(width: 18, height: 18)
                        .opacity(0.8)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
    }

    private var overlayUI: some View {
        VStack {
            // Top bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("電波マップ")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                    Text("Signal Map")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Button {
                    showStats = true
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Legend
            legendView

            // Typewriter log
            if viewModel.isScanning {
                typewriterLog
            }

            // Live stats panel
            if viewModel.isScanning {
                livePanel
            }

            // Bottom controls
            bottomControls
        }
    }

    private var livePanel: some View {
        HStack(spacing: 16) {
            statBox(
                icon: "antenna.radiowaves.left.and.right",
                label: viewModel.currentNetworkType,
                color: .blue
            )
            statBox(
                icon: "timer",
                label: String(format: "%.0fms", viewModel.currentLatency),
                color: latencyColor(viewModel.currentLatency)
            )
            statBox(
                icon: "arrow.down.circle",
                label: String(format: "%.1f Mbps", viewModel.currentSpeed),
                color: speedColor(viewModel.currentSpeed)
            )
            statBox(
                icon: "mappin.circle",
                label: "\(viewModel.scanCount)",
                color: .white
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
    }

    private func statBox(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomControls: some View {
        HStack(spacing: 16) {
            // Clear button
            Button {
                viewModel.clearMeasurements()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.red.opacity(0.7)))
            }

            // Scan button
            Button {
                if viewModel.isScanning {
                    viewModel.stopScanning()
                } else {
                    viewModel.startScanning()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isScanning ? "stop.fill" : "wave.3.right")
                        .font(.system(size: 18))
                    Text(viewModel.isScanning ? "停止" : "計測開始")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule().fill(viewModel.isScanning ? Color.orange : Color.blue)
                )
            }

            // Center button
            Button {
                position = .userLocation(fallback: .automatic)
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.blue.opacity(0.7)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var legendView: some View {
        HStack(spacing: 8) {
            Text("電波品質:")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            legendDot(.green, "最高")
            legendDot(Color(red: 0.4, green: 0.8, blue: 0.2), "良好")
            legendDot(.yellow, "普通")
            legendDot(.orange, "弱い")
            legendDot(.red, "圏外")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
        .padding(.horizontal, 16)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private var typewriterLog: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(viewModel.scanLog.suffix(4).enumerated()), id: \.offset) { idx, line in
                Text(line)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.green.opacity(1.0 - Double(viewModel.scanLog.suffix(4).count - 1 - idx) * 0.2))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.75)))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Colors

    private func qualityColor(_ quality: SignalQuality) -> Color {
        switch quality {
        case .excellent: return .green
        case .good: return Color(red: 0.4, green: 0.8, blue: 0.2)
        case .fair: return .yellow
        case .poor: return .orange
        case .dead: return .red
        }
    }

    private func latencyColor(_ ms: Double) -> Color {
        if ms < 50 { return .green }
        if ms < 100 { return .yellow }
        if ms < 200 { return .orange }
        return .red
    }

    private func speedColor(_ mbps: Double) -> Color {
        if mbps > 50 { return .green }
        if mbps > 15 { return .yellow }
        if mbps > 5 { return .orange }
        return .red
    }
}
