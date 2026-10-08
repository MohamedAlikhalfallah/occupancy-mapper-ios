import ARKit
import Combine
import simd
import QuartzCore

class ARSessionManager: NSObject, ObservableObject, ARSessionDelegate {

    let session = ARSession()
    let grid    = OccupancyGrid2D()
    let grid3D  = OccupancyGrid3D()

    private let frameProcessor  = FrameProcessor()
    private let updateOptimizer = UpdateOptimizer()
    private var frameCounter    = 0
    private var metricsTimer: Timer?

    
    private let processingQueue = DispatchQueue(label: "com.occupancymapper.processing",
                                                qos: .userInitiated)
    private var isProcessing = false

    private var horizontalPlaneY: [UUID: Float] = [:]
    @Published var floorY: Float? = nil

    @Published var frameCount: Int          = 0
    @Published var isRunning: Bool          = false
    @Published var currentSession: MapSession? = nil
    @Published var currentFPS: Double       = 0.0
    @Published var memoryMB: Float          = 0.0

    @Published var observedCellCount: Int   = 0
    @Published var occupiedCellCount: Int   = 0
    @Published var freeCellCount: Int       = 0
    @Published var residentTiles: Int       = 0
    @Published var evictedTiles: Int        = 0

    @Published var voxelCount: Int          = 0
    @Published var voxelOccupiedCount: Int  = 0
    @Published var voxelFreeCount: Int      = 0
    @Published var resident3DTiles: Int     = 0
    @Published var evicted3DTiles: Int      = 0

    @Published var skipRatio: Double        = 0.0
    @Published var is3DEnabled: Bool        = false
    @Published var currentCameraXZ: SIMD2<Float> = .zero

    @Published var trackingState: ARCamera.TrackingState = .notAvailable

    var trackingText: String {
        switch trackingState {
        case .normal:                          return "Normal"
        case .notAvailable:                    return "Unavailable"
        case .limited(.initializing):          return "Initializing"
        case .limited(.relocalizing):          return "Relocalizing"
        case .limited(.excessiveMotion):       return "Too fast"
        case .limited(.insufficientFeatures):  return "Low detail"
        case .limited:                         return "Limited"
        }
    }

    override init() {
        super.init()
        session.delegate = self
    }

