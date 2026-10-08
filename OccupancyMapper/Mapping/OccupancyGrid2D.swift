import Foundation
import simd


class OccupancyGrid2D {
    
    struct ChunkKey: Hashable {
        let cx: Int
        let cy: Int
    }
    
    final class Chunk {
        var values:   [Int8]
        var observed: [Bool]
        var lastTouched: Int = 0
        var dirty: Bool = true
        init(cellCount: Int) {
            values   = [Int8](repeating: LogOdds.unknown, count: cellCount)
            observed = [Bool](repeating: false, count: cellCount)
        }
    }
    
    private var chunks: [ChunkKey: Chunk] = [:]
    private var onDisk: Set<ChunkKey>     = []
    private let tileStore: TileStore
    
    private let queue = DispatchQueue(label: "com.occupancymapper.grid2d",
                                      qos: .userInitiated,
                                      attributes: .concurrent)
    
    let resolution: Float
    var origin: SIMD2<Float> = .zero
    
    private let chunkSize: Int
    private let cellsPerChunk: Int
    
    private var totalObserved = 0
    private var totalOccupied = 0
    private var totalFree     = 0
    
    private var gMinX =  Int.max
    private var gMaxX =  Int.min
    private var gMinY =  Int.max
    private var gMaxY =  Int.min
    
    private var tick = 0
    private var lastWindowChunk: ChunkKey? = nil
    
    init(width: Int = Constants.gridWidth,
         height: Int = Constants.gridHeight,
         resolution: Float = Constants.gridResolution) {
        self.resolution    = resolution
        self.chunkSize     = Constants.chunkSize2D
        self.cellsPerChunk = chunkSize * chunkSize
        self.tileStore     = TileStore(name: "grid2d")
        self.tileStore.removeAll()
    }
    
    func worldToGrid(_ worldPos: SIMD2<Float>) -> (x: Int, y: Int)? {
        let local = worldPos - origin
        return (Int(floor(local.x / resolution)),
                Int(floor(local.y / resolution)))
    }
    func gridToWorld(x: Int, y: Int) -> SIMD2<Float> {
        SIMD2<Float>(Float(x) * resolution + origin.x,
                     Float(y) * resolution + origin.y)
    }
    
