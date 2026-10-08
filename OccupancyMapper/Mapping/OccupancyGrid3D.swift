import Foundation
import simd


class OccupancyGrid3D {
    
    struct BlockKey: Hashable {
        let bx: Int
        let by: Int
        let bz: Int
    }
    
    final class Block {
        var values:   [Int8]
        var observed: [Bool]
        var lastTouched: Int = 0
        var dirty: Bool = true
        init(voxelCount: Int) {
            values   = [Int8](repeating: LogOdds.unknown, count: voxelCount)
            observed = [Bool](repeating: false, count: voxelCount)
        }
    }
    
    private var blocks: [BlockKey: Block] = [:]
    private var onDisk: Set<BlockKey>     = []
    private let tileStore: VoxelTileStore
    
    private let queue = DispatchQueue(label: "com.occupancymapper.grid3d",
                                      qos: .userInitiated,
                                      attributes: .concurrent)
    
    let resolution: Float
    var origin: SIMD3<Float> = .zero
    
    private let blockSize: Int
    private let voxelsPerBlock: Int
    
    private var totalObserved = 0
    private var totalOccupied = 0
    private var totalFree     = 0
    
    private var tick = 0
    private var lastWindowBlock: BlockKey? = nil
    
    init(dimX: Int = Constants.grid3DDimX,
         dimY: Int = Constants.grid3DDimY,
         dimZ: Int = Constants.grid3DDimZ,
         resolution: Float = Constants.grid3DResolution) {
        self.resolution     = resolution
        self.blockSize      = Constants.chunkSize3D
        self.voxelsPerBlock = blockSize * blockSize * blockSize
        self.tileStore      = VoxelTileStore(name: "grid3d")
        self.tileStore.removeAll()
    }
    
    func worldToVoxel(_ worldPos: SIMD3<Float>) -> (x: Int, y: Int, z: Int)? {
        let local = worldPos - origin
        return (Int(floor(local.x / resolution)),
                Int(floor(local.y / resolution)),
                Int(floor(local.z / resolution)))
    }
    func voxelToWorld(x: Int, y: Int, z: Int) -> SIMD3<Float> {
        SIMD3<Float>(Float(x) * resolution + origin.x,
                     Float(y) * resolution + origin.y,
                     Float(z) * resolution + origin.z)
    }
    
