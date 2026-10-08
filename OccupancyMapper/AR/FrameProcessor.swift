import ARKit
import simd

class FrameProcessor {
    
    private let poseProvider   = CameraPoseProvider()
    private let depthProvider  = DepthDataProvider()
    private let gridUpdater    = GridUpdater()
    private let voxelRayCaster = VoxelRayCaster()
    
    func process(frame: ARFrame,
                 on grid: OccupancyGrid2D?,
                 grid3D: OccupancyGrid3D? = nil,
                 floorY: Float? = nil) {
        
        guard depthProvider.hasDepthData(in: frame) else {
            Logger.warning("No depth data in frame")
            return
        }
        
        let cameraPos2D = poseProvider.position2D(from: frame)
        let cameraPos3D = poseProvider.position3D(from: frame)
        
        let measurements = depthProvider.measurements(from: frame, step: 4)
        guard !measurements.isEmpty else { return }
        
        for measurement in measurements {
            guard measurement.isValid else { continue }
            
            if let grid = grid {
                let flatPoint = measurement.position2D
                guard MathUtils.distance2D(cameraPos2D, flatPoint) <= Constants.maxDepth else { continue }
                

                var markOccupied = true
                if Constants.heightFilterEnabled, let floorY = floorY {
                    let y = measurement.position.y
                    let inWallBand = (y >= floorY + Constants.heightBandGroundMargin)
                                  && (y <= floorY + Constants.heightBandCeiling)
                    markOccupied = inWallBand
                }
                
                gridUpdater.castRay(on: grid, from: cameraPos2D, to: flatPoint,
                                    markEndpointOccupied: markOccupied)
            }
            
            if let grid3D = grid3D {
                let point3D = measurement.position
                if MathUtils.distance3D(cameraPos3D, point3D) <= Constants.maxDepth {
                    voxelRayCaster.castRay(on: grid3D, from: cameraPos3D, to: point3D)
                }
            }
        }
    }
}