    @inline(__always) private func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }
    @inline(__always) private func floorMod(_ a: Int, _ b: Int) -> Int {
        let r = a % b
        return r < 0 ? r + b : r
    }
    @inline(__always) private func keyOf(x: Int, y: Int) -> ChunkKey {
        ChunkKey(cx: floorDiv(x, chunkSize), cy: floorDiv(y, chunkSize))
    }
    @inline(__always) private func offsetOf(x: Int, y: Int) -> Int {
        floorMod(y, chunkSize) * chunkSize + floorMod(x, chunkSize)
    }
    @inline(__always) private func cellCoord(key: ChunkKey, offset: Int) -> (x: Int, y: Int) {
        (key.cx * chunkSize + offset % chunkSize,
         key.cy * chunkSize + offset / chunkSize)
    }
    
    private func residentChunk(_ key: ChunkKey, createIfMissing: Bool) -> Chunk? {
        if let c = chunks[key] { return c }
        if onDisk.contains(key),
           let t = tileStore.read(cx: key.cx, cy: key.cy, cellCount: cellsPerChunk) {
            let c = Chunk(cellCount: cellsPerChunk)
            c.values = t.values
            c.observed = t.observed
            c.dirty = false
            chunks[key] = c
            onDisk.remove(key)
            return c
        }
        if createIfMissing {
            let c = Chunk(cellCount: cellsPerChunk)
            chunks[key] = c
            return c
        }
        return nil
    }
    
    @inline(__always) private func classOf(observed: Bool, value: Int8) -> Int {
        if !observed { return 0 }
        if LogOdds.isOccupied(value) { return 3 }
        if LogOdds.isFree(value)     { return 1 }
        return 2
    }
    @inline(__always) private func adjustCounts(from old: Int, to new: Int) {
        if old == new { return }
        if old == 0 { totalObserved += 1 }
        if old == 1 { totalFree     -= 1 }
        if old == 3 { totalOccupied -= 1 }
        if new == 1 { totalFree     += 1 }
        if new == 3 { totalOccupied += 1 }
    }
    @inline(__always) private func growBounds(x: Int, y: Int) {
        if x < gMinX { gMinX = x }
        if x > gMaxX { gMaxX = x }
        if y < gMinY { gMinY = y }
        if y > gMaxY { gMaxY = y }
    }
    
    struct Bounds {
        let minX: Int, maxX: Int, minY: Int, maxY: Int
        var isEmpty: Bool { minX > maxX }
        var width: Int  { isEmpty ? 0 : maxX - minX + 1 }
        var height: Int { isEmpty ? 0 : maxY - minY + 1 }
    }
    func observedBounds() -> Bounds {
        queue.sync { Bounds(minX: gMinX, maxX: gMaxX, minY: gMinY, maxY: gMaxY) }
    }
    var totalObservedCells: Int { queue.sync { totalObserved } }
    var totalOccupiedCells: Int { queue.sync { totalOccupied } }
    var totalFreeCells: Int     { queue.sync { totalFree } }
    var residentChunkCount: Int { queue.sync { chunks.count } }
    var evictedChunkCount: Int  { queue.sync { onDisk.count } }
    var storageBytes: Int       { queue.sync { chunks.count * cellsPerChunk * 2 } }
    
    func logOdds(x: Int, y: Int) -> Int8? {
        queue.sync {
            let key = keyOf(x: x, y: y)
            let off = offsetOf(x: x, y: y)
            if let c = chunks[key], c.observed[off] { return c.values[off] }
            return nil
        }
    }
    func cell(x: Int, y: Int) -> GridCell? {
        guard let v = logOdds(x: x, y: y) else { return nil }
        return GridCell(logOdds: v, isObserved: true)
    }
    
    func observedCellsWithCoords() -> [(x: Int, y: Int, cell: GridCell)] {
        queue.sync {
            var result: [(x: Int, y: Int, cell: GridCell)] = []
            result.reserveCapacity(chunks.count * 64)
            for (key, chunk) in chunks {
                for off in 0..<cellsPerChunk where chunk.observed[off] {
                    let c = cellCoord(key: key, offset: off)
                    result.append((c.x, c.y,
                                   GridCell(logOdds: chunk.values[off], isObserved: true)))
                }
            }
            return result
        }
    }
    
    func allCellsWithCoords() -> [(x: Int, y: Int, cell: GridCell)] {
        queue.sync {
            var result: [(x: Int, y: Int, cell: GridCell)] = []
            result.reserveCapacity((chunks.count + onDisk.count) * 64)
            for (key, chunk) in chunks {
                for off in 0..<cellsPerChunk where chunk.observed[off] {
                    let c = cellCoord(key: key, offset: off)
                    result.append((c.x, c.y,
                                   GridCell(logOdds: chunk.values[off], isObserved: true)))
                }
            }
            for key in onDisk {
                guard let t = tileStore.read(cx: key.cx, cy: key.cy,
                                             cellCount: cellsPerChunk) else { continue }
                for off in 0..<cellsPerChunk where t.observed[off] {
                    let c = cellCoord(key: key, offset: off)
                    result.append((c.x, c.y,
                                   GridCell(logOdds: t.values[off], isObserved: true)))
                }
            }
            return result
        }
    }
    
    func applyDeltas(_ updates: [(x: Int, y: Int, delta: Int8)]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.tick += 1
            var cachedKey: ChunkKey? = nil
            var cachedChunk: Chunk? = nil
            for u in updates {
                let key = self.keyOf(x: u.x, y: u.y)
                let chunk: Chunk
                if key == cachedKey, let c = cachedChunk {
                    chunk = c
                } else {
                    chunk = self.residentChunk(key, createIfMissing: true)!
                    cachedKey = key; cachedChunk = chunk
                }
                let off = self.offsetOf(x: u.x, y: u.y)
                let oldClass = self.classOf(observed: chunk.observed[off], value: chunk.values[off])
                let newVal = LogOdds.update(chunk.values[off], delta: u.delta)
                chunk.values[off]   = newVal
                chunk.observed[off] = true
                chunk.lastTouched   = self.tick
                chunk.dirty         = true
                self.adjustCounts(from: oldClass, to: self.classOf(observed: true, value: newVal))
                self.growBounds(x: u.x, y: u.y)
            }
        }
    }
    
    func setProbabilities(_ updates: [(x: Int, y: Int, probability: Float)]) {
        setLogOdds(updates.map { (x: $0.x, y: $0.y, value: LogOdds.fromProbability($0.probability)) })
    }
    func setLogOdds(_ updates: [(x: Int, y: Int, value: Int8)]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            for u in updates {
                let key = self.keyOf(x: u.x, y: u.y)
                let chunk = self.residentChunk(key, createIfMissing: true)!
                let off = self.offsetOf(x: u.x, y: u.y)
                let oldClass = self.classOf(observed: chunk.observed[off], value: chunk.values[off])
                chunk.values[off]   = u.value
                chunk.observed[off] = true
                chunk.dirty         = true
                self.adjustCounts(from: oldClass, to: self.classOf(observed: true, value: u.value))
                self.growBounds(x: u.x, y: u.y)
            }
        }
    }
    
   
    func maintainActiveWindow(around worldPos: SIMD2<Float>) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let cell = self.worldToGrid(worldPos) else { return }
            let camKey = ChunkKey(cx: self.floorDiv(cell.x, self.chunkSize),
                                  cy: self.floorDiv(cell.y, self.chunkSize))
            if camKey == self.lastWindowChunk { return }
            self.lastWindowChunk = camKey
            
            let tileMetres = Float(self.chunkSize) * self.resolution
            let radiusChunks = max(1, Int((Constants.activeWindowRadius / tileMetres).rounded(.up)))
            
            var toEvict: [ChunkKey] = []
            for (key, _) in self.chunks {
                if max(abs(key.cx - camKey.cx), abs(key.cy - camKey.cy)) > radiusChunks {
                    toEvict.append(key)
                }
            }
            for key in toEvict {
                guard let chunk = self.chunks[key] else { continue }
                if chunk.dirty || !self.tileStore.exists(cx: key.cx, cy: key.cy) {
                    self.tileStore.write(cx: key.cx, cy: key.cy,
                                         values: chunk.values, observed: chunk.observed)
                }
                self.chunks.removeValue(forKey: key)
                self.onDisk.insert(key)
            }
            
            var toFault: [ChunkKey] = []
            for key in self.onDisk {
                if max(abs(key.cx - camKey.cx), abs(key.cy - camKey.cy)) <= radiusChunks {
                    toFault.append(key)
                }
            }
            for key in toFault {
                if let t = self.tileStore.read(cx: key.cx, cy: key.cy, cellCount: self.cellsPerChunk) {
                    let c = Chunk(cellCount: self.cellsPerChunk)
                    c.values = t.values; c.observed = t.observed; c.dirty = false
                    self.chunks[key] = c
                }
                self.onDisk.remove(key)
            }
            
            if !toEvict.isEmpty || !toFault.isEmpty {
                Logger.info("Window: \(self.chunks.count) resident, \(self.onDisk.count) on disk")
            }
        }
    }
    
    func reset() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.chunks.removeAll()
            self.onDisk.removeAll()
            self.tileStore.removeAll()
            self.totalObserved = 0; self.totalOccupied = 0; self.totalFree = 0
            self.gMinX = Int.max; self.gMaxX = Int.min
            self.gMinY = Int.max; self.gMaxY = Int.min
            self.lastWindowChunk = nil
            Logger.info("OccupancyGrid2D reset (tile-streaming)")
        }
    }
}
