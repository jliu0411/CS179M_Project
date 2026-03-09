//
//  APIClient.swift
//  PlyScan
//
//  Created by Dongyeon Kim on 2/25/26.
//

import Foundation

class APIClient {
    static let shared = APIClient()
    
    private var baseURL: String {
        #if DEBUG
        return "http://localhost:8000"
        #else
        return "https://cs179m-project-test.onrender.com"
        #endif
    }
    
    private init() {}
    
    func url(for endpoint: Endpoint) -> URL? {
        return URL(string: baseURL + endpoint.path)
    }
    
    func checkHealth(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = url(for: .health) else {
            completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(.success(true))
            } else {
                completion(.success(false))
            }
        }.resume()
    }
}
