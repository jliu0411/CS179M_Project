//
//  ScanView.swift
//  PlyScan
//
//  Created by Dongyeon Kim on 2/25/26.
//

import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {

    let sessionManager: ARSessionManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = sessionManager.session
        sessionManager.startSession()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

struct ScanView: View {

    @StateObject var sessionManager = ARSessionManager()
    @State private var isScanning = false
    @State private var showingUploadStatus = false
    @State private var uploadMessage = ""

    var body: some View {
        ZStack {
            if sessionManager.scanMode == .trueDepth {

                TrueDepthView(scanner: sessionManager.trueDepthScanner)
                    .edgesIgnoringSafeArea(.all)

            } else {

                ARViewContainer(sessionManager: sessionManager)
                    .edgesIgnoringSafeArea(.all)
            }

            VStack {
                Text({
                    switch sessionManager.scanMode {
                    case .lidar: return "Mode: LiDAR"
                    case .trueDepth: return "Mode: TrueDepth"
                    case .rgb: return "Mode: RGB"
                    }
                }())
                .padding(6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                
                Spacer()
                
                if isScanning {
                    CoverageRingView(coverage: sessionManager.coveragePercent)
                }
                
                if sessionManager.coveragePercent < 40 && isScanning {
                    Text("Move around object")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                else if sessionManager.coveragePercent < 80 && isScanning {
                    Text("Almost full circle")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                else if isScanning {
                    Text("Great coverage!")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                if isScanning {
                    Text("Frames: \(sessionManager.frameCount)")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    Text("Height Levels: \(sessionManager.heightCoverage)/2")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }

                Button(action: {
                    if isScanning {
                        // Stop and upload
                        isScanning = false
                        sessionManager.setScanning(false)
                        uploadScan()
                    } else {
                        isScanning = true
                        sessionManager.setScanning(true)
                    }
                }) {
                    Text(isScanning ? "Stop & Upload" : "Start Scan")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .alert("Upload Status", isPresented: $showingUploadStatus) {
            Button("OK") { }
        } message: {
            Text(uploadMessage)
        }
    }
    
    private func uploadScan() {
        NSLog("🚀 uploadScan() called")
        
        guard let scanFolder = sessionManager.lastScanFolder else {
            NSLog("❌ No scan folder found")
            uploadMessage = "No scan folder found"
            showingUploadStatus = true
            return
        }
        
        NSLog("📁 Scan folder: %@", scanFolder.path)
        
        let plyURL = scanFolder.appendingPathComponent("sparse_cloud.ply")
        
        NSLog("🔍 Checking for PLY at: %@", plyURL.path)
        
        guard FileManager.default.fileExists(atPath: plyURL.path) else {
            NSLog("❌ PLY file not found at path")
            uploadMessage = "PLY file not found"
            showingUploadStatus = true
            return
        }
        
        NSLog("✅ PLY file exists, starting upload...")
        
        uploadMessage = "Uploading..."
        showingUploadStatus = true
        
        UploadService.shared.uploadPLY(fileURL: plyURL, scanMode: sessionManager.scanMode) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    uploadMessage = """
                    ✅ Upload Successful!
                    
                    Width: \(String(format: "%.3f", response.dimensions.width)) m
                    Length: \(String(format: "%.3f", response.dimensions.length)) m
                    Height: \(String(format: "%.3f", response.dimensions.height)) m
                    """
                    
                    // Save to library
                    let record = ScanRecord(
                        filename: response.originalFilename,
                        dimensions: ScanRecord.Dimensions(
                            width: response.dimensions.width,
                            height: response.dimensions.height,
                            length: response.dimensions.length
                        ),
                        scanMode: {
                            switch sessionManager.scanMode {
                            case .lidar: return "LiDAR"
                            case .trueDepth: return "TrueDepth"
                            case .rgb: return "RGB"
                            }
                        }(),
                        localPath: plyURL.path
                    )
                    LibraryManager.shared.addRecord(record)
                    
                case .failure(let error):
                    let errorMsg = error.localizedDescription
                    NSLog("❌ Upload failed: %@", errorMsg)
                    uploadMessage = "❌ Upload failed:\n\n\(errorMsg)\n\nServer: http://192.168.1.47:8000"
                }
                showingUploadStatus = true
            }
        }
    }
}
