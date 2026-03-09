//
//  ServerDiscovery.swift
//  PlyScan
//
//  Auto-discovers the backend server on the local network
//

import Foundation
import Network

class ServerDiscovery: ObservableObject {
    static let shared = ServerDiscovery()
    
    @Published var discoveredServerURL: String?
    @Published var isSearching = false
    
    private let port = 8000
    private var cachedIP: String? {
        get { UserDefaults.standard.string(forKey: "cachedServerIP") }
        set { UserDefaults.standard.set(newValue, forKey: "cachedServerIP") }
    }
    
    private init() {
        // Try cached IP first
        if let cached = cachedIP {
            discoveredServerURL = "http://\(cached):\(port)"
        }
    }
    
    // Get current server URL or trigger discovery
    func getServerURL(completion: @escaping (String?) -> Void) {
        // If we have a cached URL, verify it works
        if let url = discoveredServerURL {
            testServer(url: url) { success in
                if success {
                    completion(url)
                } else {
                    // Cached server not responding, search again
                    self.discoverServer(completion: completion)
                }
            }
        } else {
            discoverServer(completion: completion)
        }
    }
    
    // Discover server on local network
    func discoverServer(completion: @escaping (String?) -> Void) {
        isSearching = true
        
        // Get local IP prefix (e.g., "192.168.1")
        guard let localIP = getLocalIPAddress() else {
            NSLog("❌ Could not determine local IP address")
            isSearching = false
            completion(nil)
            return
        }
        
        NSLog("🔍 Scanning network %@.0/24 for server...", localIP)
        
        let prefix = localIP.components(separatedBy: ".").dropLast().joined(separator: ".")
        
        // Scan common IPs in parallel
        let group = DispatchGroup()
        var foundServer: String?
        
        // Scan last octet from 1 to 254
        for i in 1...254 {
            let testIP = "\(prefix).\(i)"
            let testURL = "http://\(testIP):\(port)"
            
            group.enter()
            testServer(url: testURL) { success in
                if success && foundServer == nil {
                    foundServer = testURL
                    NSLog("✅ Found server at %@", testURL)
                }
                group.leave()
            }
        }
        
        // Wait for all tests to complete (with timeout)
        DispatchQueue.global().async {
            let result = group.wait(timeout: .now() + 10) // 10 second timeout
            
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let server = foundServer {
                    self.discoveredServerURL = server
                    // Cache the IP
                    if let ip = server.components(separatedBy: "://").last?.components(separatedBy: ":").first {
                        self.cachedIP = ip
                    }
                    completion(server)
                } else if result == .timedOut {
                    NSLog("⚠️ Network scan timed out")
                    completion(nil)
                } else {
                    NSLog("❌ No server found on network")
                    completion(nil)
                }
            }
        }
    }
    
    // Test if a server URL is responding
    private func testServer(url: String, completion: @escaping (Bool) -> Void) {
        guard let healthURL = URL(string: "\(url)/api/health") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 0.5 // Fast timeout for scanning
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(false)
                return
            }
            completion(true)
        }.resume()
    }
    
    // Get local network IP address
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                
                // Skip loopback and non-WiFi interfaces
                if name == "en0" || name.starts(with: "en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    
                    // Prefer 192.168.x.x or 10.x.x.x addresses
                    if let addr = address, 
                       (addr.starts(with: "192.168") || addr.starts(with: "10.")) {
                        break
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
}
