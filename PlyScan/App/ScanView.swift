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
    let isActive: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = sessionManager.session
        if isActive {
            sessionManager.startSession()
        }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        guard isActive else { return }
        if let frame = sessionManager.session.currentFrame {
            switch frame.camera.trackingState {
            case .normal:
                break
            default:
                sessionManager.startSession()
            }
        } else {
            // No frame yet; ensure session is running
            sessionManager.startSession()
        }
    }
}

struct ScanView: View {

    @StateObject var sessionManager = ARSessionManager()
    @State private var isScanning = false
    @State private var showingUploadStatus = false
    @State private var uploadMessage = ""
    @State private var isViewActive = false

    var body: some View {
        ZStack {
            if sessionManager.scanMode == .trueDepth {

                TrueDepthView(scanner: sessionManager.trueDepthScanner)
                    .edgesIgnoringSafeArea(.all)

            } else {

                ARViewContainer(sessionManager: sessionManager, isActive: isViewActive)
                    .edgesIgnoringSafeArea(.all)
            }

            VStack {
                // Mode Selector
                Picker("Scan Mode", selection: Binding(
                    get: { sessionManager.scanMode },
                    set: { newMode in
                        if !isScanning {
                            sessionManager.changeScanMode(to: newMode)
                        }
                    }
                )) {
                    Text(sessionManager.isLiDARAvailable ? "LiDAR" : "LiDAR ❌")
                        .tag(ARSessionManager.ScanMode.lidar)
                    Text(sessionManager.isTrueDepthAvailable ? "TrueDepth" : "TrueDepth ❌")
                        .tag(ARSessionManager.ScanMode.trueDepth)
                    Text("RGB")
                        .tag(ARSessionManager.ScanMode.rgb)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .disabled(isScanning)
                
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

                HStack(spacing: 16) {
                    Button(action: {
                        isScanning = true
                        sessionManager.setScanning(true)
                    }) {
                        Text("Start Scan")
                            .padding()
                            .background(isScanning ? Color.gray.opacity(0.3) : Color.green.opacity(0.7))
                            .cornerRadius(10)
                    }
                    .disabled(isScanning)
                    
                    Button(action: {
                        isScanning = false
                        sessionManager.setScanning(false)
                        uploadScan()
                    }) {
                        Text("Stop & Upload")
                            .padding()
                            .background(isScanning ? Color.red.opacity(0.7) : Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    .disabled(!isScanning)
                }
                .padding()
            }
        }
        .onAppear {
            isViewActive = true
        }
        .onDisappear {
            isViewActive = false
            if isScanning {
                isScanning = false
                sessionManager.setScanning(false)
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
        
        let originalPLY = scanFolder.appendingPathComponent("sparse_cloud.ply")
        
        // Check if original file exists
        guard FileManager.default.fileExists(atPath: originalPLY.path) else {
            NSLog("❌ PLY file not found at path")
            uploadMessage = "PLY file not found"
            showingUploadStatus = true
            return
        }
        
        // Generate unique filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let uniqueFilename = "scan_\(timestamp).ply"
        
        let uniquePLY = scanFolder.appendingPathComponent(uniqueFilename)
        
        // Rename file to unique name
        do {
            try FileManager.default.moveItem(at: originalPLY, to: uniquePLY)
            NSLog("✅ Renamed to: %@", uniqueFilename)
        } catch {
            NSLog("⚠️ Failed to rename file: %@", error.localizedDescription)
            // Continue with original name if rename fails
        }
        
        let plyURL = FileManager.default.fileExists(atPath: uniquePLY.path) ? uniquePLY : originalPLY
        
        NSLog("🔍 Using PLY file: %@", plyURL.lastPathComponent)
        NSLog("✅ PLY file exists, starting upload...")
        
        uploadMessage = "Uploading and processing...\nThis may take 5-15 seconds."
        showingUploadStatus = true
        
        UploadService.shared.uploadPLY(fileURL: plyURL, scanMode: sessionManager.scanMode) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    var message = """
                    ✅ Upload Successful!
                    
                    Width: \(String(format: "%.3f", response.dimensions.width)) m
                    Length: \(String(format: "%.3f", response.dimensions.length)) m
                    Height: \(String(format: "%.3f", response.dimensions.height)) m
                    """
                    
                    // Add confidence score if available (reference-based)
                    if let confidence = response.confidence {
                        message += """
                        
                        
                        Confidence: \(Int(confidence))%
                        (According to prediction model)
                        """
                    }
                    // Otherwise show quality metrics
                    else if let metrics = response.qualityMetrics {
                        message += """
                        
                        
                        Quality Score: \(Int(metrics.qualityScore))%
                        Point Count: \(metrics.pointCount)
                        """
                    }
                    
                    uploadMessage = message
                    
                    // Save to library
                    let record = ScanRecord(
                        filename: response.originalFilename,
                        dimensions: ScanRecord.Dimensions(
                            width: response.dimensions.width,
                            height: response.dimensions.height,
                            length: response.dimensions.length
                        ),
                        confidence: response.confidence,
                        qualityMetrics: response.qualityMetrics.map { metrics in
                            ScanRecord.QualityMetrics(
                                pointCount: metrics.pointCount,
                                ransacInlierRatio: metrics.ransacInlierRatio,
                                aspectRatio: metrics.aspectRatio,
                                qualityScore: metrics.qualityScore
                            )
                        },
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

