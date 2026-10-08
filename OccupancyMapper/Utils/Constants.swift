import Foundation

enum Constants {
    static let heightFilterEnabled: Bool = true
    static let heightBandGroundMargin: Float = 0.10
    static let heightBandCeiling: Float = 2.0
    static let activeWindowRadius: Float = 12.0
    static let gridResolution: Float = 0.05
    static let grid3DResolution: Float = 0.1
    

    static let gridWidth: Int  = 200
    static let gridHeight: Int = 200
    static let grid3DDimX: Int = 100
    static let grid3DDimY: Int = 30
    static let grid3DDimZ: Int = 100
    
    static let chunkSize2D: Int = 32
    static let chunkSize3D: Int = 8
    
    static let probOccupied: Float = 0.7
    static let probFree: Float     = 0.3
    static let probUnknown: Float  = 0.5
    static let probMin: Float      = 0.01
    static let probMax: Float      = 0.99
    
    static let occupiedThreshold: Float = 0.7
    static let freeThreshold: Float     = 0.3
    
    static let maxDepth: Float      = 5.0
    static let minDepth: Float      = 0.2
    static let minConfidence: Float = 0.4
    

    static let freeMarkingFraction: Double = 0.90
    

    static let freeMarkingRadius: Float = 3.5
}
