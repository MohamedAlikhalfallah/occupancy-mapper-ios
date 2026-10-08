import ARKit
import simd

class CoordinateTransformer {
    
    func worldToGrid2D(_ worldPos: SIMD3<Float>, grid: OccupancyGrid2D) -> (x: Int, y: Int)? {
        let flat = SIMD2<Float>(worldPos.x, worldPos.z)
        return grid.worldToGrid(flat)
    }
    
    func grid2DToWorld(x: Int, y: Int, grid: OccupancyGrid2D) -> SIMD3<Float> {
        let flat = grid.gridToWorld(x: x, y: y)
        return SIMD3<Float>(flat.x, 0, flat.y)
    }
    
    func cameraToWorld(_ point: SIMD3<Float>, transform: simd_float4x4) -> SIMD3<Float> {
        let p = SIMD4<Float>(point.x, point.y, point.z, 1.0)
        let world = transform * p
        return SIMD3<Float>(world.x, world.y, world.z)
    }
    
    func depthPixelToWorld(col: Int, row: Int,
                           depthWidth: Int, depthHeight: Int,
                           depth: Float,
                           intrinsics: simd_float3x3,
                           transform: simd_float4x4) -> SIMD3<Float> {
        MathUtils.unprojectPoint(col: col, row: row,
                                 width: depthWidth, height: depthHeight,
                                 depth: depth, intrinsics: intrinsics, transform: transform)
    }
    
    func toFloorPlane(_ point: SIMD3<Float>) -> SIMD2<Float> {
        SIMD2<Float>(point.x, point.z)
    }
    
    func cameraToFloorPlane(_ transform: simd_float4x4) -> SIMD2<Float> {
        SIMD2<Float>(transform.columns.3.x, transform.columns.3.z)
    }
}
