//
//  APIClient.swift
//  PlyScan
//
//  Created by Dongyeon Kim on 2/25/26.
//

import Foundation

class APIClient {
    static let shared = APIClient()
    
    private init() {}
    
    func url(for endpoint: Endpoint, completion: @escaping (URL?) -> Void) {
        ServerDiscovery.shared.getServerURL { baseURL in
            guard let baseURL = baseURL else {
                completion(nil)
                return
            }
            completion(URL(string: baseURL + endpoint.path))
        }
    }
    
    func checkHealth(completion: @escaping (Result<Bool, Error>) -> Void) {
        url(for: .health) { url in
            guard let url = url else {
                completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find server"])))
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
}
