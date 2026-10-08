import SwiftUI
import ARKit
import RealityKit

struct ContentView: View {
    
    @StateObject private var arManager = ARSessionManager()
    @State private var showMap = true
    @State private var showDebug = true
    @State private var mapOpacity = 0.9
    @State private var showSaveSheet = false
    @State private var showMapList = false
    @State private var showResetAlert = false
    @State private var show3DView = false
    @State private var mapPanelSize: CGFloat = 300
    
    var body: some View {
        ZStack {
            
            ARViewContainer(arManager: arManager)
                .edgesIgnoringSafeArea(.all)
            
            if showMap {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Group {
                            if show3DView {
                                MapView3D(arManager: arManager)
                                    .frame(width: mapPanelSize, height: mapPanelSize)
                            } else {
                                MapView(arManager: arManager)
                                    .frame(width: mapPanelSize, height: mapPanelSize)
                            }
                        }
                        .opacity(mapOpacity)
                        .cornerRadius(12)
                        .padding()
                    }
                }
            }
            
            VStack {
                
                HStack {
                    Text("Frames: \(arManager.frameCount)")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding()
                    
                    Spacer()
                    
                    Button(action: { showMapList = true }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    
                    Button(action: { showMap.toggle() }) {
                        Image(systemName: showMap ? "map.fill" : "map")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        show3DView.toggle()
                        arManager.is3DEnabled = show3DView
                    }) {
                        Text(show3DView ? "3D" : "2D")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(show3DView ? Color.blue.opacity(0.8) : Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        switch mapPanelSize {
                        case 250: mapPanelSize = 300
                        case 300: mapPanelSize = 380
                        default:  mapPanelSize = 250
                        }
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    
                    Button(action: { showDebug.toggle() }) {
                        Image(systemName: showDebug ? "info.circle.fill" : "info.circle")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    .padding(.trailing)
                }
                
                if showDebug {
                    HStack {
                        DebugOverlay(arManager: arManager)
                            .padding(.leading)
                        Spacer()
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    
                    Button(action: { showResetAlert = true }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        arManager.pauseSession()
                        showSaveSheet = true
                    }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(10)
                    }
                    
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(.white)
                        Slider(value: $mapOpacity, in: 0.1...1.0)
                            .frame(width: 100)
                        Image(systemName: "circle.fill")
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            arManager.startSession()
        }
        .onDisappear {
            arManager.stopSession()
        }
        .sheet(isPresented: $showSaveSheet, onDismiss: {
            arManager.resumeSession()
        }) {
            SaveMapSheet(arManager: arManager)
        }
        .sheet(isPresented: $showMapList) {
            MapListView(arManager: arManager)
        }
        .alert("Reset Map", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                arManager.resetMap()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear the current map? This cannot be undone.")
        }
    }
}


struct ARViewContainer: UIViewRepresentable {
    
    let arManager: ARSessionManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero,
                           cameraMode: .ar,
                           automaticallyConfigureSession: false)
        arView.session = arManager.session
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}
