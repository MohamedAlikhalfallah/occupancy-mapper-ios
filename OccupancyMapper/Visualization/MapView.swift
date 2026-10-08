import SwiftUI

struct MapView: View {
    
    @ObservedObject var arManager: ARSessionManager
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(Color(white: 0.18)))
                drawGrid(context: context, size: size)
            }
            .id(arManager.frameCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.18))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .overlay(legend, alignment: .topLeading)
    }
    
    private var legend: some View {
        VStack(alignment: .leading, spacing: 3) {
            legendRow(color: .white,             label: "Free")
            legendRow(color: .black,             label: "Occupied")
            legendRow(color: Color(white: 0.55), label: "Unknown")
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
                .overlay(RoundedRectangle(cornerRadius: 1)
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5))
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
    }
    
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let grid = arManager.grid
        let cells = grid.observedCellsWithCoords()
        guard !cells.isEmpty else { return }
        
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min
        for c in cells {
            if c.x < minX { minX = c.x }
            if c.x > maxX { maxX = c.x }
            if c.y < minY { minY = c.y }
            if c.y > maxY { maxY = c.y }
        }
        
        let cols = CGFloat(maxX - minX + 1)
        let rows = CGFloat(maxY - minY + 1)
        let margin: CGFloat = 10
        let cellPx = min((size.width  - 2 * margin) / cols,
                         (size.height - 2 * margin) / rows)
        let drawW = cellPx * cols
        let drawH = cellPx * rows
        let offsetX = (size.width  - drawW) / 2
        let offsetY = (size.height - drawH) / 2
        
        func pixel(_ cx: Int, _ cy: Int) -> CGPoint {
            CGPoint(x: offsetX + CGFloat(cx - minX) * cellPx,
                    y: offsetY + CGFloat(cy - minY) * cellPx)
        }
        
        for entry in cells {
            guard entry.cell.isObserved else { continue }
            let p = pixel(entry.x, entry.y)
            let rect = CGRect(x: p.x, y: p.y, width: cellPx, height: cellPx)
            context.fill(Path(rect), with: .color(colorForCell(entry.cell)))
        }
        
        if let cam = grid.worldToGrid(arManager.currentCameraXZ) {
            let p = pixel(cam.x, cam.y)
            let centre = CGPoint(x: p.x + cellPx / 2, y: p.y + cellPx / 2)
            let s: CGFloat = max(7, cellPx * 1.4)
            let dot = CGRect(x: centre.x - s/2, y: centre.y - s/2, width: s, height: s)
            context.fill(Path(ellipseIn: dot), with: .color(.red))
            context.stroke(Path(ellipseIn: dot), with: .color(.white), lineWidth: 1)
        }
    }
    
    private func colorForCell(_ cell: GridCell) -> Color {
        if cell.isOccupied { return .black }
        else if cell.isFree { return .white }
        else { return Color(white: 0.55) }
    }
}
