import Foundation

class MapImporter {
    
    static let shared = MapImporter()
    private let fileManager = FileManager.default
    
    private var mapsDirectoryURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SavedMaps", isDirectory: true)
    }
    
    private init() {}
    
    func loadAllSessions() -> [MapSession] {
        guard fileManager.fileExists(atPath: mapsDirectoryURL.path) else { return [] }
        guard let files = try? fileManager.contentsOfDirectory(
            at: mapsDirectoryURL, includingPropertiesForKeys: nil) else { return [] }
        
        let sessions = files
            .filter { $0.pathExtension == "json" }
            .compactMap { loadSession(from: $0) }
            .sorted { $0.createdAt > $1.createdAt }
        
        Logger.info("Loaded \(sessions.count) map sessions")
        return sessions
    }
    
    func loadSession(id: UUID) -> MapSession? {
        loadSession(from: mapsDirectoryURL
            .appendingPathComponent("\(id.uuidString).json"))
    }
    
    private func loadSession(from url: URL) -> MapSession? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MapSession.self, from: data)
    }
    
    func restoreGrid(from session: MapSession) -> OccupancyGrid2D {
        let grid = OccupancyGrid2D(resolution: session.gridResolution)
        
        var updates: [(x: Int, y: Int, value: Int8)] = []
        updates.reserveCapacity(session.cellX.count)
        for i in 0..<session.cellX.count {
            updates.append((x: session.cellX[i],
                            y: session.cellY[i],
                            value: session.cellLogOdds[i]))
        }
        grid.setLogOdds(updates)
        
        Logger.info("2D grid restored from session: \(session.name)")
        return grid
    }
    
    func restoreGrid3D(from session: MapSession) -> OccupancyGrid3D? {
        guard let vx = session.voxelX,
              let vy = session.voxelY,
              let vz = session.voxelZ,
              let vlog = session.voxelLogOdds,
              let resolution = session.grid3DResolution,
              !vx.isEmpty else { return nil }
        
        let grid = OccupancyGrid3D(resolution: resolution)
        
        var updates: [(x: Int, y: Int, z: Int, value: Int8)] = []
        updates.reserveCapacity(vx.count)
        for i in 0..<vx.count {
            updates.append((x: vx[i], y: vy[i], z: vz[i], value: vlog[i]))
        }
        grid.setLogOdds(updates)
        
        Logger.info("3D grid restored from session: \(session.name)")
        return grid
    }
    
    func deleteSession(id: UUID) throws {
        let url = mapsDirectoryURL.appendingPathComponent("\(id.uuidString).json")
        try fileManager.removeItem(at: url)
        Logger.info("Session deleted: \(id.uuidString)")
    }
}
