# OccupancyMapper – Probabilistic Occupancy Mapping on the iPhone

Real-time 2D and 3D occupancy mapping on a LiDAR iPhone, built entirely on the device
without external computers or infrastructure.

Developed as my bachelor thesis *"Development of a System for Probabilistic Occupancy
Mapping with iOS"* at the University of Duisburg-Essen (2026).

## What it does

A robot or a person walking through a building needs to know which space is free,
which is occupied, and which has not been seen yet. OccupancyMapper builds exactly
this kind of map live while you walk through a room with an iPhone:

- **2D occupancy grid** (5 cm cells) – a floor plan of walls and obstacles, with the
  floor and ceiling recognised as free space by their height.
- **3D voxel grid** (10 cm voxels) – the full volume of the room, including furniture,
  floor and ceiling.
- Every cell holds a **probability** (stored as log-odds), updated with each new
  measurement, so the map corrects itself when objects are moved.

## How it works

1. **Sensing** – ARKit provides the device pose and a LiDAR depth image for each frame.
   Depth samples are filtered by range (0.2–5 m) and confidence.
2. **Unprojection** – each depth pixel is turned into a 3D world point using the
   camera intrinsics (scaled to the depth-map resolution) and the device pose.
3. **Ray casting** – a ray from the camera to each point marks the cells along it as
   free and the end cell as occupied (Bresenham in 2D and 3D).
4. **Bayesian update** – cells are updated in log-odds form with clamped values,
   stored in one byte per cell.
5. **Bounded memory** – the map is stored sparsely in blocks; blocks more than ~12 m
   away are streamed to disk and reloaded on return, so memory stays bounded however
   large the explored area becomes.
6. **Visualisation** – live 2D map and 3D voxel view, plus a statistics overlay.

## Results (iPhone 14 Pro Max)

| | 2D map | 3D map |
|---|---|---|
| Processing time per frame (median / 95th pct.) | 1.97 ms / 2.98 ms | 2.81 ms / 4.53 ms |
| Frames over the 60 Hz budget (16.7 ms) | 0 | 0 |
| Map memory | ≈ 0.06 MB | ≈ 0.26 MB |
| Room dimensions vs. tape measure | within 2 cm | width/height within 1 cm |

Maps can be saved, reloaded and extended; a moving-object test showed that removed
objects are cleared from the map within seconds.

## Tech stack

Swift · SwiftUI · ARKit (scene depth, world tracking) · LiDAR · SIMD ·
Grand Central Dispatch · JSON persistence

## Project structure

| Folder | Content |
|---|---|
| `App/` | App entry point and main view |
| `AR/` | ARKit session, depth extraction and unprojection, frame processing |
| `Mapping/` | 2D/3D grids (sparse blocks + tile streaming), ray casting |
| `Models/` | Cell, voxel, measurement and saved-map types |
| `Persistence/` | Saving/loading maps and the on-disk tile store |
| `Performance/` | Motion gate, frame-rate and memory monitoring, CSV logging |
| `Utils/` | Constants, log-odds arithmetic, math helpers |
| `Visualization/` | 2D map view, 3D voxel view, overlay, save/list sheets |

## Build and run

Requirements: iPhone or iPad **with LiDAR** (iPhone 12 Pro or newer Pro model),
Xcode 26, iOS 26.4 or newer. The app does not run in the simulator.

1. Open `OccupancyMapper.xcodeproj` in Xcode.
2. Under *Signing & Capabilities*, select your own team.
3. Select your device and press *Run*.

## Limitations and next steps

- Glass returns almost no LiDAR depth and appears as an opening.
- Maps cannot yet be aligned across separate sessions (relocalisation).
- The resolution is set at build time, not in the app.

## Author

Mohamed Ali Khalfallah – B.Sc. thesis, University of Duisburg-Essen
