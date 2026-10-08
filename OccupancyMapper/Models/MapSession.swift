import Foundation

struct MapSession: Codable, Identifiable {
    
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    
    let gridResolution: Float
    var cellX: [Int]
    var cellY: [Int]
    var cellLogOdds: [Int8]
    var totalObservedCells: Int
    var occupiedCellCount: Int
    var freeCellCount: Int
    
    var grid3DResolution: Float?
    var voxelX: [Int]?
    var voxelY: [Int]?
    var voxelZ: [Int]?
    var voxelLogOdds: [Int8]?
    var totalObservedVoxels: Int?
    var occupiedVoxelCount: Int?
    var freeVoxelCount: Int?
    
    init(name: String,
         grid: OccupancyGrid2D,
         grid3D: OccupancyGrid3D? = nil) {
        self.id        = UUID()
        self.name      = name
        self.createdAt = Date()
        self.updatedAt = Date()
        
        self.gridResolution = grid.resolution
        
        let observed = grid.allCellsWithCoords()
        self.cellX       = observed.map { $0.x }
        self.cellY       = observed.map { $0.y }
        self.cellLogOdds = observed.map { $0.cell.logOdds }
        self.totalObservedCells = observed.count
        self.occupiedCellCount  = observed.filter { $0.cell.isOccupied }.count
        self.freeCellCount      = observed.filter { $0.cell.isFree }.count
        
        Self.fill3D(from: grid3D, into: &self)
    }
    
    init(updating existing: MapSession,
         grid: OccupancyGrid2D,
         grid3D: OccupancyGrid3D? = nil) {
        self.id        = existing.id
        self.name      = existing.name
        self.createdAt = existing.createdAt
        self.updatedAt = Date()
        
        self.gridResolution = grid.resolution
        
        let observed = grid.allCellsWithCoords()
        self.cellX       = observed.map { $0.x }
        self.cellY       = observed.map { $0.y }
        self.cellLogOdds = observed.map { $0.cell.logOdds }
        self.totalObservedCells = observed.count
        self.occupiedCellCount  = observed.filter { $0.cell.isOccupied }.count
        self.freeCellCount      = observed.filter { $0.cell.isFree }.count
        
        Self.fill3D(from: grid3D, into: &self)
        
        if voxelX == nil {
            grid3DResolution    = existing.grid3DResolution
            voxelX              = existing.voxelX
            voxelY              = existing.voxelY
            voxelZ              = existing.voxelZ
            voxelLogOdds        = existing.voxelLogOdds
            totalObservedVoxels = existing.totalObservedVoxels
            occupiedVoxelCount  = existing.occupiedVoxelCount
            freeVoxelCount      = existing.freeVoxelCount
        }
    }
    
    private static func fill3D(from grid3D: OccupancyGrid3D?,
                               into session: inout MapSession) {
        guard let g = grid3D else { return }
        let voxels = g.allVoxelsWithCoords()
        guard !voxels.isEmpty else { return }
        
        session.grid3DResolution    = g.resolution
        session.voxelX              = voxels.map { $0.x }
        session.voxelY              = voxels.map { $0.y }
        session.voxelZ              = voxels.map { $0.z }
        session.voxelLogOdds        = voxels.map { $0.voxel.logOdds }
        session.totalObservedVoxels = voxels.count
        session.occupiedVoxelCount  = voxels.filter { $0.voxel.isOccupied }.count
        session.freeVoxelCount      = voxels.filter { $0.voxel.isFree }.count
    }
    
    var hasVolumetricData: Bool { (voxelX?.isEmpty == false) }
    
    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: createdAt)
    }
    
    var observedArea: Double {
        let cellArea = Double(gridResolution) * Double(gridResolution)
        return Double(totalObservedCells) * cellArea
    }
    
    var mapSizeDescription: String {
        String(format: "%.1f m² observed", observedArea)
    }
}
