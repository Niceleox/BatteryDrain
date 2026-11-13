import Foundation
import UIKit

@MainActor
final class DrainController: ObservableObject {
    @Published var isRunning = false
    @Published var batteryLevel: Float = UIDevice.current.batteryLevel
    @Published var targetBatteryPercent = 10.0
    @Published var thermalState = ProcessInfo.processInfo.thermalState
    @Published var cpuWorkerCount = 0
    @Published private var lastReason = "Ready"

    let targetFrameRate = 120

    private var monitorTimer: Timer?
    private var workers: [Task<Void, Never>] = []

    var batteryText: String {
        guard batteryLevel >= 0 else { return "--" }
        return "\(Int((batteryLevel * 100).rounded()))%"
    }

    var thermalText: String {
        switch thermalState {
        case .nominal:
            return "OK"
        case .fair:
            return "Warm"
        case .serious:
            return "Limit"
        case .critical:
            return "Stop"
        @unknown default:
            return "Unknown"
        }
    }

    var statusText: String {
        if isRunning {
            if thermalState == .serious {
                return "Running, CPU throttled by heat"
            }
            return "Running GPU particles + CPU work"
        }
        return lastReason
    }

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshDeviceState()
    }

    deinit {
        monitorTimer?.invalidate()
        workers.forEach { $0.cancel() }
    }

    func start() {
        refreshDeviceState()

        guard !isRunning else { return }
        guard thermalState != .critical else {
            lastReason = "Too hot to start"
            return
        }

        if batteryLevel >= 0, Double(batteryLevel * 100) <= targetBatteryPercent {
            lastReason = "Already below target"
            return
        }

        isRunning = true
        lastReason = "Running"
        UIApplication.shared.isIdleTimerDisabled = true
        startWorkers()
        startMonitoring()
    }

    func stop(reason: String = "Stopped") {
        guard isRunning || !workers.isEmpty || monitorTimer != nil else {
            lastReason = reason
            return
        }

        isRunning = false
        lastReason = reason
        UIApplication.shared.isIdleTimerDisabled = false
        monitorTimer?.invalidate()
        monitorTimer = nil
        workers.forEach { $0.cancel() }
        workers.removeAll()
        cpuWorkerCount = 0
        refreshDeviceState()
    }

    func refreshDeviceState() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        thermalState = ProcessInfo.processInfo.thermalState
    }

    private func startWorkers() {
        workers = (0..<3).map { _ in
            Task.detached(priority: .userInitiated) {
                await Self.runCPUWorker()
            }
        }
        cpuWorkerCount = workers.count
    }

    private func startMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.monitorTick()
            }
        }
    }

    private func monitorTick() {
        refreshDeviceState()

        if thermalState == .critical {
            stop(reason: "Stopped: too hot")
            return
        }

        guard batteryLevel >= 0 else { return }

        let percent = Double(batteryLevel * 100)
        if percent <= targetBatteryPercent {
            stop(reason: "Target reached")
        }
    }

    nonisolated(unsafe) private static var cpuSink = 0.0

    private nonisolated static func runCPUWorker() async {
        var value = 0.731

        while !Task.isCancelled {
            for index in 0..<90_000 {
                let input = Double(index) + value
                value = sin(input) + cos(value + abs(input).squareRoot()) * atan(input.remainder(dividingBy: 97))
            }

            cpuSink = value

            if ProcessInfo.processInfo.thermalState == .serious {
                try? await Task.sleep(nanoseconds: 45_000_000)
            }
        }
    }
}
