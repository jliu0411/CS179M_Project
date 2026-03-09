//
//  ARSessionManager.swift
//  PlyScan
//

import Foundation
import ARKit
import Combine
import AVFoundation

class ARSessionManager: NSObject, ObservableObject, ARSessionDelegate {
    
    // MARK: - Core Managers
    let session = ARSession()
    private let captureManager = FrameCaptureManager()
    private let fileService = FileManagerService()
    private let pointQueue = DispatchQueue(label: "pointcloud.queue")
    
    let trueDepthScanner = TrueDepthScanner()
    
    // MARK: - Scan State
    private var isScanning = false
    private var scanFolderURL: URL?
    
    // Expose last scan folder for upload
    var lastScanFolder: URL? {
        return scanFolderURL
    }
    
    private var capturedFrames: [CaptureFrame] = []
    private var accumulatedPoints: [SIMD3<Float>] = []
    private var scanPositions: [SIMD3<Float>] = []
    private var heightLevels: Set<Int> = []
    
    // MARK: - Published UI State
    @Published var frameCount: Int = 0
    @Published var coveragePercent: Int = 0
    @Published var heightCoverage: Int = 0
    @Published var currentTransform: simd_float4x4?
    @Published var scanMode: ScanMode = .rgb
    @Published var isLiDARAvailable: Bool = false
    @Published var isTrueDepthAvailable: Bool = false
    
    // MARK: - Frame Metadata
    struct CaptureFrame: Codable {
        let imageName: String
        let transform: [Float]
        let intrinsics: [Float]
    }
    
    enum ScanMode {
        case lidar
        case trueDepth
        case rgb
    }
    
    // MARK: - Init
    override init() {
        super.init()

        session.delegate = self

        detectScanMode()

        trueDepthScanner.onDepthFrame = { [weak self] depth in
            self?.processTrueDepth(depth)
        }

        // Start camera preview immediately
        if scanMode == .trueDepth {
            trueDepthScanner.start()
        }
    }
    
    // MARK: - AR Session
    func startSession() {

        let configuration = ARWorldTrackingConfiguration()

        configuration.planeDetection = []
        configuration.environmentTexturing = .none

        if scanMode == .lidar {

            configuration.frameSemantics = [
                .sceneDepth,
                .smoothedSceneDepth
            ]
        }

        session.run(configuration)
    }
    
    // MARK: - Scan Control
    func setScanning(_ scanning: Bool) {
        
        isScanning = scanning
        
        if scanning {
            
            resetScanState()
            scanFolderURL = fileService.createScanFolder()
            
            switch scanMode {
                
            case .lidar:
                print("Scanning Started (LiDAR)")
                
            case .rgb:
                print("Scanning Started (RGB)")
                
            case .trueDepth:
                print("Scanning Started (TrueDepth)")
            }
            
        } else {
            
            finalizeScan()
            
            if scanMode == .trueDepth {
                startSession()
            }
            
            print("Scanning Stopped")
        }
    }
    
    private func resetScanState() {
        capturedFrames.removeAll()
        accumulatedPoints.removeAll()
        scanPositions.removeAll()
        heightLevels.removeAll()
        
        frameCount = 0
        coveragePercent = 0
        heightCoverage = 0
    }
    
    private func finalizeScan() {

        saveCapturedData()

        guard let folder = scanFolderURL else { return }

        pointQueue.sync {

            fileService.savePLY(points: accumulatedPoints, to: folder)
        }

        // Delete RGB photos after generating PLY
        if scanMode == .rgb {
            fileService.deleteImages(in: folder)
        }
    }
    
