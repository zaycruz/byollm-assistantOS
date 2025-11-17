//
//  NetworkManager.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    private init() {}
    
    func testConnection(to serverAddress: String) async throws -> Bool {
        // Validate URL format
        guard !serverAddress.isEmpty else {
            throw NetworkError.invalidURL
        }
        
        // Add http:// if not present
        var urlString = serverAddress
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        // Create a simple health check request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // Consider 200-299 and 404 as "server is responding"
                // 404 is acceptable because it means the server exists, just wrong endpoint
                return (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 404
            }
            
            return false
        } catch {
            throw NetworkError.connectionFailed(error.localizedDescription)
        }
    }
    
    enum NetworkError: LocalizedError {
        case invalidURL
        case connectionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid server address format"
            case .connectionFailed(let message):
                return "Connection failed: \(message)"
            }
        }
    }
}

