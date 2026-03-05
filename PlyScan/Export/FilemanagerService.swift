//
//  FilemanagerService.swift
//  PlyScan
//
//  Created by Dongyeon Kim on 2/25/26.
//

import Foundation
import ARKit
import UIKit

// MARK: - File Saving Service

class FileManagerService {

    private let fileManager = FileManager.default

    func createScanFolder() -> URL? {

        guard let documentsURL = fileManager.urls(for: .documentDirectory,
                                                  in: .userDomainMask).first
        else { return nil }

        // Create unique folder using timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let folderName = "Scan_\(formatter.string(from: Date()))"

        let scanFolderURL = documentsURL.appendingPathComponent(folderName)

        do {
            try fileManager.createDirectory(at: scanFolderURL,
                                            withIntermediateDirectories: true)
            print("Created scan folder:", scanFolderURL)
            return scanFolderURL
        } catch {
            print("Failed to create folder:", error)
            return nil
        }
    }

    func saveImage(_ image: UIImage,
                   to folder: URL,
                   index: Int) {

        let fileURL = folder.appendingPathComponent("frame_\(index).jpg")

        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        do {
            try data.write(to: fileURL)
        } catch {
            print("Failed to save image:", error)
        }
    }
    
    func savePLY(points: [SIMD3<Float>], to folder: URL) {

        let plyURL = folder.appendingPathComponent("sparse_cloud.ply")

        var plyString = """
        ply
        format ascii 1.0
        element vertex \(points.count)
        property float x
        property float y
        property float z
        end_header
        """

        for p in points {
            plyString += "\n\(p.x) \(p.y) \(p.z)"
        }

        do {
            try plyString.write(to: plyURL,
                                atomically: true,
                                encoding: .utf8)
            print("Saved sparse_cloud.ply with \(points.count) points")
        } catch {
            print("Failed to save PLY:", error)
        }
    }
    
    func deleteImages(in folder: URL) {

        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )

            for file in contents {
                if file.pathExtension.lowercased() == "jpg" {
                    try fileManager.removeItem(at: file)
                }
            }

            print("Deleted RGB images from scan folder")

        } catch {
            print("Failed to delete images:", error)
        }
    }
}
