import SwiftUI
import ARKit
import Combine

struct DebugOverlay: View {
    
    @ObservedObject var arManager: ARSessionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            HStack(spacing: 6) {
                Text("DEBUG")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                Text(arManager.is3DEnabled ? "3D" : "2D")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(arManager.is3DEnabled ? .cyan : .white)
            }
            
            Divider().background(Color.white.opacity(0.3))
            
            debugRow(icon: "speedometer", label: "FPS",
                     value: String(format: "%.0f", arManager.currentFPS),
                     color: fpsColor)
            debugRow(icon: "memorychip", label: "RAM",
                     value: String(format: "%.1f MB", arManager.memoryMB),
                     color: memoryColor)
            debugRow(icon: "camera.fill", label: "Frames",
                     value: "\(arManager.frameCount)", color: .white)
            
            if arManager.is3DEnabled {
                debugRow(icon: "cube", label: "Voxels",
                         value: "\(arManager.voxelCount)", color: .white)
                debugRow(icon: "cube.fill", label: "Walls",
                         value: "\(arManager.voxelOccupiedCount)", color: .white)
                debugRow(icon: "square.dashed", label: "Free",
                         value: "\(arManager.voxelFreeCount)", color: .white)
                debugRow(icon: "location.fill", label: "Track",
                         value: arManager.trackingText, color: trackingColor)
                debugRow(icon: "ruler", label: "Res",
                         value: String(format: "%.0fcm", arManager.grid3D.resolution * 100),
                         color: .white)
                debugRow(icon: "square.stack.3d.up.fill", label: "Tiles",
                         value: "\(arManager.resident3DTiles) RAM / \(arManager.evicted3DTiles) disk",
                         color: .white)
            } else {
                debugRow(icon: "square.grid.2x2", label: "Cells",
                         value: "\(arManager.observedCellCount)", color: .white)
                debugRow(icon: "square.fill", label: "Walls",
                         value: "\(arManager.occupiedCellCount)", color: .white)
                debugRow(icon: "square", label: "Free",
                         value: "\(arManager.freeCellCount)", color: .white)
                debugRow(icon: "location.fill", label: "Track",
                         value: arManager.trackingText, color: trackingColor)
                debugRow(icon: "ruler", label: "Res",
                         value: String(format: "%.0fcm", arManager.grid.resolution * 100),
                         color: .white)
                debugRow(icon: "arrow.down.to.line", label: "Floor",
                         value: arManager.floorY.map { String(format: "%.2f m", $0) } ?? "—",
                         color: arManager.floorY == nil ? .yellow : .green)
                debugRow(icon: "square.stack.3d.up.fill", label: "Tiles",
                         value: "\(arManager.residentTiles) RAM / \(arManager.evictedTiles) disk",
                         color: .white)
            }
            
            debugRow(icon: "bolt.fill", label: "Skip",
                     value: String(format: "%.0f%%", arManager.skipRatio),
                     color: skipColor)
            
            if let session = arManager.currentSession {
                Divider().background(Color.white.opacity(0.3))
                debugRow(icon: "map.fill", label: "Map",
                         value: session.name, color: .cyan)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.75))
        .cornerRadius(10)
    }
    
    private func debugRow(icon: String, label: String,
                          value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
                .frame(width: 12)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 40, alignment: .leading)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
        }
    }
    
    private var fpsColor: Color {
        if arManager.currentFPS >= 30 { return .green }
        if arManager.currentFPS >= 15 { return .yellow }
        return .red
    }
    private var memoryColor: Color {
        if arManager.memoryMB < 500 { return .green }
        if arManager.memoryMB < 700 { return .yellow }
        return .red
    }
    private var skipColor: Color {
        if arManager.skipRatio >= 50 { return .green }
        if arManager.skipRatio >= 20 { return .yellow }
        return .white
    }
    private var trackingColor: Color {
        switch arManager.trackingState {
        case .normal:       return .green
        case .notAvailable: return .red
        case .limited:      return .yellow
        }
    }
}
