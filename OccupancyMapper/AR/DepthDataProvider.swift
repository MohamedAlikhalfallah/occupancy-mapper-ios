import ARKit
import simd

class DepthDataProvider {

    func hasDepthData(in frame: ARFrame) -> Bool {
        frame.sceneDepth != nil
    }

    func depthMap(from frame: ARFrame) -> CVPixelBuffer? {
        frame.sceneDepth?.depthMap
    }

    func confidenceMap(from frame: ARFrame) -> CVPixelBuffer? {
        frame.sceneDepth?.confidenceMap
    }

    func measurements(from frame: ARFrame, step: Int = 8) -> [SensorMeasurement] {
        guard let sceneDepth = frame.sceneDepth else { return [] }

        let depthMap = sceneDepth.depthMap
        var measurements: [SensorMeasurement] = []

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width  = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return [] }
        let depthRowStride = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.stride
        let depthPointer = baseAddress.assumingMemoryBound(to: Float32.self)

        let confidenceMap = sceneDepth.confidenceMap
        var confidencePointer: UnsafeMutablePointer<UInt8>? = nil
        var confRowStride = width
        if let confBuffer = confidenceMap {
            CVPixelBufferLockBaseAddress(confBuffer, .readOnly)
            confidencePointer = CVPixelBufferGetBaseAddress(confBuffer)?
                .assumingMemoryBound(to: UInt8.self)
            confRowStride = CVPixelBufferGetBytesPerRow(confBuffer)
        }
        defer {
            if let confBuffer = confidenceMap {
                CVPixelBufferUnlockBaseAddress(confBuffer, .readOnly)
            }
        }


        let imageResolution = frame.camera.imageResolution
        let sx = Float(width)  / Float(imageResolution.width)
        let sy = Float(height) / Float(imageResolution.height)
        var intrinsics = frame.camera.intrinsics
        intrinsics[0][0] *= sx
        intrinsics[1][1] *= sy
        intrinsics[2][0] *= sx
        intrinsics[2][1] *= sy   
        let transform  = frame.camera.transform

        for row in stride(from: 0, to: height, by: step) {
            for col in stride(from: 0, to: width, by: step) {
                let depth = depthPointer[row * depthRowStride + col]
                guard depth >= Constants.minDepth, depth <= Constants.maxDepth else { continue }

                let rawConfidence = confidencePointer != nil ?
                    Float(confidencePointer![row * confRowStride + col]) / 2.0 : 0.5
                guard rawConfidence >= Constants.minConfidence else { continue }

                let worldPoint = MathUtils.unprojectPoint(
                    col: col, row: row, width: width, height: height,
                    depth: depth, intrinsics: intrinsics, transform: transform
                )
                measurements.append(SensorMeasurement(
                    position: worldPoint, distance: depth, confidence: rawConfidence
                ))
            }
        }
        return measurements
    }
}
