import SwiftUI

struct SaveMapSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var arManager: ARSessionManager
    
    @State private var mapName: String = ""
    @State private var isSaved: Bool = false
    @State private var showError: Bool = false
    @State private var saveMode: SaveMode = .new
    
    enum SaveMode { case new, update }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                
                ZStack {
                    Color.black
                    MapView(arManager: arManager)
                        .frame(width: 250, height: 250)
                }
                .frame(width: 260, height: 260)
                .cornerRadius(16)
                .padding(.top)
                
                HStack(spacing: 20) {
                    statView(title: "Observed",
                             value: "\(arManager.observedCellCount)")
                    statView(title: "Occupied",
                             value: "\(arManager.occupiedCellCount)")
                    statView(title: "Free",
                             value: "\(arManager.freeCellCount)")
                }
                .padding(.horizontal)
                
                if arManager.currentSession != nil {
                    Picker("Save Mode", selection: $saveMode) {
                        Text("Update Current Map").tag(SaveMode.update)
                        Text("Save as New Map").tag(SaveMode.new)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
                if saveMode == .new {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Map Name").font(.headline)
                        TextField("e.g. Living Room, Office...", text: $mapName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal)
                } else if let session = arManager.currentSession {
                    HStack {
                        Image(systemName: "map.fill").foregroundColor(.blue)
                        Text("Updating: \(session.name)")
                            .font(.headline).foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Button(action: saveMap) {
                    HStack {
                        Image(systemName: isSaved ? "checkmark.circle.fill"
                                                  : "square.and.arrow.down")
                        Text(isSaved ? "Saved!" : saveButtonTitle)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSaved ? Color.green : Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .disabled(saveMode == .new && mapName.isEmpty || isSaved)
                
                Button(action: saveToPhotos) {
                    HStack {
                        Image(systemName: "photo")
                        Text("Export as Image")
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .navigationTitle("Save Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error saving map", isPresented: $showError) {
                Button("OK") {}
            }
            .onAppear {
                if arManager.currentSession != nil { saveMode = .update }
            }
        }
    }
    
    private var saveButtonTitle: String {
        saveMode == .update ? "Update Map" : "Save New Map"
    }
    
    private func statView(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func saveMap() {
        DispatchQueue.main.async {
            do {
                if saveMode == .update, let existing = arManager.currentSession {
                    let updated = MapSession(updating: existing,
                                             grid: arManager.grid,
                                             grid3D: arManager.grid3D)
                    try MapExporter.shared.save(updated)
                    arManager.currentSession = updated
                } else {
                    let session = MapSession(name: mapName,
                                             grid: arManager.grid,
                                             grid3D: arManager.grid3D)
                    try MapExporter.shared.save(session)
                    arManager.currentSession = session
                }
                withAnimation { isSaved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            } catch {
                Logger.error("Failed to save: \(error.localizedDescription)")
                showError = true
            }
        }
    }
    
    private func saveToPhotos() {
        let name = mapName.isEmpty
            ? (arManager.currentSession?.name ?? "OccupancyMap") : mapName
        DispatchQueue.global(qos: .userInitiated).async {
            MapExporter.shared.saveImageToPhotos(from: arManager.grid, name: name)
        }
    }
}
