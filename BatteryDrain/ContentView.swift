import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = DrainController()

    var body: some View {
        ZStack {
            MetalParticleView(isRunning: controller.isRunning, preferredFrameRate: controller.targetFrameRate)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.88), .black.opacity(0.5), .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Text("Battery")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(controller.batteryText)
                        .font(.system(size: 74, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                    Text(controller.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .frame(minHeight: 38)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    HStack {
                        Label("Target", systemImage: "battery.25")
                        Spacer()
                        Text("\(Int(controller.targetBatteryPercent))%")
                            .monospacedDigit()
                    }

                    Slider(value: $controller.targetBatteryPercent, in: 5...50, step: 5)
                        .disabled(controller.isRunning)
                }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 12) {
                    MetricView(title: "FPS", value: "\(controller.targetFrameRate)")
                    MetricView(title: "CPU", value: "\(controller.cpuWorkerCount)")
                    MetricView(title: "Heat", value: controller.thermalText)
                }

                Button {
                    controller.isRunning ? controller.stop() : controller.start()
                } label: {
                    Label(controller.isRunning ? "Stop" : "Start", systemImage: controller.isRunning ? "stop.fill" : "play.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(controller.isRunning ? .red : .green)
            }
            .padding(22)
        }
        .foregroundStyle(.white)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                controller.stop(reason: "Paused")
            }
        }
        .onAppear {
            controller.refreshDeviceState()
        }
    }
}

private struct MetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ContentView()
}
