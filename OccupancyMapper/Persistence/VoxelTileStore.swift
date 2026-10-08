import Foundation


final class VoxelTileStore {
    
    private let directory: URL
    private let fileManager = FileManager.default
    
    init(name: String) {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches
            .appendingPathComponent("MapTiles", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try? fileManager.createDirectory(at: directory,
                                         withIntermediateDirectories: true)
    }
    
    private func url(bx: Int, by: Int, bz: Int) -> URL {
        directory.appendingPathComponent("t_\(bx)_\(by)_\(bz).bin")
    }
    
    func write(bx: Int, by: Int, bz: Int, values: [Int8], observed: [Bool]) {
        var bytes = [UInt8]()
        bytes.reserveCapacity(values.count + observed.count)
        for v in values   { bytes.append(UInt8(bitPattern: v)) }
        for o in observed { bytes.append(o ? 1 : 0) }
        try? Data(bytes).write(to: url(bx: bx, by: by, bz: bz), options: .atomic)
    }
    
    func read(bx: Int, by: Int, bz: Int, voxelCount: Int) -> (values: [Int8], observed: [Bool])? {
        let fileURL = url(bx: bx, by: by, bz: bz)
        guard let data = try? Data(contentsOf: fileURL),
              data.count == voxelCount * 2 else { return nil }
        let bytes = [UInt8](data)
        var values   = [Int8](repeating: 0, count: voxelCount)
        var observed = [Bool](repeating: false, count: voxelCount)
        for i in 0..<voxelCount { values[i]   = Int8(bitPattern: bytes[i]) }
        for i in 0..<voxelCount { observed[i] = bytes[voxelCount + i] != 0 }
        return (values, observed)
    }
    
    func exists(bx: Int, by: Int, bz: Int) -> Bool {
        fileManager.fileExists(atPath: url(bx: bx, by: by, bz: bz).path)
    }
    
    func removeAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory,
                                         withIntermediateDirectories: true)
    }
}
