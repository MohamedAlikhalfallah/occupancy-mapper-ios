import simd
import Foundation

class UpdateOptimizer {
    
    
    private let minMovementDistance: Float = 0.02
    
    private let minRotationAngle: Float = 0.05
    
    private let minTimeInterval: TimeInterval = 0.03
    
    private var lastPosition: SIMD3<Float>? = nil
    private var lastForward: SIMD3<Float>?  = nil
    private var lastProcessTime: Date       = .distantPast
    
    private(set) var processedFrames: Int = 0
    private(set) var skippedFrames: Int   = 0
    
    
    func shouldProcess(position: SIMD3<Float>,
                       forward: SIMD3<Float>) -> Bool {
        
        let now = Date()
        
        guard now.timeIntervalSince(lastProcessTime) >= minTimeInterval else {
            skippedFrames += 1
            return false
        }
        
        guard let lastPos = lastPosition,
              let lastFwd = lastForward else {
            commit(position: position, forward: forward, time: now)
            return true
        }
        
        let movement = simd_length(position - lastPos)
        let rotation = acos(min(max(simd_dot(forward, lastFwd), -1), 1))
        
        if movement >= minMovementDistance || rotation >= minRotationAngle {
            commit(position: position, forward: forward, time: now)
            return true
        }
        
        skippedFrames += 1
        return false
    }
    
    private func commit(position: SIMD3<Float>,
                        forward: SIMD3<Float>,
                        time: Date) {
        lastPosition    = position
        lastForward     = forward
        lastProcessTime = time
        processedFrames += 1
    }
    
    
    var skipRatio: Double {
        let total = processedFrames + skippedFrames
        guard total > 0 else { return 0 }
        return Double(skippedFrames) / Double(total) * 100.0
    }
    
    func reset() {
        lastPosition    = nil
        lastForward     = nil
        lastProcessTime = .distantPast
        processedFrames = 0
        skippedFrames   = 0
        Logger.info("UpdateOptimizer reset")
    }
}
