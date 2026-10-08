import Foundation
import simd

class RayCaster {
    
    private let freeRadiusCells: Int =
        Int(Constants.freeMarkingRadius / Constants.gridResolution)
    
    func castRay(on grid: OccupancyGrid2D,
                 from origin: SIMD2<Float>,
                 to endpoint: SIMD2<Float>,
                 markEndpointOccupied: Bool = true) {
        
        guard let startCell = grid.worldToGrid(origin),
              let endCell   = grid.worldToGrid(endpoint) else { return }
        
        let totalSteps = max(abs(endCell.x - startCell.x),
                             abs(endCell.y - startCell.y))
        let fractionLimit = Int(Double(totalSteps) * Constants.freeMarkingFraction)
        let freeLimit = min(fractionLimit, freeRadiusCells)
        
        var updates: [(x: Int, y: Int, delta: Int8)] = []
        updates.reserveCapacity(min(totalSteps, freeLimit) + 1)
        
        var step = 0
        bresenham(from: startCell, to: endCell) { x, y, isEndpoint in
            if isEndpoint {
                if markEndpointOccupied {
                    updates.append((x: x, y: y, delta: LogOdds.occupiedDelta))
                } else if step <= freeLimit {
                    updates.append((x: x, y: y, delta: LogOdds.freeDelta))
                }
            } else if step <= freeLimit {
                updates.append((x: x, y: y, delta: LogOdds.freeDelta))
            }
            step += 1
        }
        
        grid.applyDeltas(updates)
    }
    
    private func bresenham(from start: (x: Int, y: Int),
                           to end: (x: Int, y: Int),
                           visit: (Int, Int, Bool) -> Void) {
        var x0 = start.x, y0 = start.y
        let x1 = end.x,   y1 = end.y
        
        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx - dy
        
        while true {
            let isEndpoint = (x0 == x1 && y0 == y1)
            visit(x0, y0, isEndpoint)
            if isEndpoint { break }
            let e2 = 2 * err
            if e2 > -dy { err -= dy; x0 += sx }
            if e2 <  dx { err += dx; y0 += sy }
        }
    }
}
