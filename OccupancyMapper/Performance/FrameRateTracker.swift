import Foundation

class FrameRateTracker {
    
    static let shared = FrameRateTracker()
    
    private(set) var currentFPS: Double = 0.0
    private(set) var peakFPS: Double    = 0.0
    private(set) var samples: [Double]  = []
    
    private var lastFrameCount: Int = 0
    private var lastCheck: Date     = Date()
    private let maxSamples = 300
    
    private init() {}
    
    
    @discardableResult
    func update(frameCount: Int) -> Double {
        let now         = Date()
        let elapsed     = now.timeIntervalSince(lastCheck)
        let framesDelta = frameCount - lastFrameCount
        
        lastCheck      = now
        lastFrameCount = frameCount
        
        guard elapsed > 0, framesDelta > 0 else { return currentFPS }
        
        currentFPS = min(Double(framesDelta) / elapsed, 60.0)
        peakFPS    = max(peakFPS, currentFPS)
        
        samples.append(currentFPS)
        if samples.count > maxSamples {
            samples.removeFirst()
        }
        
        return currentFPS
    }
    
    
    var averageFPS: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }
    
    var minFPS: Double {
        samples.min() ?? 0
    }
    
    func reset() {
        samples.removeAll()
        peakFPS        = 0
        lastFrameCount = 0
        lastCheck      = Date()
        Logger.info("FrameRateTracker reset")
    }
    
    
    func exportCSV() -> String {
        var csv = "sample_index,fps\n"
        for (index, value) in samples.enumerated() {
            csv += "\(index),\(value)\n"
        }
        return csv
    }
}
