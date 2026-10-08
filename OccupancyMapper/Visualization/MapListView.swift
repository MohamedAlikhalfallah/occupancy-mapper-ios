import SwiftUI

struct MapListView: View {
    
    @ObservedObject var arManager: ARSessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [MapSession] = []
    @State private var sessionToDelete: UUID? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var loadedSessionName: String = ""
    @State private var showLoadedAlert: Bool = false
    
    var body: some View {
        NavigationView {
            Group {
                if sessions.isEmpty {
                    emptyView
                } else {
                    listView
                }
            }
            .navigationTitle("Saved Maps")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadSessions) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("Delete Map", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let id = sessionToDelete { deleteSession(id: id) }
                }
                Button("Cancel", role: .cancel) { sessionToDelete = nil }
            } message: {
                Text("Are you sure you want to delete this map?")
            }
            .alert("Map Loaded", isPresented: $showLoadedAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("\"\(loadedSessionName)\" loaded successfully!")
            }
        }
        .onAppear { loadSessions() }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60)).foregroundColor(.gray)
            Text("No Saved Maps").font(.title2).fontWeight(.semibold)
            Text("Scan a room and save your first map!")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
        }
    }
    
    private var listView: some View {
        List {
            ForEach(sessions) { session in
                let sid = session.id
                let sname = session.name
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            Color.blue.opacity(0.15)
                            Image(systemName: "map.fill")
                                .foregroundColor(.blue).font(.title2)
                        }
                        .frame(width: 50, height: 50).cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sname).font(.headline)
                            Text(session.formattedDate)
                                .font(.caption).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Label("\(session.occupiedCellCount) walls",
                                      systemImage: "square.fill")
                                    .font(.caption2).foregroundColor(.secondary)
                                if session.hasVolumetricData {
                                    Label("3D", systemImage: "cube")
                                        .font(.caption2).foregroundColor(.blue)
                                }
                                Label(session.mapSizeDescription,
                                      systemImage: "ruler")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: { loadSession(id: sid, name: sname) }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Load Map").fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Color.blue).cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            sessionToDelete = sid
                            showDeleteAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete").fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Color.red).cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func loadSessions() {
        sessions = MapImporter.shared.loadAllSessions()
    }
    
    private func loadSession(id: UUID, name: String) {
        guard let session = MapImporter.shared.loadSession(id: id) else {
            Logger.error("Failed to load session: \(id)")
            return
        }
        
        arManager.grid.reset()
        var cellUpdates: [(x: Int, y: Int, value: Int8)] = []
        cellUpdates.reserveCapacity(session.cellX.count)
        for i in 0..<session.cellX.count {
            cellUpdates.append((x: session.cellX[i],
                                y: session.cellY[i],
                                value: session.cellLogOdds[i]))
        }
        arManager.grid.setLogOdds(cellUpdates)
        
        arManager.grid3D.reset()
        if let vx = session.voxelX,
           let vy = session.voxelY,
           let vz = session.voxelZ,
           let vlog = session.voxelLogOdds {
            var voxelUpdates: [(x: Int, y: Int, z: Int, value: Int8)] = []
            voxelUpdates.reserveCapacity(vx.count)
            for i in 0..<vx.count {
                voxelUpdates.append((x: vx[i], y: vy[i], z: vz[i], value: vlog[i]))
            }
            arManager.grid3D.setLogOdds(voxelUpdates)
            Logger.info("Restored \(voxelUpdates.count) voxels")
        }
        
        DispatchQueue.main.async {
            arManager.currentSession = session
            arManager.frameCount    += 1
            loadedSessionName        = name
            showLoadedAlert          = true
        }
        Logger.info("Session loaded: \(name)")
    }
    
    private func deleteSession(id: UUID) {
        try? MapImporter.shared.deleteSession(id: id)
        sessionToDelete = nil
        loadSessions()
    }
}
