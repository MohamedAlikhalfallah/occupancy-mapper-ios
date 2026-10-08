import simd

struct Ray {
    var origin: SIMD3<Float>
    var direction: SIMD3<Float>
    var maxDistance: Float
    
    init(origin: SIMD3<Float>,
         direction: SIMD3<Float>,
         maxDistance: Float = Constants.maxDepth) {
        self.origin = origin
        self.direction = simd_normalize(direction)
        self.maxDistance = maxDistance
    }
    
    func point(at t: Float) -> SIMD3<Float> {
        origin + direction * t
    }
    
    var origin2D: SIMD2<Float> {
        SIMD2<Float>(origin.x, origin.z)
    }
    
    var endpoint2D: SIMD2<Float> {
        let end = point(at: maxDistance)
        return SIMD2<Float>(end.x, end.z)
    }
}
