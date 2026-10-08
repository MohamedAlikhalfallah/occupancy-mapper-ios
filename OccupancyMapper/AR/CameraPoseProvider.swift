import ARKit
import simd

class CameraPoseProvider {
    
    func pose(from frame: ARFrame) -> Pose {
        Pose(transform: frame.camera.transform)
    }
    
    func position2D(from frame: ARFrame) -> SIMD2<Float> {
        MathUtils.position2D(from: frame.camera.transform)
    }
    
    func position3D(from frame: ARFrame) -> SIMD3<Float> {
        MathUtils.position3D(from: frame.camera.transform)
    }
    
    func intrinsics(from frame: ARFrame) -> simd_float3x3 {
        frame.camera.intrinsics
    }
    
    func transform(from frame: ARFrame) -> simd_float4x4 {
        frame.camera.transform
    }
}
