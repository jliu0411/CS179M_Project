//
//  FrameCaptureManager.swift
//  PlyScan
//
//  Created by Dongyeon Kim on 2/25/26.
//

import Foundation
import ARKit
import UIKit

class FrameCaptureManager {

    private var lastCapturedPosition: simd_float3?
    private var lastCapturedTransform: simd_float4x4?
    
    func isExposureStable(frame: ARFrame) -> Bool {

        let exposure = frame.camera.exposureDuration

        return exposure < 0.02
    }

    func shouldCapture(frame: ARFrame) -> Bool {

        let transform = frame.camera.transform

        guard let lastTransform = lastCapturedTransform else {
            lastCapturedTransform = transform
            return true
        }

        // Translation check
        let currentPos = simd_float3(transform.columns.3.x,
                                     transform.columns.3.y,
                                     transform.columns.3.z)

        let lastPos = simd_float3(lastTransform.columns.3.x,
                                  lastTransform.columns.3.y,
                                  lastTransform.columns.3.z)

        let distance = simd_distance(currentPos, lastPos)

        // Rotation check
        let currentForward = simd_float3(transform.columns.2.x,
                                         transform.columns.2.y,
                                         transform.columns.2.z)

        let lastForward = simd_float3(lastTransform.columns.2.x,
                                      lastTransform.columns.2.y,
                                      lastTransform.columns.2.z)

        let dotProduct = simd_dot(currentForward, lastForward)
        let angle = acos(min(max(dotProduct, -1.0), 1.0))

        if distance > 0.05 || angle > 0.1 {   // ~6 degrees
            lastCapturedTransform = transform
            return true
        }

        return false
    }
    
    func isFrameSharp(_ image: UIImage) -> Bool {

            guard let cgImage = image.cgImage else { return false }

            let ciImage = CIImage(cgImage: cgImage)

            let filter = CIFilter(name: "CIEdges")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(10.0, forKey: "inputIntensity")

            guard let output = filter?.outputImage else { return false }

            let context = CIContext()
            guard let cg = context.createCGImage(output,
                                                 from: output.extent)
            else { return false }

            return cg.width > 0
    }

    func captureFrame(frame: ARFrame) -> UIImage? {

        let pixelBuffer = frame.capturedImage
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage,
                                                  from: ciImage.extent)
        else { return nil }

        return UIImage(cgImage: cgImage)
    }
    
    func resizeImage(_ image: UIImage, maxWidth: CGFloat = 1280) -> UIImage {

        let size = image.size
        let scale = maxWidth / size.width

        if scale >= 1 { return image }

        let newSize = CGSize(width: maxWidth, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized ?? image
    }
}
