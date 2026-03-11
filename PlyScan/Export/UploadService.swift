//
//  UploadService.swift
//  PlyScan
//
//  Created by Dongyeon Kim on 2/25/26.
//

import Foundation

struct UploadResponse: Codable {
    let success: Bool
    let originalFilename: String
    let cleanedFilename: String
    let dimensions: Dimensions
    let qualityMetrics: QualityMetrics?
    let confidence: Double?  // Reference-based confidence (0-100)
    
    struct Dimensions: Codable {
        let width: Double
        let length: Double
        let height: Double
    }
    
    struct QualityMetrics: Codable {
        let pointCount: Int
        let ransacInlierRatio: Double
        let aspectRatio: Double
        
        enum CodingKeys: String, CodingKey {
            case pointCount = "point_count"
            case ransacInlierRatio = "ransac_inlier_ratio"
            case aspectRatio = "aspect_ratio"
        }
        
        // Calculate a simple quality score (0-100)
        var qualityScore: Double {
            // Higher point count = better (normalize to 10k points)
            let pointScore = min(Double(pointCount) / 10000.0, 1.0) * 100
            
            // Lower RANSAC ratio = cleaner object detection (less floor)
            let ransacScore = (1.0 - ransacInlierRatio) * 100
            
            // Aspect ratio around 1.5-3.0 is typical for boxes
            let aspectScore = aspectRatio >= 1.0 && aspectRatio <= 5.0 ? 100.0 : 50.0
            
            return (pointScore * 0.4 + ransacScore * 0.4 + aspectScore * 0.2)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case originalFilename = "original_filename"
        case cleanedFilename = "cleaned_filename"
        case dimensions
        case qualityMetrics = "quality_metrics"
        case confidence
    }
}

enum UploadError: Error, LocalizedError {
    case invalidURL
    case fileNotFound
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL. Please check your network settings."
        case .fileNotFound:
            return "PLY file not found. Please try scanning again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

class UploadService {
    static let shared = UploadService()
    
    private init() {}
    
    func uploadPLY(fileURL: URL, scanMode: ARSessionManager.ScanMode, completion: @escaping (Result<UploadResponse, UploadError>) -> Void) {
        
        NSLog("🔧 UploadService.uploadPLY called")
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            NSLog("❌ File not found at: %@", fileURL.path)
            DispatchQueue.main.async {
                completion(.failure(.fileNotFound))
            }
            return
        }
        
        NSLog("✅ Found file at: %@", fileURL.path)
        
        // Discover server URL
        NSLog("🔍 Starting server discovery...")
        ServerDiscovery.shared.getServerURL { [weak self] baseURL in
            guard let self = self else { return }
            
            NSLog("📞 getServerURL callback - result: %@", baseURL ?? "nil")
            
            guard let baseURL = baseURL else {
                NSLog("❌ Could not find server on network")
                DispatchQueue.main.async {
                    completion(.failure(.invalidURL))
                }
                return
            }
            
            NSLog("🌐 Using server: %@", baseURL)
            
            // Prepare the request
            guard let url = URL(string: "\(baseURL)/api/upload-ply?method=AABB") else {
                NSLog("❌ Invalid URL: %@/api/upload-ply", baseURL)
                completion(.failure(.invalidURL))
                return
            }
            
            NSLog("📡 Uploading to: %@", url.absoluteString)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 120  // Increased to 2 minutes for processing time
            
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            // Create multipart body
            let body = self.createMultipartBody(fileURL: fileURL, boundary: boundary)
            
            // Upload task
            let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            
            if let error = error {
                NSLog("❌ Network error: %@", error.localizedDescription)
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("❌ Invalid response")
                completion(.failure(.invalidResponse))
                return
            }
            
            NSLog("📥 Server response: %d", httpResponse.statusCode)
            
            guard let data = data else {
                NSLog("❌ No data in response")
                completion(.failure(.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 200 {
                // Log raw response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    NSLog("📄 Raw response: %@", jsonString)
                }
                
                do {
                    let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
                    NSLog("✅ Upload successful!")
                    NSLog("   Width: %.3fm", uploadResponse.dimensions.width)
                    NSLog("   Length: %.3fm", uploadResponse.dimensions.length)
                    NSLog("   Height: %.3fm", uploadResponse.dimensions.height)
                    completion(.success(uploadResponse))
                } catch {
                    NSLog("❌ Decoding error: %@", error.localizedDescription)
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            NSLog("   Missing key: %@ - %@", key.stringValue, context.debugDescription)
                        case .typeMismatch(let type, let context):
                            NSLog("   Type mismatch: %@ - %@", String(describing: type), context.debugDescription)
                        case .valueNotFound(let type, let context):
                            NSLog("   Value not found: %@ - %@", String(describing: type), context.debugDescription)
                        case .dataCorrupted(let context):
                            NSLog("   Data corrupted: %@", context.debugDescription)
                        @unknown default:
                            NSLog("   Unknown decoding error")
                        }
                    }
                    completion(.failure(.invalidResponse))
                }
            } else {
                if let errorMessage = String(data: data, encoding: .utf8) {
                    NSLog("❌ Server error (%d): %@", httpResponse.statusCode, errorMessage)
                    completion(.failure(.serverError(errorMessage)))
                } else {
                    NSLog("❌ Server error: %d", httpResponse.statusCode)
                    completion(.failure(.serverError("Server returned status \(httpResponse.statusCode)")))
                }
            }
        }
        
        task.resume()
            }
        }
    
        private func createMultipartBody(fileURL: URL, boundary: String) -> Data {
            var body = Data()
            
            let filename = fileURL.lastPathComponent
            let mimetype = "application/octet-stream"
            
            // Add file data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
            
            if let fileData = try? Data(contentsOf: fileURL) {
                NSLog("📦 File size: %d bytes", fileData.count)
                body.append(fileData)
            } else {
                NSLog("❌ Failed to read file data")
            }
            
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            NSLog("📤 Total upload size: %d bytes", body.count)
            return body
        }
}
