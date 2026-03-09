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
    
    struct Dimensions: Codable {
        let width: Double
        let length: Double
        let height: Double
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case originalFilename = "original_filename"
        case cleanedFilename = "cleaned_filename"
        case dimensions
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
    
    // Backend server URL - update this with your server address
    private var baseURL: String {
        // Try to read from server-auto.ts if available, otherwise use default
        #if DEBUG
        return "http://192.168.1.47:8000"  // Your Mac's IP address
        #else
        return "https://cs179m-project-test.onrender.com"
        #endif
    }
    
    private init() {}
    
    func uploadPLY(fileURL: URL, scanMode: ARSessionManager.ScanMode, completion: @escaping (Result<UploadResponse, UploadError>) -> Void) {
        
        NSLog("🔧 UploadService.uploadPLY called")
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            NSLog("❌ File not found at: %@", fileURL.path)
            completion(.failure(.fileNotFound))
            return
        }
        
        NSLog("✅ Found file at: %@", fileURL.path)
        
        // Prepare the request
        guard let url = URL(string: "\(baseURL)/api/upload-ply") else {
            NSLog("❌ Invalid URL: %@/api/upload-ply", baseURL)
            completion(.failure(.invalidURL))
            return
        }
        
        NSLog("📡 Uploading to: %@", url.absoluteString)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create multipart body
        let body = createMultipartBody(fileURL: fileURL, boundary: boundary)
        
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
