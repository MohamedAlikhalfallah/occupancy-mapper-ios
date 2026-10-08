import ARKit
import simd

class GridUpdater {
    
    private let rayCaster = RayCaster()
    
    func castRay(on grid: OccupancyGrid2D,
                 from origin: SIMD2<Float>,
                 to endpoint: SIMD2<Float>,
                 markEndpointOccupied: Bool = true) {
        rayCaster.castRay(on: grid, from: origin, to: endpoint,
                          markEndpointOccupied: markEndpointOccupied)
    }
}
