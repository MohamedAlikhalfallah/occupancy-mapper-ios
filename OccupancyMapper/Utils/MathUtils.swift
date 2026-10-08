import simd
import ARKit

struct MathUtils {

    static func position2D(from transform: simd_float4x4) -> SIMD2<Float> {
        SIMD2<Float>(transform.columns.3.x, transform.columns.3.z)
    }

    static func position3D(from transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }


    static func unprojectPoint(col: Int, row: Int,
                                width: Int, height: Int,
                                depth: Float,
                                intrinsics: simd_float3x3,
                                transform: simd_float4x4) -> SIMD3<Float> {
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        let cx = intrinsics[2][0]
        let cy = intrinsics[2][1]

        let x = (Float(col) - cx) / fx * depth
        let y = (Float(row) - cy) / fy * depth

        let localPoint = SIMD4<Float>(x, -y, -depth, 1.0)
        let worldPoint = transform * localPoint
        return SIMD3<Float>(worldPoint.x, worldPoint.y, worldPoint.z)
    }

    static func distance2D(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        simd_length(b - a)
    }

    static func distance3D(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        simd_length(b - a)
    }

    static func normalize2D(_ v: SIMD2<Float>) -> SIMD2<Float> {
        let len = simd_length(v)
        guard len > 0 else { return .zero }
        return v / len
    }

    static func toRadians(_ degrees: Float) -> Float { degrees * .pi / 180.0 }
    static func toDegrees(_ radians: Float) -> Float { radians * 180.0 / .pi }
}
