import UIKit
import Foundation

class MapExporter {
    
    static let shared = MapExporter()
    private let fileManager = FileManager.default
    
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var mapsDirectoryURL: URL {
        documentsURL.appendingPathComponent("SavedMaps", isDirectory: true)
    }
    
    private init() { createMapsDirectoryIfNeeded() }
    
    func save(_ session: MapSession) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        let fileURL = mapsDirectoryURL
            .appendingPathComponent("\(session.id.uuidString).json")
        try data.write(to: fileURL, options: .atomic)
        Logger.info("Map saved: \(session.name)")
    }
    
    func exportImage(from grid: OccupancyGrid2D, name: String) -> UIImage? {
        let bounds = grid.observedBounds()
        guard !bounds.isEmpty else { return nil }
        
        let size = CGSize(width: bounds.width, height: bounds.height)
        
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setFillColor(UIColor(white: 0.18, alpha: 1.0).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        for entry in grid.allCellsWithCoords() {
            guard entry.cell.isObserved else { continue }
            let px = entry.x - bounds.minX
            let py = entry.y - bounds.minY
            context.setFillColor(colorForCell(entry.cell).cgColor)
            context.fill(CGRect(x: px, y: py, width: 1, height: 1))
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        Logger.info("Map image exported: \(name)")
        return image
    }
    
    func saveImageToPhotos(from grid: OccupancyGrid2D, name: String) {
        guard let image = exportImage(from: grid, name: name) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        Logger.info("Map image saved to photos: \(name)")
    }
    
    private func createMapsDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: mapsDirectoryURL.path) else { return }
        try? fileManager.createDirectory(at: mapsDirectoryURL,
                                         withIntermediateDirectories: true)
    }
    
    private func colorForCell(_ cell: GridCell) -> UIColor {
        if cell.isOccupied { return .black }
        else if cell.isFree { return .white }
        else { return UIColor(white: 0.55, alpha: 1.0) }
    }
}
