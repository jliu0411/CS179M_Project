//
//  TrueDepthScanner.swift
//  PlyScan
//

import AVFoundation
import UIKit

class TrueDepthScanner: NSObject, AVCaptureDepthDataOutputDelegate {

    private let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()

    var previewLayer: AVCaptureVideoPreviewLayer?

    var onDepthFrame: ((AVDepthData) -> Void)?

    // MARK: - Start Scanner
    func start() {

        session.beginConfiguration()

        session.sessionPreset = .vga640x480

        guard let device = AVCaptureDevice.default(
            .builtInTrueDepthCamera,
            for: .video,
            position: .front
        ) else {
            print("TrueDepth camera not available")
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            print("Cannot create camera input")
            return
        }

        if session.inputs.isEmpty && session.canAddInput(input) {
            session.addInput(input)
        }

        if session.outputs.isEmpty {

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            if session.canAddOutput(depthOutput) {
                session.addOutput(depthOutput)
            }
        }

        depthOutput.setDelegate(self,
                                callbackQueue: DispatchQueue(label: "depthQueue"))

        depthOutput.isFilteringEnabled = true

        session.commitConfiguration()

        // Create preview BEFORE starting session
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }

        print("TrueDepth session started")
    }

    // MARK: - Stop Scanner
    func stop() {
        DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
        }
        print("TrueDepth session stopped")
    }

    // MARK: - Depth Frame Delegate
    func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                         didOutput depthData: AVDepthData,
                         timestamp: CMTime,
                         connection: AVCaptureConnection) {

        onDepthFrame?(depthData)
    }
}
