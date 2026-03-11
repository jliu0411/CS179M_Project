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
    
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var hasTriedAfterPermission = false
    private var previousNetworkStatus: NWPath.Status = .unsatisfied
    
    private init() {
        // Try cached IP first
        if let cached = cachedIP {
            discoveredServerURL = "http://\(cached):\(port)"
        }
        
        // Set up network monitoring to detect when permission is granted
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        pathMonitor = NWPathMonitor()
        
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            NSLog("📡 Network status: \(path.status) (previous: \(self.previousNetworkStatus))")
            
            // Detect when network transitions from unsatisfied -> satisfied
            // This indicates permission was just granted
            if path.status == .satisfied && 
               self.previousNetworkStatus != .satisfied && 
               self.discoveredServerURL == nil && 
               !self.hasTriedAfterPermission {
                
                NSLog("🔄 Permission granted! Network transitioned to satisfied. Retrying server discovery...")
                self.hasTriedAfterPermission = true
                
                // Wait a bit to ensure permission is fully applied
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.getServerURL { url in
                        if url != nil {
                            NSLog("✅ Server found after permission grant: \(url)")
                        } else {
                            NSLog("❌ Still no server found after permission grant")
                        }
                    }
                }
            }
            
            // Track previous state for next invocation
            self.previousNetworkStatus = path.status
        }
        pathMonitor?.start(queue: monitorQueue)
    }
    
    deinit {
        pathMonitor?.cancel()
    }
    
    // Get current server URL or trigger discovery
    func getServerURL(completion: @escaping (String?) -> Void) {
        NSLog("🔍 ServerDiscovery: Starting server search...")
        
        // Try cached server first if available
        if let cachedURL = discoveredServerURL {
            NSLog("🔍 Testing cached server: %@", cachedURL)
            testServer(url: cachedURL, timeout: 2.0) { success in
                if success {
                    NSLog("✅ Using cached server: %@", cachedURL)
                    DispatchQueue.main.async {
                        completion(cachedURL)
                    }
                    return
                }
                NSLog("❌ Cached server not responding")
                self.tryCommonServers(completion: completion)
            }
            return
        }
        
        // No cache, try common servers
        tryCommonServers(completion: completion)
    }
    
    // Manual retry (resets the auto-retry flag)
    func retryDiscovery(completion: @escaping (String?) -> Void) {
        NSLog("🔄 Manual retry triggered")
        hasTriedAfterPermission = true  // Prevent duplicate auto-retry
        getServerURL(completion: completion)
    }
    
    // Try common server locations before full network scan
    private func tryCommonServers(completion: @escaping (String?) -> Void) {
        // Build list of likely server addresses
        var candidates: [String] = []
        
        // 1. Localhost (for simulator)
        candidates.append("http://127.0.0.1:\(port)")
        
        // 2. Gateway IP (often the Mac when iPhone is tethered or on same network)
        if let localIP = getLocalIPAddress() {
            NSLog("📱 Device IP: %@", localIP)
            let components = localIP.components(separatedBy: ".")
            if components.count == 4 {
                // Try common gateway: .1
                let gateway = "\(components[0]).\(components[1]).\(components[2]).1"
                candidates.append("http://\(gateway):\(port)")
                
                // Try nearby IPs (likely server IPs)
                for i in 1...20 {
                    let ip = "\(components[0]).\(components[1]).\(components[2]).\(i)"
                    if ip != localIP {
                        candidates.append("http://\(ip):\(port)")
                    }
                }
            }
        }
        
        NSLog("🔍 Testing %d candidate servers...", candidates.count)
        
        // Test candidates in parallel with longer timeout
        let group = DispatchGroup()
        var foundServer: String?
        
        for candidate in candidates {
            group.enter()
            testServer(url: candidate, timeout: 3.0) { success in
                if success && foundServer == nil {
                    foundServer = candidate
                    NSLog("✅ Found server at: %@", candidate)
                }
                group.leave()
            }
        }
        
        // Wait for quick tests to complete
        DispatchQueue.global().async {
            let result = group.wait(timeout: .now() + 5)
            
            DispatchQueue.main.async {
                if let server = foundServer {
                    self.discoveredServerURL = server
                    if let ip = server.components(separatedBy: "://").last?.components(separatedBy: ":").first {
                        self.cachedIP = ip
                    }
                    completion(server)
                } else if result == .timedOut {
                    NSLog("⚠️ Quick scan timed out, trying full network scan...")
                    self.discoverServer(completion: completion)
                } else {
                    NSLog("❌ No server found in quick scan, trying full network scan...")
                    self.discoverServer(completion: completion)
                }
            }
        }
    }
    
    // Discover server on local network
    func discoverServer(completion: @escaping (String?) -> Void) {
        isSearching = true
        
        // Get local IP prefix (e.g., "10.13.173")
        guard let localIP = getLocalIPAddress() else {
            NSLog("❌ Could not determine local IP address")
            isSearching = false
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        NSLog("🔍 Full network scan of %@.0/24 for server...", localIP)
        
        let prefix = localIP.components(separatedBy: ".").dropLast().joined(separator: ".")
        
        // Scan common IPs in parallel
        let group = DispatchGroup()
        var foundServer: String?
        
        // Scan last octet from 1 to 254
        for i in 1...254 {
            let testIP = "\(prefix).\(i)"
            let testURL = "http://\(testIP):\(port)"
            
            group.enter()
            testServer(url: testURL, timeout: 1.0) { success in
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
    private func testServer(url: String, timeout: TimeInterval = 0.5, completion: @escaping (Bool) -> Void) {
        guard let healthURL = URL(string: "\(url)/api/health") else {
            NSLog("❌ Invalid health URL: %@/api/health", url)
            completion(false)
            return
        }
        
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        NSLog("🏥 Testing health endpoint: %@", healthURL.absoluteString)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                NSLog("❌ Health check failed: %@", error.localizedDescription)
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("❌ No HTTP response")
                completion(false)
                return
            }
            
            NSLog("📡 Health check status code: %d", httpResponse.statusCode)
            
            if httpResponse.statusCode == 200 {
                NSLog("✅ Server is healthy!")
                completion(true)
            } else {
                completion(false)
            }
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
