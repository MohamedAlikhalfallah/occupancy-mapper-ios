import Foundation


final class TileStore {
    
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
    
    private func url(cx: Int, cy: Int) -> URL {
        directory.appendingPathComponent("t_\(cx)_\(cy).bin")
    }
    
    func write(cx: Int, cy: Int, values: [Int8], observed: [Bool]) {
        var bytes = [UInt8]()
        bytes.reserveCapacity(values.count + observed.count)
        for v in values   { bytes.append(UInt8(bitPattern: v)) }
        for o in observed { bytes.append(o ? 1 : 0) }
        try? Data(bytes).write(to: url(cx: cx, cy: cy), options: .atomic)
    }
    
    func read(cx: Int, cy: Int, cellCount: Int) -> (values: [Int8], observed: [Bool])? {
        let fileURL = url(cx: cx, cy: cy)
        guard let data = try? Data(contentsOf: fileURL),
              data.count == cellCount * 2 else { return nil }
        let bytes = [UInt8](data)
        var values   = [Int8](repeating: 0, count: cellCount)
        var observed = [Bool](repeating: false, count: cellCount)
        for i in 0..<cellCount { values[i]   = Int8(bitPattern: bytes[i]) }
        for i in 0..<cellCount { observed[i] = bytes[cellCount + i] != 0 }
        return (values, observed)
    }
    
    func exists(cx: Int, cy: Int) -> Bool {
        fileManager.fileExists(atPath: url(cx: cx, cy: cy).path)
    }
    
    func removeAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory,
                                         withIntermediateDirectories: true)
    }
}
