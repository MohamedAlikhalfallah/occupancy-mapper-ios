import SwiftUI
import simd

struct MapView3D: View {
    
    @ObservedObject var arManager: ARSessionManager
    
    @State private var rotationAngle: Double = 0.7
    @State private var tiltAngle: Double = 0.5
    @State private var showFreeSpace: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawScene(context: context, size: size)
            }
            .id(arManager.frameCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(white: 0.12), Color(white: 0.03)],
                           startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .overlay(heightLegend, alignment: .topLeading)
        .overlay(controls, alignment: .bottomLeading)
        .overlay(
            Text("Drag to rotate")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .padding(6),
            alignment: .bottomTrailing
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    rotationAngle = 0.7 + Double(value.translation.width) / 100
                    tiltAngle     = max(0.15, min(1.2,
                                    0.5 + Double(value.translation.height) / 200))
                }
        )
    }
    
    private var heightLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("HEIGHT")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            legendRow(color: colorForHeight(1.0), label: "High")
            legendRow(color: colorForHeight(0.5), label: "Mid")
            legendRow(color: colorForHeight(0.0), label: "Low")
            legendRow(color: Color(red: 0.2, green: 0.8, blue: 0.4), label: "Free")
        }
        .padding(6)
        .background(Color.black.opacity(0.55))
        .cornerRadius(6)
        .padding(6)
    }
    
    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1).fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
    }
    
    private var controls: some View {
        Button(action: { showFreeSpace.toggle() }) {
            Text(showFreeSpace ? "Hide floor" : "Show floor")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 6).padding(.vertical, 4)
                .background(Color.black.opacity(0.55))
                .cornerRadius(5)
        }
        .padding(6)
    }
    
    private func project(_ vx: Double, _ vy: Double, _ vz: Double,
                         centerX: CGFloat, centerY: CGFloat, scale: CGFloat,
                         cosR: Double, sinR: Double,
                         cosT: Double, sinT: Double) -> (point: CGPoint, depth: Double) {
        let rx = vx * cosR - vz * sinR
        let rz = vx * sinR + vz * cosR
        let ry    = vy * cosT - rz * sinT
        let depth = vy * sinT + rz * cosT
        return (CGPoint(x: centerX + CGFloat(rx) * scale,
                        y: centerY - CGFloat(ry) * scale), depth)
    }
    
    private func drawScene(context: GraphicsContext, size: CGSize) {
        let grid = arManager.grid3D
        let voxels = grid.observedVoxelsWithCoords()
        guard !voxels.isEmpty else { return }
        
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min
        var minZ = Int.max, maxZ = Int.min
        var occMinY = Int.max, occMaxY = Int.min
        var freeHeightHistogram: [Int: Int] = [:]
        
        for v in voxels {
            minX = min(minX, v.x); maxX = max(maxX, v.x)
            minY = min(minY, v.y); maxY = max(maxY, v.y)
            minZ = min(minZ, v.z); maxZ = max(maxZ, v.z)
            if v.voxel.isOccupied {
                occMinY = min(occMinY, v.y); occMaxY = max(occMaxY, v.y)
            }
            if v.voxel.isFree {
                freeHeightHistogram[v.y, default: 0] += 1
            }
        }
        
        let modalFreeY = freeHeightHistogram.max(by: { $0.value < $1.value })?.key
        if occMinY > occMaxY { occMinY = minY; occMaxY = maxY }
        let heightSpan = max(occMaxY - occMinY, 1)
        
        let cX = Double(minX + maxX) / 2.0
        let cY = Double(minY + maxY) / 2.0
        let cZ = Double(minZ + maxZ) / 2.0
        
        let extent = Double(max(max(maxX - minX, maxZ - minZ), maxY - minY)) + 4.0
        let scale = min(size.width, size.height) / CGFloat(extent) * 0.85
        
        let centerX = size.width / 2
        let centerY = size.height / 2 + size.height * 0.08
        
        let cosR = cos(rotationAngle), sinR = sin(rotationAngle)
        let cosT = cos(tiltAngle),     sinT = sin(tiltAngle)
        
        let floorLevel = Double(modalFreeY ?? minY)
        
        if showFreeSpace {
            drawFloorGrid(context: context, voxels: voxels, floorLevel: floorLevel,
                          cX: cX, cY: cY, cZ: cZ,
                          centerX: centerX, centerY: centerY, scale: scale,
                          cosR: cosR, sinR: sinR, cosT: cosT, sinT: sinT)
        }
        
        struct Cube { let depth: Double; let x: Int; let y: Int; let z: Int; let hr: Double }
        var cubes: [Cube] = []
        cubes.reserveCapacity(voxels.count / 4)
        
        for v in voxels {
            guard v.voxel.isOccupied else { continue }
            let vx = Double(v.x) - cX
            let vy = Double(v.y) - cY
            let vz = Double(v.z) - cZ
            let rz = vx * sinR + vz * cosR
            let depth = vy * sinT + rz * cosT
            let hr = Double(v.y - occMinY) / Double(heightSpan)
            cubes.append(Cube(depth: depth, x: v.x, y: v.y, z: v.z, hr: hr))
        }
        cubes.sort { $0.depth < $1.depth }
        
        for c in cubes {
            drawCube(context: context, x: c.x, y: c.y, z: c.z, heightRatio: c.hr,
                     cX: cX, cY: cY, cZ: cZ,
                     centerX: centerX, centerY: centerY, scale: scale,
                     cosR: cosR, sinR: sinR, cosT: cosT, sinT: sinT)
        }
    }
    
    private func drawFloorGrid(context: GraphicsContext,
                               voxels: [(x: Int, y: Int, z: Int, voxel: VoxelCell)],
                               floorLevel: Double,
                               cX: Double, cY: Double, cZ: Double,
                               centerX: CGFloat, centerY: CGFloat, scale: CGFloat,
                               cosR: Double, sinR: Double, cosT: Double, sinT: Double) {
        let bandHalfHeight = 2
        let floorY = Int(floorLevel.rounded())
        
        var freeXZ = Set<[Int]>()
        for v in voxels where v.voxel.isFree {
            guard abs(v.y - floorY) <= bandHalfHeight else { continue }
            freeXZ.insert([v.x, v.z])
        }
        guard !freeXZ.isEmpty else { return }
        
        let fy = floorLevel - cY
        
        for cell in freeXZ {
            let x = cell[0], z = cell[1]
            let vx = Double(x) - cX
            let vz = Double(z) - cZ
            
            let p0 = project(vx,       fy, vz,       centerX: centerX, centerY: centerY, scale: scale, cosR: cosR, sinR: sinR, cosT: cosT, sinT: sinT).point
            let p1 = project(vx + 1.0, fy, vz,       centerX: centerX, centerY: centerY, scale: scale, cosR: cosR, sinR: sinR, cosT: cosT, sinT: sinT).point
            let p2 = project(vx + 1.0, fy, vz + 1.0, centerX: centerX, centerY: centerY, scale: scale, cosR: cosR, sinR: sinR, cosT: cosT, sinT: sinT).point
            let p3 = project(vx,       fy, vz + 1.0, centerX: centerX, centerY: centerY, scale: scale, cosR: cosR, sinR: sinR, cosT: cosT, sinT: sinT).point
            
            var path = Path()
            path.move(to: p0); path.addLine(to: p1)
            path.addLine(to: p2); path.addLine(to: p3); path.closeSubpath()
            
            context.fill(path, with: .color(Color(red: 0.12, green: 0.45, blue: 0.25).opacity(0.45)))
            context.stroke(path, with: .color(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.35)), lineWidth: 0.4)
        }
    }
    
    private func drawCube(context: GraphicsContext, x: Int, y: Int, z: Int,
                          heightRatio: Double,
                          cX: Double, cY: Double, cZ: Double,
                          centerX: CGFloat, centerY: CGFloat, scale: CGFloat,
                          cosR: Double, sinR: Double, cosT: Double, sinT: Double) {
        let vx = Double(x) - cX
        let vy = Double(y) - cY
        let vz = Double(z) - cZ
        let s = 1.0
        
        func P(_ dx: Double, _ dy: Double, _ dz: Double) -> CGPoint {
            project(vx + dx, vy + dy, vz + dz,
                    centerX: centerX, centerY: centerY, scale: scale,
                    cosR: cosR, sinR: sinR, cosT: cosT, sinT: sinT).point
        }
        
        let base = colorForHeight(heightRatio)
        let edge = Color.black.opacity(0.4)
        
        var top = Path()
        top.move(to: P(0, s, 0)); top.addLine(to: P(s, s, 0))
        top.addLine(to: P(s, s, s)); top.addLine(to: P(0, s, s)); top.closeSubpath()
        context.fill(top, with: .color(base)); context.stroke(top, with: .color(edge), lineWidth: 0.4)
        
        var right = Path()
        right.move(to: P(0, 0, s)); right.addLine(to: P(s, 0, s))
        right.addLine(to: P(s, s, s)); right.addLine(to: P(0, s, s)); right.closeSubpath()
        context.fill(right, with: .color(base.opacity(0.55))); context.stroke(right, with: .color(edge), lineWidth: 0.4)
        
        var left = Path()
        left.move(to: P(s, 0, 0)); left.addLine(to: P(s, 0, s))
        left.addLine(to: P(s, s, s)); left.addLine(to: P(s, s, 0)); left.closeSubpath()
        context.fill(left, with: .color(base.opacity(0.78))); context.stroke(left, with: .color(edge), lineWidth: 0.4)
    }
    
    private func colorForHeight(_ ratio: Double) -> Color {
        let clamped = min(max(ratio, 0), 1)
        return Color(hue: max(0, 0.66 - clamped * 0.66), saturation: 0.85, brightness: 0.95)
    }
}
