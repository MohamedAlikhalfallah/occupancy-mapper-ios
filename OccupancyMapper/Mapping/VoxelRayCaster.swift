import Foundation
import simd

class VoxelRayCaster {
    
    private let freeRadiusVoxels: Int =
        Int(Constants.freeMarkingRadius / Constants.grid3DResolution)
    
    
    func castRay(on grid: OccupancyGrid3D,
                 from origin: SIMD3<Float>,
                 to endpoint: SIMD3<Float>) {
        
        guard let startVoxel = grid.worldToVoxel(origin),
              let endVoxel   = grid.worldToVoxel(endpoint) else { return }
        
        let totalSteps = max(max(abs(endVoxel.x - startVoxel.x),
                                 abs(endVoxel.y - startVoxel.y)),
                             abs(endVoxel.z - startVoxel.z))
        let fractionLimit = Int(Double(totalSteps) * Constants.freeMarkingFraction)
        let freeLimit = min(fractionLimit, freeRadiusVoxels)
        
        var updates: [(x: Int, y: Int, z: Int, delta: Int8)] = []
        updates.reserveCapacity(min(totalSteps, freeLimit) + 1)
        
        var step = 0
        bresenham3D(from: startVoxel, to: endVoxel) { x, y, z, isEndpoint in
            if isEndpoint {
                updates.append((x: x, y: y, z: z, delta: LogOdds.occupiedDelta))
            } else if step <= freeLimit {
                updates.append((x: x, y: y, z: z, delta: LogOdds.freeDelta))
            }
            step += 1
        }
        
        grid.applyDeltas(updates)
    }
    
    
    private func bresenham3D(from start: (x: Int, y: Int, z: Int),
                             to end: (x: Int, y: Int, z: Int),
                             visit: (Int, Int, Int, Bool) -> Void) {
        var x0 = start.x, y0 = start.y, z0 = start.z
        let x1 = end.x,   y1 = end.y,   z1 = end.z
        
        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)
        let dz = abs(z1 - z0)
        
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        let sz = z0 < z1 ? 1 : -1
        
        if dx >= dy && dx >= dz {
            var p1 = 2 * dy - dx, p2 = 2 * dz - dx
            while x0 != x1 {
                visit(x0, y0, z0, false)
                if p1 >= 0 { y0 += sy; p1 -= 2 * dx }
                if p2 >= 0 { z0 += sz; p2 -= 2 * dx }
                p1 += 2 * dy; p2 += 2 * dz; x0 += sx
            }
        } else if dy >= dx && dy >= dz {
            var p1 = 2 * dx - dy, p2 = 2 * dz - dy
            while y0 != y1 {
                visit(x0, y0, z0, false)
                if p1 >= 0 { x0 += sx; p1 -= 2 * dy }
                if p2 >= 0 { z0 += sz; p2 -= 2 * dy }
                p1 += 2 * dx; p2 += 2 * dz; y0 += sy
            }
        } else {
            var p1 = 2 * dy - dz, p2 = 2 * dx - dz
            while z0 != z1 {
                visit(x0, y0, z0, false)
                if p1 >= 0 { y0 += sy; p1 -= 2 * dz }
                if p2 >= 0 { x0 += sx; p2 -= 2 * dz }
                p1 += 2 * dy; p2 += 2 * dx; z0 += sz
            }
        }
        
        visit(x1, y1, z1, true)
    }
}
