import Foundation
import AVFoundation
import simd
import CoreMedia
import CoreVideo

final class TrueDepthCameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "TrueDepthCameraSessionQueue")
    private let outputQueue = DispatchQueue(label: "TrueDepthOutputQueue")

    private var videoOutput = AVCaptureVideoDataOutput()
    private var depthOutput = AVCaptureDepthDataOutput()

    private var latestDepthData: AVDepthData?
    private var latestCalibration: AVCameraCalibrationData?

    private var captureContinuation: CheckedContinuation<URL, Error>?

    // MARK: - Public

    func start() {
        sessionQueue.async {
            if self.session.isRunning { return }
            do {
                if self.session.inputs.isEmpty {
                    try self.configureSession()
                }
                self.session.startRunning()
            } catch {
                print("Failed to configure/start TrueDepth session:", error)
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePLY() async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            outputQueue.async {
                // overwrite any prior pending capture
                self.captureContinuation = continuation

                guard let depth = self.latestDepthData else {
                    continuation.resume(throwing: NSError(
                        domain: "TrueDepth",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "No depth frame available yet. Try again in 1 second."]
                    ))
                    self.captureContinuation = nil
                    return
                }

                do {
                    let points = try self.pointCloudFromDepth(depth)
                    let reduced = self.voxelLikeDownsample(points, grid: 0.003)

                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let url = docs.appendingPathComponent("scan.ply")

                    try PlyWriter.writeASCII(points: reduced, to: url)
                    continuation.resume(returning: url)
                    self.captureContinuation = nil
                } catch {
                    continuation.resume(throwing: error)
                    self.captureContinuation = nil
                }
            }
        }
    }

    // MARK: - Session setup

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        // TrueDepth front camera
        guard let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else {
            session.commitConfiguration()
            throw NSError(
                domain: "TrueDepth",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "TrueDepth front camera is not available on this device."]
            )
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw NSError(domain: "TrueDepth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input"])
        }
        session.addInput(input)

        // Video output (for preview timing / optional future use)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            throw NSError(domain: "TrueDepth", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot add video output"])
        }
        session.addOutput(videoOutput)

        // Depth output
        depthOutput.isFilteringEnabled = true
        depthOutput.setDelegate(self, callbackQueue: outputQueue)
        guard session.canAddOutput(depthOutput) else {
            session.commitConfiguration()
            throw NSError(domain: "TrueDepth", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot add depth output"])
        }
        session.addOutput(depthOutput)

        // Connection settings
        if let depthConnection = depthOutput.connection(with: .depthData) {
            if depthConnection.isCameraIntrinsicMatrixDeliverySupported {
                depthConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
            if depthConnection.isVideoOrientationSupported {
                depthConnection.videoOrientation = .portrait
            }
        }

        if let videoConnection = videoOutput.connection(with: .video), videoConnection.isVideoOrientationSupported {
            videoConnection.videoOrientation = .portrait
        }

        // Try to force a depth format if available (optional but helpful)
        try device.lockForConfiguration()
        if let bestFormat = device.activeFormat.supportedDepthDataFormats.last {
            device.activeDepthDataFormat = bestFormat
        }
        device.unlockForConfiguration()

        session.commitConfiguration()
    }

    // MARK: - Delegates

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // video frames available here if needed later
    }

    func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                         didOutput depthData: AVDepthData,
                         timestamp: CMTime,
                         connection: AVCaptureConnection) {
        // Convert to Float32 depth map in meters if needed
        let converted: AVDepthData
        if depthData.depthDataType != kCVPixelFormatType_DepthFloat32 {
            converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        } else {
            converted = depthData
        }

        latestDepthData = converted
        latestCalibration = converted.cameraCalibrationData
    }

    // MARK: - Depth -> Point Cloud

    private func pointCloudFromDepth(_ depthData: AVDepthData) throws -> [simd_float3] {
        guard let calib = depthData.cameraCalibrationData else {
            throw NSError(domain: "TrueDepth", code: 6, userInfo: [NSLocalizedDescriptionKey: "Missing camera calibration data"])
        }

        let depthBuffer = depthData.depthDataMap
        CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(depthBuffer)
        let height = CVPixelBufferGetHeight(depthBuffer)

        guard let baseAddr = CVPixelBufferGetBaseAddress(depthBuffer) else {
            throw NSError(domain: "TrueDepth", code: 7, userInfo: [NSLocalizedDescriptionKey: "No depth buffer base address"])
        }

        let depthPtr = baseAddr.assumingMemoryBound(to: Float32.self)
        let depthStride = CVPixelBufferGetBytesPerRow(depthBuffer) / MemoryLayout<Float32>.size

        // Intrinsics are for the calibration reference dimensions
        let intrinsics = calib.intrinsicMatrix
        let invK = simd_inverse(intrinsics)

        // Depth map may differ from reference dimensions; scale coordinates
        let refSize = calib.intrinsicMatrixReferenceDimensions
        let sx = Float(refSize.width) / Float(width)
        let sy = Float(refSize.height) / Float(height)

        var points: [simd_float3] = []
        points.reserveCapacity((width * height) / 16)

        // Tune these for stability/speed
        let pixelStep = 4
        let minDepth: Float = 0.10   // meters
        let maxDepth: Float = 1.20   // TrueDepth works close-range

        for y in stride(from: 0, to: height, by: pixelStep) {
            for x in stride(from: 0, to: width, by: pixelStep) {
                let d = depthPtr[y * depthStride + x]
                if !d.isFinite || d <= minDepth || d >= maxDepth {
                    continue
                }

                // Scale depth-map pixel coordinates into calibration reference image coordinates
                let u = (Float(x) + 0.5) * sx
                let v = (Float(y) + 0.5) * sy

                let pixel = simd_float3(u, v, 1.0)
                let ray = invK * pixel
                let pCam = ray * d

                // NOTE:
                // This is in camera coordinates (meters). For your backend pipeline, that's fine.
                // You don't need world coordinates for a single-frame MVP.
                points.append(pCam)
            }
        }

        if points.isEmpty {
            throw NSError(domain: "TrueDepth", code: 8, userInfo: [NSLocalizedDescriptionKey: "No valid depth points found. Move closer and try again."])
        }

        return points
    }

    private func voxelLikeDownsample(_ points: [simd_float3], grid: Float) -> [simd_float3] {
        guard !points.isEmpty else { return [] }
        guard grid > 0 else { return points }

        var seen = Set<String>()
        var out: [simd_float3] = []
        out.reserveCapacity(min(points.count, 80_000))

        for p in points {
            let gx = Int(floor(p.x / grid))
            let gy = Int(floor(p.y / grid))
            let gz = Int(floor(p.z / grid))
            let key = "\(gx),\(gy),\(gz)"
            if seen.insert(key).inserted {
                out.append(p)
            }
        }
        return out
    }
}