    // MARK: - TrueDepth Processing
    func processTrueDepth(_ depthData: AVDepthData) {

        let converted = depthData.converting(
            toDepthDataType: kCVPixelFormatType_DepthFloat32
        )

        let depthMap = converted.depthDataMap
        let calibration = depthData.cameraCalibrationData!

        let intrinsics = calibration.intrinsicMatrix

        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        let cx = intrinsics[2][0]
        let cy = intrinsics[2][1]

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        guard let base = CVPixelBufferGetBaseAddress(depthMap) else {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            return
        }

        let buffer = base.assumingMemoryBound(to: Float32.self)

        var newPoints: [SIMD3<Float>] = []

        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {

                let depth = buffer[y * width + x]

                if depth.isNaN || depth <= 0 { continue }

                let X = (Float(x) - cx) * depth / fx
                let Y = (Float(y) - cy) * depth / fy
                let Z = depth

                newPoints.append(SIMD3<Float>(X, Y, Z))
            }
        }

        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)

        pointQueue.async {

            self.accumulatedPoints.append(contentsOf: newPoints)

            if self.accumulatedPoints.count > 1_000_000 {
                self.accumulatedPoints.removeFirst(200_000)
            }
        }

        DispatchQueue.main.async {
            self.frameCount += 1
        }
    }
    
    // MARK: - LiDAR Processing
    private func processLidarFrame(_ frame: ARFrame) {

        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else {
            print("No LiDAR depth available")
            return
        }

        let transform = frame.camera.transform

        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )

        scanPositions.append(position)

        updateCoverage()

        frameCount += 1

        let depthMap = depthData.depthMap

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        let base = CVPixelBufferGetBaseAddress(depthMap)!
        let buffer = base.assumingMemoryBound(to: Float32.self)

        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {

                let depth = buffer[y * width + x]

                if depth == 0 { continue }

                accumulatedPoints.append(
                    SIMD3<Float>(Float(x), Float(y), depth)
                )
            }
        }

        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
    }
    
    // MARK: - RGB Processing
    private func processRGBFrame(_ frame: ARFrame) {
        
        guard case .normal = frame.camera.trackingState else { return }
        if capturedFrames.count > 120 { return }
        
        if let rawPoints = frame.rawFeaturePoints {
            accumulatedPoints.append(contentsOf: rawPoints.points)
        }
        
        guard captureManager.shouldCapture(frame: frame),
              captureManager.isExposureStable(frame: frame),
              let image = captureManager.captureFrame(frame: frame),
              captureManager.isFrameSharp(image),
              let folder = scanFolderURL else { return }
        
        let resized = captureManager.resizeImage(image)
        
        let transform = frame.camera.transform
        let intrinsics = frame.camera.intrinsics
        
        // Height coverage
        let height = transform.columns.3.y
        let level = Int(height * 10)
        heightLevels.insert(level)
        
        heightCoverage = min(heightLevels.count, 2)
        
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        scanPositions.append(position)
        updateCoverage()
        
        let imageName = "frame_\(capturedFrames.count).jpg"
        
        fileService.saveImage(resized, to: folder, index: capturedFrames.count)
        
        let transformArray: [Float] = [
            transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w,
            transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w,
            transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w,
            transform.columns.3.x, transform.columns.3.y, transform.columns.3.z, transform.columns.3.w
        ]
        
        let intrinsicsArray: [Float] = [
            intrinsics[0][0],intrinsics[0][1],intrinsics[0][2],
            intrinsics[1][0],intrinsics[1][1],intrinsics[1][2],
            intrinsics[2][0],intrinsics[2][1],intrinsics[2][2]
        ]
        
        capturedFrames.append(
            CaptureFrame(
                imageName: imageName,
                transform: transformArray,
                intrinsics: intrinsicsArray
            )
        )
        
        frameCount = capturedFrames.count
    }
    
    // MARK: - ARSession Delegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        currentTransform = frame.camera.transform

        guard isScanning else { return }

        switch scanMode {

        case .lidar:
            processLidarFrame(frame)

        case .rgb:
            processRGBFrame(frame)

        case .trueDepth:
            break
        }
    }
    
    // MARK: - Coverage
    private func updateCoverage() {
        
        guard scanPositions.count > 5 else { return }
        
        let center = scanPositions.prefix(10)
            .reduce(SIMD3<Float>(0,0,0), +) / 10
        
        let binCount = 36
        var visited = Set<Int>()
        
        for pos in scanPositions {
            
            let direction = pos - center
            let angle = atan2(direction.z, direction.x)
            
            let normalized = (angle + Float.pi) / (2 * Float.pi)
            let bin = Int(normalized * Float(binCount))
            
            visited.insert(bin)
        }
        
        coveragePercent = Int(Float(visited.count) / Float(binCount) * 100)
    }
    
    // MARK: - Save JSON
    private func saveCapturedData() {
        
        guard let folder = scanFolderURL else { return }
        
        do {
            
            let jsonURL = folder.appendingPathComponent("camera_data.json")
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(capturedFrames)
            try data.write(to: jsonURL)
            
            print("Saved camera_data.json")
            print("Total Frames:", capturedFrames.count)
            
        } catch {
            print("Failed to save JSON:", error)
        }
    }
    
    // MARK: - Detect Mode
    func detectScanMode() {
        
        // Check LiDAR availability
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        
        // Check TrueDepth availability
        isTrueDepthAvailable = AVCaptureDevice.default(.builtInTrueDepthCamera,
                                                        for: .video,
                                                        position: .front) != nil
        
        // Auto-select best available mode
        if isLiDARAvailable {
            scanMode = .lidar
            print("Using LiDAR mode")
        } else if isTrueDepthAvailable {
            scanMode = .trueDepth
            print("Using TrueDepth mode")
        } else {
            scanMode = .rgb
            print("Using RGB mode")
        }
    }
    
    // MARK: - Change Mode
    func changeScanMode(to newMode: ScanMode) {
        // Safety check: prevent switching to unavailable modes
        if newMode == .lidar && !isLiDARAvailable {
            print("⚠️ Cannot switch to LiDAR: not available on this device")
            return
        }
        if newMode == .trueDepth && !isTrueDepthAvailable {
            print("⚠️ Cannot switch to TrueDepth: not available on this device")
            return
        }
        
        scanMode = newMode
        print("Switching to \(newMode) mode")
        
        // Restart session with new configuration
        if newMode == .trueDepth {
            session.pause()
            trueDepthScanner.start()
        } else {
            trueDepthScanner.stop()
            startSession()
        }
    }
}

