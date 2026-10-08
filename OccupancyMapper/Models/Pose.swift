import simd

struct Pose {
    var position: SIMD3<Float>
    var rotation: simd_float3x3
    
    init(position: SIMD3<Float> = .zero,
         rotation: simd_float3x3 = matrix_identity_float3x3) {
        self.position = position
        self.rotation = rotation
    }
    
    init(transform: simd_float4x4) {
        self.position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        self.rotation = simd_float3x3(
            SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )
    }
    
    var position2D: SIMD2<Float> {
        SIMD2<Float>(position.x, position.z)
    }
}
