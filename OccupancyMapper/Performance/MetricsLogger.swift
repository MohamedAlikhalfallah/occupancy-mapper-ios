import Foundation
import QuartzCore
import UIKit


final class MetricsLogger {

    static let shared = MetricsLogger()

    private let queue = DispatchQueue(label: "com.occupancymapper.metrics")
    private var framesHandle: FileHandle?
    private var timelineHandle: FileHandle?
    private var startTime: CFTimeInterval = 0
    private var frameIndex = 0
    private(set) var currentFolder: URL?
    private var running = false

    private init() {}

    func start(session: String = "run") {
        queue.async {
            guard !self.running else { return }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let stamp = Self.stampFormatter.string(from: Date())
            let folder = docs.appendingPathComponent("EvaluationLogs", isDirectory: true)
                             .appendingPathComponent("\(session)_\(stamp)", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let framesURL   = folder.appendingPathComponent("frames.csv")
            let timelineURL = folder.appendingPathComponent("timeline.csv")
            FileManager.default.createFile(atPath: framesURL.path,   contents: nil)
            FileManager.default.createFile(atPath: timelineURL.path, contents: nil)

            self.framesHandle   = try? FileHandle(forWritingTo: framesURL)
            self.timelineHandle = try? FileHandle(forWritingTo: timelineURL)
            self.write(self.framesHandle,   "frame_index,t_sec,proc_ms\n")
            self.write(self.timelineHandle, "t_sec,ram_mb,grid_kb,resident_tiles,disk_tiles,observed,area_m2,skip_ratio,fps,thermal,battery\n")

            self.startTime  = CACurrentMediaTime()
            self.frameIndex = 0
            self.currentFolder = folder
            self.running = true
            UIDevice.current.isBatteryMonitoringEnabled = true
            Logger.info("Metrics logging to: \(folder.path)")
        }
    }

    func stop() {
        queue.async {
            guard self.running else { return }
            try? self.framesHandle?.close()
            try? self.timelineHandle?.close()
            self.framesHandle = nil
            self.timelineHandle = nil
            self.running = false
            if let f = self.currentFolder { Logger.info("Metrics saved: \(f.path)") }
        }
    }

    func logFrameTime(_ ms: Double) {
        queue.async {
            guard self.running, let h = self.framesHandle else { return }
            let t = CACurrentMediaTime() - self.startTime
            self.frameIndex += 1
            self.write(h, String(format: "%d,%.4f,%.4f\n", self.frameIndex, t, ms))
        }
    }

    func logSnapshot(ramMB: Float,
                     gridBytes: Int,
                     residentTiles: Int,
                     diskTiles: Int,
                     observed: Int,
                     areaM2: Double,
                     skipRatio: Double,
                     fps: Double) {
        queue.async {
            guard self.running, let h = self.timelineHandle else { return }
            let t = CACurrentMediaTime() - self.startTime
            let thermal = Self.thermalString(ProcessInfo.processInfo.thermalState)
            let battery = UIDevice.current.batteryLevel
            let line = String(format: "%.2f,%.1f,%.1f,%d,%d,%d,%.3f,%.1f,%.1f,%@,%.2f\n",
                              t, ramMB, Double(gridBytes) / 1024.0,
                              residentTiles, diskTiles, observed, areaM2,
                              skipRatio, fps, thermal, battery)
            self.write(h, line)
        }
    }

    private func write(_ handle: FileHandle?, _ s: String) {
        guard let h = handle, let d = s.data(using: .utf8) else { return }
        h.write(d)
    }

    private static func thermalString(_ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()
}