    @inline(__always) private func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }
    @inline(__always) private func floorMod(_ a: Int, _ b: Int) -> Int {
        let r = a % b
        return r < 0 ? r + b : r
    }
    @inline(__always) private func keyOf(x: Int, y: Int, z: Int) -> BlockKey {
        BlockKey(bx: floorDiv(x, blockSize),
                 by: floorDiv(y, blockSize),
                 bz: floorDiv(z, blockSize))
    }
    @inline(__always) private func offsetOf(x: Int, y: Int, z: Int) -> Int {
        (floorMod(z, blockSize) * blockSize + floorMod(y, blockSize)) * blockSize
            + floorMod(x, blockSize)
    }
    @inline(__always) private func voxelCoord(key: BlockKey, offset: Int) -> (x: Int, y: Int, z: Int) {
        let lx = offset % blockSize
        let ly = (offset / blockSize) % blockSize
        let lz = offset / (blockSize * blockSize)
        return (key.bx * blockSize + lx,
                key.by * blockSize + ly,
                key.bz * blockSize + lz)
    }
    
    private func residentBlock(_ key: BlockKey, createIfMissing: Bool) -> Block? {
        if let b = blocks[key] { return b }
        if onDisk.contains(key),
           let t = tileStore.read(bx: key.bx, by: key.by, bz: key.bz, voxelCount: voxelsPerBlock) {
            let b = Block(voxelCount: voxelsPerBlock)
            b.values = t.values
            b.observed = t.observed
            b.dirty = false
            blocks[key] = b
            onDisk.remove(key)
            return b
        }
        if createIfMissing {
            let b = Block(voxelCount: voxelsPerBlock)
            blocks[key] = b
            return b
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
    
    var storedVoxelCount: Int    { queue.sync { totalObserved } }
    var occupiedVoxelTotal: Int  { queue.sync { totalOccupied } }
    var freeVoxelTotal: Int      { queue.sync { totalFree } }
    var residentBlockCount: Int  { queue.sync { blocks.count } }
    var evictedBlockCount: Int   { queue.sync { onDisk.count } }
    
    func logOdds(x: Int, y: Int, z: Int) -> Int8? {
        queue.sync {
            let key = keyOf(x: x, y: y, z: z)
            let off = offsetOf(x: x, y: y, z: z)
            if let b = blocks[key], b.observed[off] { return b.values[off] }
            return nil
        }
    }
    func voxel(x: Int, y: Int, z: Int) -> VoxelCell? {
        guard let v = logOdds(x: x, y: y, z: z) else { return nil }
        return VoxelCell(logOdds: v, isObserved: true)
    }
    
    func observedVoxelsWithCoords() -> [(x: Int, y: Int, z: Int, voxel: VoxelCell)] {
        queue.sync {
            var result: [(x: Int, y: Int, z: Int, voxel: VoxelCell)] = []
            result.reserveCapacity(blocks.count * 64)
            for (key, block) in blocks {
                for off in 0..<voxelsPerBlock where block.observed[off] {
                    let c = voxelCoord(key: key, offset: off)
                    result.append((c.x, c.y, c.z,
                                   VoxelCell(logOdds: block.values[off], isObserved: true)))
                }
            }
            return result
        }
    }
    
    func allVoxelsWithCoords() -> [(x: Int, y: Int, z: Int, voxel: VoxelCell)] {
        queue.sync {
            var result: [(x: Int, y: Int, z: Int, voxel: VoxelCell)] = []
            result.reserveCapacity((blocks.count + onDisk.count) * 64)
            for (key, block) in blocks {
                for off in 0..<voxelsPerBlock where block.observed[off] {
                    let c = voxelCoord(key: key, offset: off)
                    result.append((c.x, c.y, c.z,
                                   VoxelCell(logOdds: block.values[off], isObserved: true)))
                }
            }
            for key in onDisk {
                guard let t = tileStore.read(bx: key.bx, by: key.by, bz: key.bz,
                                             voxelCount: voxelsPerBlock) else { continue }
                for off in 0..<voxelsPerBlock where t.observed[off] {
                    let c = voxelCoord(key: key, offset: off)
                    result.append((c.x, c.y, c.z,
                                   VoxelCell(logOdds: t.values[off], isObserved: true)))
                }
            }
            return result
        }
    }
    
    func applyDeltas(_ updates: [(x: Int, y: Int, z: Int, delta: Int8)]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.tick += 1
            var cachedKey: BlockKey? = nil
            var cachedBlock: Block? = nil
            for u in updates {
                let key = self.keyOf(x: u.x, y: u.y, z: u.z)
                let block: Block
                if key == cachedKey, let b = cachedBlock {
                    block = b
                } else {
                    block = self.residentBlock(key, createIfMissing: true)!
                    cachedKey = key; cachedBlock = block
                }
                let off = self.offsetOf(x: u.x, y: u.y, z: u.z)
                let oldClass = self.classOf(observed: block.observed[off], value: block.values[off])
                let newVal = LogOdds.update(block.values[off], delta: u.delta)
                block.values[off]   = newVal
                block.observed[off] = true
                block.lastTouched   = self.tick
                block.dirty         = true
                self.adjustCounts(from: oldClass, to: self.classOf(observed: true, value: newVal))
            }
        }
    }
    
    func setLogOdds(_ updates: [(x: Int, y: Int, z: Int, value: Int8)]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            for u in updates {
                let key = self.keyOf(x: u.x, y: u.y, z: u.z)
                let block = self.residentBlock(key, createIfMissing: true)!
                let off = self.offsetOf(x: u.x, y: u.y, z: u.z)
                let oldClass = self.classOf(observed: block.observed[off], value: block.values[off])
                block.values[off]   = u.value
                block.observed[off] = true
                block.dirty         = true
                self.adjustCounts(from: oldClass, to: self.classOf(observed: true, value: u.value))
            }
        }
    }
    
    func maintainActiveWindow(around worldPos: SIMD3<Float>) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let v = self.worldToVoxel(worldPos) else { return }
            let camKey = BlockKey(bx: self.floorDiv(v.x, self.blockSize),
                                  by: self.floorDiv(v.y, self.blockSize),
                                  bz: self.floorDiv(v.z, self.blockSize))
            if camKey == self.lastWindowBlock { return }
            self.lastWindowBlock = camKey
            
            let blockMetres = Float(self.blockSize) * self.resolution
            let radius = max(1, Int((Constants.activeWindowRadius / blockMetres).rounded(.up)))
            
            func dist(_ a: BlockKey) -> Int {
                max(max(abs(a.bx - camKey.bx), abs(a.by - camKey.by)), abs(a.bz - camKey.bz))
            }
            
            var toEvict: [BlockKey] = []
            for (key, _) in self.blocks where dist(key) > radius { toEvict.append(key) }
            for key in toEvict {
                guard let block = self.blocks[key] else { continue }
                if block.dirty || !self.tileStore.exists(bx: key.bx, by: key.by, bz: key.bz) {
                    self.tileStore.write(bx: key.bx, by: key.by, bz: key.bz,
                                         values: block.values, observed: block.observed)
                }
                self.blocks.removeValue(forKey: key)
                self.onDisk.insert(key)
            }
            
            var toFault: [BlockKey] = []
            for key in self.onDisk where dist(key) <= radius { toFault.append(key) }
            for key in toFault {
                if let t = self.tileStore.read(bx: key.bx, by: key.by, bz: key.bz,
                                               voxelCount: self.voxelsPerBlock) {
                    let b = Block(voxelCount: self.voxelsPerBlock)
                    b.values = t.values; b.observed = t.observed; b.dirty = false
                    self.blocks[key] = b
                }
                self.onDisk.remove(key)
            }
        }
    }
    
    func reset() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.blocks.removeAll()
            self.onDisk.removeAll()
            self.tileStore.removeAll()
            self.totalObserved = 0; self.totalOccupied = 0; self.totalFree = 0
            self.lastWindowBlock = nil
            Logger.info("OccupancyGrid3D reset (tile-streaming)")
        }
    }
}
