//
//  ARISENetworkService.swift
//  byollm-assistantOS
//
//  Created by master on 12/6/25.
//
//  API contracts for ARISE backend. Backend implementation is separate.
//

import Foundation

// MARK: - API Request/Response Types

struct CreateGoalRequest: Codable {
    let title: String
    let description: String
    let timeframe: String
    let targetDate: Date?
}

struct CreateGoalResponse: Codable {
    let id: String
    let title: String
    let description: String
    let timeframe: String
    let targetDate: Date?
    let status: String
    let createdAt: Date
}

struct GenerateTreeRequest: Codable {
    let goalId: String
    let contextSourceIds: [String]?
}

struct GenerateTreeResponse: Codable {
    let id: String
    let goalId: String
    let title: String
    let branches: [BranchResponse]
    let generatedAt: Date
}

struct BranchResponse: Codable {
    let id: String
    let name: String
    let nodes: [NodeResponse]
}

struct NodeResponse: Codable {
    let id: String
    let title: String
    let description: String
    let tier: Int
    let prerequisites: [String]
    let completionCriteria: [String]
    let estimatedHours: Double
    let xpValue: Int
    let status: String
    let linkedStats: [String]
}

struct CompleteNodeRequest: Codable {
    let completionNotes: String?
}

struct CompleteNodeResponse: Codable {
    let node: NodeResponse
    let xpGained: Int
    let newNodes: [NodeResponse]?
    let levelUp: Bool
    let newLevel: Int?
}

struct IngestContextRequest: Codable {
    let sourceType: String
    let title: String
    let content: String
}

struct IngestContextResponse: Codable {
    let id: String
    let sourceType: String
    let title: String
    let ingestedAt: Date
    let chunkCount: Int?
}

struct StatsResponse: Codable {
    let level: Int
    let totalXP: Int
    let currentStreak: Int
    let longestStreak: Int
    let nodesCompleted: Int
    let treesCompleted: Int
    let str: Int
    let int: Int
    let wis: Int
    let dex: Int
    let cha: Int
    let vit: Int
}

struct RefreshTreeRequest: Codable {
    let treeId: String
}

struct RefreshTreeResponse: Codable {
    let tree: GenerateTreeResponse
    let nodesAdded: Int
    let nodesModified: Int
    let nodesRemoved: Int
}

// MARK: - ARISE Network Service

class ARISENetworkService {
    static let shared = ARISENetworkService()
    
    private var baseURL: String = ""
    
    private init() {}
    
    func configure(serverAddress: String) {
        var urlString = serverAddress
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        baseURL = urlString
    }
    
    // MARK: - Goals
    
    /// POST /api/arise/goals - Create a new goal
    func createGoal(_ request: CreateGoalRequest) async throws -> CreateGoalResponse {
        let url = try buildURL("/api/arise/goals")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
        
        return try JSONDecoder().decode(CreateGoalResponse.self, from: data)
    }
    
    /// GET /api/arise/goals - List all goals
    func listGoals() async throws -> [CreateGoalResponse] {
        let url = try buildURL("/api/arise/goals")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
        
        return try JSONDecoder().decode([CreateGoalResponse].self, from: data)
    }
    
    /// DELETE /api/arise/goals/{id} - Delete a goal
    func deleteGoal(id: String) async throws {
        let url = try buildURL("/api/arise/goals/\(id)")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
    }
    
    // MARK: - Trees
    
    /// POST /api/arise/trees/generate - Generate skill tree from goal
    func generateTree(_ request: GenerateTreeRequest) async throws -> GenerateTreeResponse {
        let url = try buildURL("/api/arise/trees/generate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120.0
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
        
        return try JSONDecoder().decode(GenerateTreeResponse.self, from: data)
    }
    
    /// GET /api/arise/trees/{id} - Get full tree with nodes
    func getTree(id: String) async throws -> GenerateTreeResponse {
        let url = try buildURL("/api/arise/trees/\(id)")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
        
        return try JSONDecoder().decode(GenerateTreeResponse.self, from: data)
    }
    
    /// POST /api/arise/trees/{id}/refresh - Regenerate tree with latest context
    func refreshTree(_ request: RefreshTreeRequest) async throws -> RefreshTreeResponse {
        let url = try buildURL("/api/arise/trees/\(request.treeId)/refresh")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120.0
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
        
        return try JSONDecoder().decode(RefreshTreeResponse.self, from: data)
    }
    
    // MARK: - Nodes
    
    /// POST /api/arise/nodes/{id}/complete - Mark node as complete
    func completeNode(id: String, request: CompleteNodeRequest) async throws -> CompleteNodeResponse {
        let url = try buildURL("/api/arise/nodes/\(id)/complete")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
        
        return try JSONDecoder().decode(CompleteNodeResponse.self, from: data)
    }
    
    /// PUT /api/arise/nodes/{id}/status - Update node status
    func updateNodeStatus(id: String, status: String) async throws -> NodeResponse {
        let url = try buildURL("/api/arise/nodes/\(id)/status")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(["status": status])
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
        
        return try JSONDecoder().decode(NodeResponse.self, from: data)
    }
    
    // MARK: - Context
    
    /// POST /api/arise/context/ingest - Ingest new context source
    func ingestContext(_ request: IngestContextRequest) async throws -> IngestContextResponse {
        let url = try buildURL("/api/arise/context/ingest")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
        
        return try JSONDecoder().decode(IngestContextResponse.self, from: data)
    }
    
    /// GET /api/arise/context/sources - List context sources
    func listContextSources() async throws -> [IngestContextResponse] {
        let url = try buildURL("/api/arise/context/sources")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
        
        return try JSONDecoder().decode([IngestContextResponse].self, from: data)
    }
    
    // MARK: - Stats
    
    /// GET /api/arise/stats - Get user stats
    func getStats() async throws -> StatsResponse {
        let url = try buildURL("/api/arise/stats")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validateResponse(response)
        
        return try JSONDecoder().decode(StatsResponse.self, from: data)
    }
    
    // MARK: - Helpers
    
    private func buildURL(_ path: String) throws -> URL {
        guard !baseURL.isEmpty else {
            throw ARISENetworkError.notConfigured
        }
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw ARISENetworkError.invalidURL
        }
        return url
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ARISENetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ARISENetworkError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    enum ARISENetworkError: LocalizedError {
        case notConfigured
        case invalidURL
        case invalidResponse
        case serverError(statusCode: Int)
        
        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "ARISE server not configured"
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let statusCode):
                return "Server error (status: \(statusCode))"
            }
        }
    }
}