    func startSession() {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            Logger.error("LiDAR not supported on this device")
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = .sceneDepth
        config.planeDetection = [.horizontal]
        session.run(config)
        isRunning = true
        Logger.info("ARKit session started with LiDAR + plane detection")

        MetricsLogger.shared.start(session: is3DEnabled ? "3D" : "2D")
        metricsTimer?.invalidate()
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.logMetricsSnapshot()
        }
    }

    func stopSession() {
        session.pause()
        isRunning = false
        metricsTimer?.invalidate(); metricsTimer = nil
        MetricsLogger.shared.stop()
        Logger.info("ARKit session stopped")
    }

    func pauseSession() {
        session.pause()
        Logger.info("ARKit session paused")
    }

    func resumeSession() {
        startSession()
        Logger.info("ARKit session resumed")
    }

    func resetMap() {
        grid.reset()
        grid3D.reset()
        updateOptimizer.reset()
        FrameRateTracker.shared.reset()
        MemoryMonitor.shared.reset()
        frameCount         = 0
        frameCounter       = 0
        currentSession     = nil
        observedCellCount  = 0
        occupiedCellCount  = 0
        freeCellCount      = 0
        residentTiles      = 0
        evictedTiles       = 0
        voxelCount         = 0
        voxelOccupiedCount = 0
        voxelFreeCount     = 0
        resident3DTiles    = 0
        evicted3DTiles     = 0

        MetricsLogger.shared.stop()
        MetricsLogger.shared.start(session: is3DEnabled ? "3D" : "2D")

        Logger.info("Map reset — metrics log rolled to a new folder")
    }

    private func updateFloor(_ anchors: [ARAnchor]) {
        for case let plane as ARPlaneAnchor in anchors where plane.alignment == .horizontal {
            horizontalPlaneY[plane.identifier] = plane.transform.columns.3.y
        }
        recomputeFloor()
    }
    private func recomputeFloor() {
        let f = horizontalPlaneY.values.min()
        DispatchQueue.main.async { self.floorY = f }
    }

    func updatePerformanceMetrics() {
        currentFPS = FrameRateTracker.shared.update(frameCount: frameCounter)
        memoryMB   = MemoryMonitor.shared.sample()
        skipRatio  = updateOptimizer.skipRatio

        observedCellCount = grid.totalObservedCells
        occupiedCellCount = grid.totalOccupiedCells
        freeCellCount     = grid.totalFreeCells
        residentTiles     = grid.residentChunkCount
        evictedTiles      = grid.evictedChunkCount

        voxelCount         = grid3D.storedVoxelCount
        voxelOccupiedCount = grid3D.occupiedVoxelTotal
        voxelFreeCount     = grid3D.freeVoxelTotal
        resident3DTiles    = grid3D.residentBlockCount
        evicted3DTiles     = grid3D.evictedBlockCount
    }

    private func logMetricsSnapshot() {
        let res       = is3DEnabled ? grid3D.resolution : grid.resolution
        let gridBytes = is3DEnabled ? resident3DTiles * 512 * 2 : grid.storageBytes
        let observed  = is3DEnabled ? voxelCount : observedCellCount
        let resTiles  = is3DEnabled ? resident3DTiles : residentTiles
        let diskTiles = is3DEnabled ? evicted3DTiles  : evictedTiles
        let area      = Double(observedCellCount) * Double(res) * Double(res)
        MetricsLogger.shared.logSnapshot(ramMB: memoryMB, gridBytes: gridBytes,
            residentTiles: resTiles, diskTiles: diskTiles, observed: observed,
            areaM2: area, skipRatio: skipRatio, fps: currentFPS)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        frameCounter += 1

        let transform = frame.camera.transform
        let position  = SIMD3<Float>(transform.columns.3.x,
                                     transform.columns.3.y,
                                     transform.columns.3.z)
        let forward   = SIMD3<Float>(-transform.columns.2.x,
                                     -transform.columns.2.y,
                                     -transform.columns.2.z)

        guard updateOptimizer.shouldProcess(position: position,
                                            forward: forward) else {
            return
        }
        guard !isProcessing else { return }
        isProcessing = true

        let use3D = is3DEnabled
        let floor = floorY

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            let t0 = CACurrentMediaTime()
            self.frameProcessor.process(
                frame: frame,
                on: use3D ? nil : self.grid,
                grid3D: use3D ? self.grid3D : nil,
                floorY: floor
            )
            MetricsLogger.shared.logFrameTime((CACurrentMediaTime() - t0) * 1000.0)

            if use3D {
                self.grid3D.maintainActiveWindow(around: position)
            } else {
                self.grid.maintainActiveWindow(around: SIMD2<Float>(position.x, position.z))
            }

            DispatchQueue.main.async {
                self.isProcessing    = false
                self.frameCount      = self.frameCounter
                self.currentCameraXZ = SIMD2<Float>(position.x, position.z)
                self.updatePerformanceMetrics()
            }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        DispatchQueue.main.async { self.trackingState = state }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        updateFloor(anchors)
    }
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        updateFloor(anchors)
    }
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for a in anchors { horizontalPlaneY.removeValue(forKey: a.identifier) }
        recomputeFloor()
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        Logger.error("ARSession failed: \(error.localizedDescription)")
    }
    func sessionWasInterrupted(_ session: ARSession) {
        Logger.warning("ARSession interrupted")
    }
    func sessionInterruptionEnded(_ session: ARSession) {
        startSession()
        Logger.info("ARSession resumed")
    }
}
