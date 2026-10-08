import simd

struct SensorMeasurement {
    let position: SIMD3<Float>
    let distance: Float
    let confidence: Float
    
    init(position: SIMD3<Float>, distance: Float, confidence: Float) {
        self.position = position
        self.distance = distance
        self.confidence = confidence
    }
    
    var isValid: Bool {
        confidence >= Constants.minConfidence &&
        distance >= Constants.minDepth &&
        distance <= Constants.maxDepth
    }
    
    var position2D: SIMD2<Float> {
        SIMD2<Float>(position.x, position.z)
    }
}
