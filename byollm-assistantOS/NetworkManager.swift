//
//  NetworkManager.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import Foundation
import Security
import UIKit

// MARK: - API Models
struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let provider: String?
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool
    let safetyLevel: String?
    let reasoningEffort: String?
    let conversationId: String?
    let includeReasoning: Bool?  // Request reasoning content in response
    
    enum CodingKeys: String, CodingKey {
        case model, messages, provider, temperature, stream
        case maxTokens = "max_tokens"
        case safetyLevel = "safety_level"
        case reasoningEffort = "reasoning_effort"
        case conversationId = "conversation_id"
        case includeReasoning = "include_reasoning"
    }
    
    // Initialize without max_tokens by setting it to nil
    init(model: String, messages: [ChatMessage], provider: String? = nil, temperature: Double?, stream: Bool, safetyLevel: String?, reasoningEffort: String? = nil, conversationId: String? = nil, includeReasoning: Bool? = nil) {
        self.model = model
        self.messages = messages
        self.provider = provider
        self.temperature = temperature
        self.maxTokens = nil  // Remove token limit
        self.stream = stream
        self.safetyLevel = safetyLevel
        self.reasoningEffort = reasoningEffort
        self.conversationId = conversationId
        self.includeReasoning = includeReasoning
    }
}

struct ChatResponse: Codable {
    let id: String
    let object: String
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let index: Int
        let message: ResponseMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct ResponseMessage: Codable {
        let role: String
        let content: String
        let reasoningContent: String?  // For GPT-oss thinking
        
        enum CodingKeys: String, CodingKey {
            case role, content
            case reasoningContent = "reasoning_content"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct ChatStreamResponse: Codable {
    let id: String
    let object: String
    let model: String
    let choices: [StreamChoice]
    
    struct StreamChoice: Codable {
        let index: Int
        let delta: Delta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }
    
    struct Delta: Codable {
        let role: String?
        let content: String?
        let reasoningContent: String?  // For GPT-oss thinking
        
        enum CodingKeys: String, CodingKey {
            case role, content
            case reasoningContent = "reasoning_content"
        }
    }
}

struct ModelsResponse: Codable {
    let object: String
    let data: [ModelInfo]
    
    struct ModelInfo: Codable {
        let id: String
        let object: String
        let created: Int?
        let ownedBy: String?
        
        enum CodingKeys: String, CodingKey {
            case id, object, created
            case ownedBy = "owned_by"
        }
    }
}

struct HealthResponse: Codable {
    let status: String
    let backend: String?
    let version: String?
}

// MARK: - Network Manager
class NetworkManager {
    static let shared = NetworkManager()
    
    private init() {}
    
    // Test connection using health endpoint
    func testConnection(to serverAddress: String) async throws -> Bool {
        guard !serverAddress.isEmpty else {
            throw NetworkError.invalidURL
        }
        
        var urlString = serverAddress
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        
        guard let url = URL(string: "\(urlString)/health") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    // Try to decode health response
                    if let healthResponse = try? JSONDecoder().decode(HealthResponse.self, from: data) {
                        return healthResponse.status == "healthy"
                    }
                    return true
                }
            }
            
            return false
        } catch {
            throw NetworkError.connectionFailed(error.localizedDescription)
        }
    }
    
    // Get available models
    func getModels(from serverAddress: String) async throws -> [String] {
        var urlString = serverAddress
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        
        guard let url = URL(string: "\(urlString)/v1/models") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
        
        return response.data.map { $0.id }
    }
    
    // Send chat message
    func sendChatMessage(
        to serverAddress: String,
        model: String,
        messages: [ChatMessage],
        systemPrompt: String? = nil,
        provider: String? = nil,
        safetyLevel: String? = nil,
        temperature: Double = 0.7,
        reasoningEffort: String? = nil,
        conversationId: String? = nil
    ) async throws -> String {
        var urlString = serverAddress
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        
        guard let url = URL(string: "\(urlString)/v1/chat/completions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0
        
        // Build messages array with optional system prompt
        var allMessages: [ChatMessage] = []
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            allMessages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        allMessages.append(contentsOf: messages)
        
        let chatRequest = ChatRequest(
            model: model,
            messages: allMessages,
            provider: provider,
            temperature: temperature,
            stream: false,
            safetyLevel: safetyLevel,
            reasoningEffort: reasoningEffort,
            conversationId: conversationId,
            includeReasoning: reasoningEffort != nil ? true : nil
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        // Debug: Print the actual JSON being sent
        if let jsonData = request.httpBody,
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Sending request to server:")
            print(jsonString)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        guard let content = chatResponse.choices.first?.message.content else {
            throw NetworkError.noContent
        }
        
        return content
    }
    
    // Send chat message with streaming
    func sendChatMessageStreaming(
        to serverAddress: String,
        model: String,
        messages: [ChatMessage],
        systemPrompt: String? = nil,
        provider: String? = nil,
        safetyLevel: String? = nil,
        temperature: Double = 0.7,
        reasoningEffort: String? = nil,
        conversationId: String? = nil,
        onChunk: @escaping (String) -> Void,
        onReasoningChunk: @escaping (String) -> Void = { _ in }
    ) async throws {
        var urlString = serverAddress
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        
        guard let url = URL(string: "\(urlString)/v1/chat/completions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120.0
        
        // Build messages array with optional system prompt
        var allMessages: [ChatMessage] = []
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            allMessages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        allMessages.append(contentsOf: messages)
        
        let chatRequest = ChatRequest(
            model: model,
            messages: allMessages,
            provider: provider,
            temperature: temperature,
            stream: true,
            safetyLevel: safetyLevel,
            reasoningEffort: reasoningEffort,
            conversationId: conversationId,
            includeReasoning: reasoningEffort != nil ? true : nil
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        // Debug: Print the actual JSON being sent
        if let jsonData = request.httpBody,
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Sending streaming request to server:")
            print(jsonString)
        }
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        var buffer = Data()
        var stringBuffer = ""
        
        for try await byte in asyncBytes {
            buffer.append(byte)
            
            // Try to decode accumulated bytes as UTF-8 string
            // Use lossy decoding to handle incomplete sequences gracefully
            if let decodedString = String(bytes: buffer, encoding: .utf8) {
                stringBuffer += decodedString
                buffer.removeAll()
            } else if buffer.count > 4 {
                // If buffer is getting too large without valid UTF-8, use lossy conversion
                stringBuffer += String(decoding: buffer, as: UTF8.self)
                buffer.removeAll()
            }
            
            // Process complete lines
            while let newlineIndex = stringBuffer.firstIndex(of: "\n") {
                let line = String(stringBuffer[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                stringBuffer.removeSubrange(...newlineIndex)
                
                // Skip empty lines
                guard !line.isEmpty else { continue }
                
                // Skip "data: [DONE]" marker
                if line == "data: [DONE]" {
                    continue
                }
                
                // Parse SSE format
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    
                    // Debug: Print raw JSON for first few chunks
                    if jsonString.count < 500 {
                        print("📦 Raw JSON chunk: \(jsonString)")
                    }
                    
                    if let jsonData = jsonString.data(using: .utf8) {
                        do {
                            let streamResponse = try JSONDecoder().decode(ChatStreamResponse.self, from: jsonData)
                            
                            // Handle reasoning content (for GPT-oss models)
                            if let reasoningContent = streamResponse.choices.first?.delta.reasoningContent {
                                print("🧠 Reasoning content chunk: \(reasoningContent.prefix(100))")
                                onReasoningChunk(reasoningContent)
                            }
                            
                            // Handle regular content
                            if let content = streamResponse.choices.first?.delta.content {
                                onChunk(content)
                            }
                        } catch {
                            // Skip malformed JSON chunks
                            print("⚠️ Failed to parse chunk: \(error)")
                            print("Failed JSON: \(jsonString)")
                        }
                    }
                }
            }
        }
        
        // Process any remaining buffered data
        if !buffer.isEmpty {
            stringBuffer += String(decoding: buffer, as: UTF8.self)
        }
        
        // Process any remaining lines in string buffer
        if !stringBuffer.isEmpty {
            let remainingLines = stringBuffer.components(separatedBy: .newlines)
            for line in remainingLines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLine.isEmpty, trimmedLine != "data: [DONE]" else { continue }
                
                if trimmedLine.hasPrefix("data: ") {
                    let jsonString = String(trimmedLine.dropFirst(6))
                    if let jsonData = jsonString.data(using: .utf8) {
                        do {
                            let streamResponse = try JSONDecoder().decode(ChatStreamResponse.self, from: jsonData)
                            
                            // Handle reasoning content (for GPT-oss models)
                            if let reasoningContent = streamResponse.choices.first?.delta.reasoningContent {
                                print("🧠 Final reasoning content chunk: \(reasoningContent.prefix(100))")
                                onReasoningChunk(reasoningContent)
                            }
                            
                            // Handle regular content
                            if let content = streamResponse.choices.first?.delta.content {
                                onChunk(content)
                            }
                        } catch {
                            print("⚠️ Failed to parse final chunk: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    enum NetworkError: LocalizedError {
        case invalidURL
        case connectionFailed(String)
        case invalidResponse
        case serverError(statusCode: Int)
        case noContent
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid server address format"
            case .connectionFailed(let message):
                return "Connection failed: \(message)"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let statusCode):
                return "Server error (status code: \(statusCode))"
            case .noContent:
                return "No content received from server"
            }
        }
    }
}

// MARK: - Level Up API (AssistantOS backend)

enum LevelUpError: LocalizedError, Equatable {
    case invalidBaseURL
    case invalidResponse
    case httpError(Int)
    case authenticationMissing
    case authenticationExpired
    case pathGenerationFailed(String)
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid API base URL."
        case .invalidResponse:
            return "Received invalid response from server."
        case .httpError(let code):
            return "Server error (\(code))."
        case .authenticationMissing:
            return "Not authenticated."
        case .authenticationExpired:
            return "Authentication expired."
        case .pathGenerationFailed(let message):
            return "Could not generate path: \(message)"
        case .decodingFailed(let message):
            return "Could not decode server response: \(message)"
        }
    }
}

struct LevelUpAPIConfig {
    // Server routes are rooted at /api/levelup (per backend contract).
    static let defaultBaseURL = "http://localhost:8080/api/levelup"
    static let baseURLKey = "levelUp.apiBaseURL"
    
    static var baseURLString: String {
        // Prefer explicit LevelUp base URL setting.
        if let explicit = UserDefaults.standard.string(forKey: baseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty {
            return explicit
        }
        
        // Fall back to the app-wide server address (used by Chat settings).
        // Users often configure this once; reuse it for LevelUp.
        if let server = UserDefaults.standard.string(forKey: "serverAddress")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !server.isEmpty {
            return server
        }
        
        return defaultBaseURL
    }
    
    static var baseURL: URL? {
        let raw = baseURLString
        let normalized = (raw.hasPrefix("http://") || raw.hasPrefix("https://")) ? raw : "http://\(raw)"
        guard var url = URL(string: normalized) else { return nil }
        
        // Ensure LevelUp path prefix is present.
        // If the caller sets just http://host:port, we append /api/levelup.
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            url.appendPathComponent("api")
            url.appendPathComponent("levelup")
        } else if !path.hasPrefix("api/levelup") && !path.contains("/api/levelup") {
            // Preserve any existing path but add the LevelUp prefix at the end.
            url.appendPathComponent("api")
            url.appendPathComponent("levelup")
        }
        
        return url
    }
    
    static let timeout: TimeInterval = 60
    static let longTimeout: TimeInterval = 120
}

protocol LevelUpAPIClient: Sendable {
    func authenticate(deviceID: String) async throws -> LevelUpAuthResponse
    func createGoal(_ goal: LevelUpCreateGoalRequest) async throws -> LevelUpGoalResponse
    func listGoals(status: String?) async throws -> [LevelUpGoalResponse]
    func getGoalDetail(goalID: String) async throws -> LevelUpGoalDetailResponse
    func updateGoal(goalID: String, request: LevelUpUpdateGoalRequest) async throws -> LevelUpGoalResponse
    func addContext(goalID: String, request: LevelUpAddContextRequest) async throws -> LevelUpContextResponse
    
    // Async plan generation: start job, poll job status, fetch plan when complete.
    func startPlanGeneration(goalID: String) async throws -> LevelUpPlanJobResponse
    func getJob(jobID: String) async throws -> LevelUpJobStatusResponse
    func getPlan(planID: String) async throws -> LevelUpPlanVersionResponse
    
    func startObjective(objectiveID: String) async throws -> LevelUpObjectiveResponse
    func completeObjective(objectiveID: String, notes: String?) async throws -> LevelUpObjectiveCompletionResponse
    func skipObjective(objectiveID: String) async throws -> LevelUpObjectiveResponse
    func syncProgress() async throws -> LevelUpProgressResponse
}

// MARK: - Token storage

final class LevelUpTokenStore: @unchecked Sendable {
    private let service = "com.levelup.auth"
    private let account = "device"
    
    private let userDefaultsKey = "levelUp.authStored"
    
    struct StoredAuth: Codable, Sendable {
        var token: String
        var expiresAt: Date
        var deviceID: String
    }
    
    func readAuth() -> StoredAuth? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // UI tests often run in environments where Keychain can behave differently;
        // fall back to UserDefaults when explicitly requested.
        if ProcessInfo.processInfo.arguments.contains("--levelup-token-userdefaults") {
            guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
            return try? decoder.decode(StoredAuth.self, from: data)
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? decoder.decode(StoredAuth.self, from: data)
    }
    
    func writeAuth(_ auth: StoredAuth) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(auth) else { return }
        
        if ProcessInfo.processInfo.arguments.contains("--levelup-token-userdefaults") {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
    
    func clearToken() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Request/Response models

struct LevelUpCreateGoalRequest: Codable, Sendable {
    var title: String
    var description: String?
    var targetDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case targetDate = "target_date"
    }
}

struct LevelUpUpdateGoalRequest: Codable, Sendable {
    var title: String?
    var status: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case status
    }
}

struct LevelUpAddContextRequest: Codable, Sendable {
    var content: String
    var source: String?
}

struct LevelUpGoalResponse: Codable, Sendable {
    var id: String
    var title: String
    var description: String?
    var createdAt: Date
    var updatedAt: Date?
    var targetDate: Date?
    var status: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case targetDate = "target_date"
        case status
    }
}

struct LevelUpGoalDetailResponse: Codable, Sendable {
    var id: String
    var title: String
    var description: String?
    var createdAt: Date
    var targetDate: Date?
    var status: String
    var objectives: [LevelUpObjectiveResponse]
    var contexts: [LevelUpContextResponse]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case createdAt = "created_at"
        case targetDate = "target_date"
        case status
        case objectives
        case contexts
    }
}

// MARK: - Plan version response (GET /api/levelup/plans/{plan_id})
//
// Backend contract:
// - top-level returns a plan version record with objectives + dependencies
// - many fields are nullable

struct LevelUpPlanVersionResponse: Codable, Sendable {
    let id: String
    let planId: String
    let version: Int
    let promptHash: String?
    let rawResponse: [String: AnyCodable]?
    let createdAt: Date
    let objectives: [LevelUpPlanObjectiveResponse]
    let dependencies: [LevelUpDependencyResponse]
    
    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case version
        case promptHash = "prompt_hash"
        case rawResponse = "raw_response"
        case createdAt = "created_at"
        case objectives
        case dependencies
    }
}

struct LevelUpPlanObjectiveResponse: Codable, Sendable {
    let id: String
    let goalId: String
    let title: String
    let description: String?
    let estimatedHours: Double?
    let pointsValue: Int
    let tier: String
    let position: Int
    let status: String
    let purpose: String
    let unlocks: String?
    let availableAt: Date?
    let completedAt: Date?
    let completionNotes: String?
    let createdAt: Date
    let updatedAt: Date
    let dependencies: [LevelUpDependencyResponse]
    
    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case title
        case description
        case estimatedHours = "estimated_hours"
        case pointsValue = "points_value"
        case tier
        case position
        case status
        case purpose
        case unlocks
        case availableAt = "available_at"
        case completedAt = "completed_at"
        case completionNotes = "completion_notes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case dependencies
    }
}

// Objective response used by /objectives endpoints (kept for compatibility with those routes).
struct LevelUpObjectiveResponse: Codable, Sendable {
    var id: String
    var title: String
    var description: String
    var estimatedHours: Double
    var pointsValue: Int
    var tier: String
    var position: Int
    var status: String
    var purpose: String
    var unlocks: String
    var dependsOn: [String]
    var contextSources: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case estimatedHours = "estimated_hours"
        case pointsValue = "points_value"
        case tier
        case position
        case status
        case purpose
        case unlocks
        case dependsOn = "depends_on"
        case contextSources = "context_sources"
    }
}

struct LevelUpDependencyResponse: Codable, Sendable {
    var from: String
    var to: String
    var required: Bool
    
    enum CodingKeys: String, CodingKey {
        // plan graph uses from_id/to_id; older endpoints used from/to
        case fromId = "from_id"
        case toId = "to_id"
        case from
        case to
        case required
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.required = (try? c.decode(Bool.self, forKey: .required)) ?? true
        
        if let fromId = try c.decodeIfPresent(String.self, forKey: .fromId),
           let toId = try c.decodeIfPresent(String.self, forKey: .toId) {
            self.from = fromId
            self.to = toId
            return
        }
        // fallback to legacy keys
        self.from = try c.decode(String.self, forKey: .from)
        self.to = try c.decode(String.self, forKey: .to)
    }

    init(from: String, to: String, required: Bool = true) {
        self.from = from
        self.to = to
        self.required = required
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(from, forKey: .fromId)
        try c.encode(to, forKey: .toId)
        try c.encode(required, forKey: .required)
    }
}

struct LevelUpProgressResponse: Codable, Sendable {
    var currentLevel: Int
    var totalPoints: Int
    var pointsToNextLevel: Int
    var currentStreak: Int
    var longestStreak: Int
    var freezeDaysAvailable: Int
    
    enum CodingKeys: String, CodingKey {
        case currentLevel = "current_level"
        case totalPoints = "total_points"
        case pointsToNextLevel = "points_to_next_level"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case freezeDaysAvailable = "freeze_days_available"
    }
}

struct LevelUpContextResponse: Codable, Sendable {
    var id: String
    var content: String
    var source: String?
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case source
        case createdAt = "created_at"
    }
}

struct LevelUpAuthResponse: Codable, Sendable {
    var token: String
    var expiresAt: Date
    var deviceID: String
    
    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
        case deviceID = "device_id"
    }
}

struct LevelUpPlanJobResponse: Codable, Sendable {
    var jobID: String
    var planID: String
    var status: String
    
    enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case planID = "plan_id"
        case status
    }
}

struct LevelUpJobStatusResponse: Codable, Sendable {
    var jobID: String
    var goalID: String?
    var planID: String?
    var type: String?
    var status: String
    var error: String?
    var planVersionID: String?
    var diffID: String?
    var startedAt: Date?
    var finishedAt: Date?
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        // Backends may return either `job_id` or `id`.
        case jobIDLegacy = "job_id"
        case id
        case goalID = "goal_id"
        case planID = "plan_id"
        case type
        case status
        case error
        case planVersionID = "plan_version_id"
        case diffID = "diff_id"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        // Prefer `job_id` if present, otherwise fall back to `id`.
        if let legacy = try c.decodeIfPresent(String.self, forKey: .jobIDLegacy) {
            self.jobID = legacy
        } else if let modern = try c.decodeIfPresent(String.self, forKey: .id) {
            self.jobID = modern
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected job identifier under `job_id` or `id`.")
            )
        }
        
        self.goalID = try c.decodeIfPresent(String.self, forKey: .goalID)
        self.planID = try c.decodeIfPresent(String.self, forKey: .planID)
        self.type = try c.decodeIfPresent(String.self, forKey: .type)
        self.status = try c.decode(String.self, forKey: .status)
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
        self.planVersionID = try c.decodeIfPresent(String.self, forKey: .planVersionID)
        self.diffID = try c.decodeIfPresent(String.self, forKey: .diffID)
        self.startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        self.finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    // Convenience initializer for mocks/tests (since we use a custom Decodable init).
    init(
        jobID: String,
        status: String,
        planVersionID: String? = nil,
        error: String? = nil,
        goalID: String? = nil,
        planID: String? = nil,
        type: String? = nil,
        diffID: String? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.jobID = jobID
        self.goalID = goalID
        self.planID = planID
        self.type = type
        self.status = status
        self.error = error
        self.planVersionID = planVersionID
        self.diffID = diffID
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.createdAt = createdAt
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // Encode the modern field name.
        try c.encode(jobID, forKey: .id)
        try c.encodeIfPresent(goalID, forKey: .goalID)
        try c.encodeIfPresent(planID, forKey: .planID)
        try c.encodeIfPresent(type, forKey: .type)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(error, forKey: .error)
        try c.encodeIfPresent(planVersionID, forKey: .planVersionID)
        try c.encodeIfPresent(diffID, forKey: .diffID)
        try c.encodeIfPresent(startedAt, forKey: .startedAt)
        try c.encodeIfPresent(finishedAt, forKey: .finishedAt)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct LevelUpObjectiveCompletionResponse: Codable, Sendable {
    var objectiveID: String
    var pointsEarned: Int
    var newLevel: Int?
    var newTotalPoints: Int
    var unlockedObjectives: [String]
    var currentStreak: Int?
    
    enum CodingKeys: String, CodingKey {
        case objectiveID = "objective_id"
        case pointsEarned = "points_earned"
        case newLevel = "new_level"
        case newTotalPoints = "new_total_points"
        case unlockedObjectives = "unlocked_objectives"
        case currentStreak = "current_streak"
    }
}

// MARK: - Real implementation

final class LevelUpAPIService: LevelUpAPIClient, @unchecked Sendable {
    private let session: URLSession
    private let tokenStore: LevelUpTokenStore
    private let authRefreshLeeway: TimeInterval = 60 * 60 * 24 * 3 // 3 days
    
    init(tokenStore: LevelUpTokenStore = LevelUpTokenStore()) {
        self.tokenStore = tokenStore
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = LevelUpAPIConfig.timeout
        self.session = URLSession(configuration: config)
    }
    
    func authenticate(deviceID: String) async throws -> LevelUpAuthResponse {
        let url = try requireURL(pathComponents: ["auth", "device"])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = LevelUpAPIConfig.timeout
        
        struct Body: Codable {
            let deviceID: String
            enum CodingKeys: String, CodingKey { case deviceID = "device_id" }
        }
        request.httpBody = try jsonEncoder().encode(Body(deviceID: deviceID))
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        
        let decoded = try decode(LevelUpAuthResponse.self, from: data, http: http, context: "auth/device")
        tokenStore.writeAuth(.init(token: decoded.token, expiresAt: decoded.expiresAt, deviceID: decoded.deviceID))
        return decoded
    }
    
    func createGoal(_ goal: LevelUpCreateGoalRequest) async throws -> LevelUpGoalResponse {
        let url = try requireURL(pathComponents: ["goals"])
        var request = try await authorizedRequest(url: url, method: "POST", timeout: LevelUpAPIConfig.timeout)
        request.httpBody = try jsonEncoder().encode(goal)
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpGoalResponse.self, from: data, http: http, context: "goals:create")
    }
    
    func listGoals(status: String?) async throws -> [LevelUpGoalResponse] {
        let query = status.map { [URLQueryItem(name: "status", value: $0)] }
        let url = try requireURL(pathComponents: ["goals"], queryItems: query)
        let request = try await authorizedRequest(url: url, method: "GET", timeout: LevelUpAPIConfig.timeout)
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode([LevelUpGoalResponse].self, from: data, http: http, context: "goals:list")
    }
    
    func getGoalDetail(goalID: String) async throws -> LevelUpGoalDetailResponse {
        let url = try requireURL(pathComponents: ["goals", goalID])
        let request = try await authorizedRequest(url: url, method: "GET", timeout: LevelUpAPIConfig.timeout)
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpGoalDetailResponse.self, from: data, http: http, context: "goals:detail")
    }
    
    func updateGoal(goalID: String, request body: LevelUpUpdateGoalRequest) async throws -> LevelUpGoalResponse {
        let url = try requireURL(pathComponents: ["goals", goalID])
        var request = try await authorizedRequest(url: url, method: "PATCH", timeout: LevelUpAPIConfig.timeout)
        request.httpBody = try jsonEncoder().encode(body)
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpGoalResponse.self, from: data, http: http, context: "goals:update")
    }
    
    func addContext(goalID: String, request body: LevelUpAddContextRequest) async throws -> LevelUpContextResponse {
        let url = try requireURL(pathComponents: ["goals", goalID, "context"])
        var request = try await authorizedRequest(url: url, method: "POST", timeout: LevelUpAPIConfig.timeout)
        request.httpBody = try jsonEncoder().encode(body)
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpContextResponse.self, from: data, http: http, context: "goals:context")
    }
    
    func startPlanGeneration(goalID: String) async throws -> LevelUpPlanJobResponse {
        let url = try requireURL(pathComponents: ["goals", goalID, "plan"])
        var request = try await authorizedRequest(url: url, method: "POST", timeout: LevelUpAPIConfig.longTimeout)
        request.httpBody = Data()
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpPlanJobResponse.self, from: data, http: http, context: "goals:plan:start")
    }
    
    func getJob(jobID: String) async throws -> LevelUpJobStatusResponse {
        let url = try requireURL(pathComponents: ["jobs", jobID])
        let request = try await authorizedRequest(url: url, method: "GET", timeout: LevelUpAPIConfig.timeout)
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpJobStatusResponse.self, from: data, http: http, context: "jobs:status")
    }
    
    func getPlan(planID: String) async throws -> LevelUpPlanVersionResponse {
        let url = try requireURL(pathComponents: ["plans", planID])
        let request = try await authorizedRequest(url: url, method: "GET", timeout: LevelUpAPIConfig.longTimeout)
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpPlanVersionResponse.self, from: data, http: http, context: "plans:get")
    }
    
    func startObjective(objectiveID: String) async throws -> LevelUpObjectiveResponse {
        let url = try requireURL(pathComponents: ["objectives", objectiveID, "start"])
        let request = try await authorizedRequest(url: url, method: "POST", timeout: LevelUpAPIConfig.timeout)
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpObjectiveResponse.self, from: data, http: http, context: "objectives:start")
    }
    
    func completeObjective(objectiveID: String, notes: String?) async throws -> LevelUpObjectiveCompletionResponse {
        let url = try requireURL(pathComponents: ["objectives", objectiveID, "complete"])
        var request = try await authorizedRequest(url: url, method: "POST", timeout: LevelUpAPIConfig.timeout)
        
        struct Body: Codable { let notes: String? }
        request.httpBody = try jsonEncoder().encode(Body(notes: notes))
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpObjectiveCompletionResponse.self, from: data, http: http, context: "objectives:complete")
    }
    
    func skipObjective(objectiveID: String) async throws -> LevelUpObjectiveResponse {
        let url = try requireURL(pathComponents: ["objectives", objectiveID, "skip"])
        let request = try await authorizedRequest(url: url, method: "POST", timeout: LevelUpAPIConfig.timeout)
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpObjectiveResponse.self, from: data, http: http, context: "objectives:skip")
    }
    
    func syncProgress() async throws -> LevelUpProgressResponse {
        let url = try requireURL(pathComponents: ["user", "progress"])
        let request = try await authorizedRequest(url: url, method: "GET", timeout: LevelUpAPIConfig.timeout)
        
        let (data, http) = try await requestData(request)
        guard (200...299).contains(http.statusCode) else { throw LevelUpError.httpError(http.statusCode) }
        return try decode(LevelUpProgressResponse.self, from: data, http: http, context: "user:progress")
    }
    
    // MARK: - Helpers
    
    private func requireURL(pathComponents: [String], queryItems: [URLQueryItem]? = nil) throws -> URL {
        guard let base = LevelUpAPIConfig.baseURL else { throw LevelUpError.invalidBaseURL }
        var url = base
        for part in pathComponents {
            url.appendPathComponent(part)
        }
        
        guard let queryItems else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        guard let withQuery = components?.url else { return url }
        return withQuery
    }
    
    private func authorizedRequest(url: URL, method: String, timeout: TimeInterval) async throws -> URLRequest {
        let auth = try await ensureAuthenticated()
        guard !auth.token.isEmpty else { throw LevelUpError.authenticationMissing }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    private func ensureAuthenticated() async throws -> LevelUpTokenStore.StoredAuth {
        if let stored = tokenStore.readAuth() {
            let isExpired = stored.expiresAt <= Date()
            let shouldRefreshSoon = stored.expiresAt <= Date().addingTimeInterval(authRefreshLeeway)
            if !isExpired && !shouldRefreshSoon {
                return stored
            }
            // Token expired or nearly expired: refresh via device auth.
            let refreshed = try await authenticate(deviceID: stored.deviceID)
            return .init(token: refreshed.token, expiresAt: refreshed.expiresAt, deviceID: refreshed.deviceID)
        }
        
        // No stored auth: create from current device ID.
        // UIDevice access is MainActor-isolated in newer SDKs.
        let deviceID = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString } ?? UUID().uuidString
        let authed = try await authenticate(deviceID: deviceID)
        return .init(token: authed.token, expiresAt: authed.expiresAt, deviceID: authed.deviceID)
    }
    
    private func requireHTTP(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else { throw LevelUpError.invalidResponse }
        return http
    }
    
    private func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds first (common backend default).
            if let date = LevelUpDateCoding.iso8601Fractional.date(from: string) {
                return date
            }
            if let date = LevelUpDateCoding.iso8601Basic.date(from: string) {
                return date
            }
            if let date = LevelUpDateCoding.parseNoTimezoneFractional(string) {
                return date
            }
            if let date = LevelUpDateCoding.posixNoTZ.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }
    
    private func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let string = LevelUpDateCoding.iso8601Fractional.string(from: date)
            try container.encode(string)
        }
        return encoder
    }
    
    private func requestData(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        let http = try requireHTTP(response)
        
        // Helpful debug when wiring up a new backend.
        if !(200...299).contains(http.statusCode) {
            debugPrintResponse(data: data, http: http)
        }
        return (data, http)
    }
    
    private func decode<T: Decodable>(_ type: T.Type, from data: Data, http: HTTPURLResponse, context: String) throws -> T {
        do {
            return try jsonDecoder().decode(T.self, from: data)
        } catch {
            debugPrint("⚠️ LevelUp decode failed (\(context)): \(error)")
            debugPrintResponse(data: data, http: http)
            throw LevelUpError.decodingFailed("\(context): \(error.localizedDescription)")
        }
    }
    
    private func debugPrintResponse(data: Data, http: HTTPURLResponse?) {
        let status = http.map { "\($0.statusCode)" } ?? "unknown"
        let contentType = http?.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body: \(data.count) bytes>"
        let snippet = String(body.prefix(2000))
        debugPrint("📡 LevelUp response status=\(status) contentType=\(contentType)\n\(snippet)")
    }
}

enum LevelUpDateCoding {
    static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    // Some backends return ISO-ish timestamps without timezone, e.g. "2026-01-12T18:27:02".
    // Treat these as UTC by default.
    static let posixNoTZ: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()
    
    // ISO-ish timestamps with fractional seconds but no timezone, e.g. "2025-12-13T18:29:21.349613".
    // DateFormatter needs a fixed fraction width, so we normalize to microseconds (6 digits).
    static let posixNoTZMicro: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return f
    }()
    
    static func parseNoTimezoneFractional(_ string: String) -> Date? {
        // Fast path: must contain fractional separator and no explicit timezone marker.
        // (If there's a timezone, ISO8601DateFormatter should have already handled it.)
        guard string.contains(".") else { return nil }
        guard !string.contains("Z"), !string.contains("+") else { return nil }
        
        // If there's an explicit numeric timezone offset at the end, let ISO8601 parse it.
        // Examples: ...-05:00, ...+0100
        if string.range(of: #"[+-]\d{2}:\d{2}$"#, options: .regularExpression) != nil { return nil }
        if string.range(of: #"[+-]\d{4}$"#, options: .regularExpression) != nil { return nil }
        
        let parts = string.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let base = String(parts[0])
        var frac = String(parts[1])
        
        // Keep only digits in fraction (defensive).
        frac = frac.filter(\.isNumber)
        if frac.isEmpty { return nil }
        
        // Normalize to 6 digits (microseconds): pad with zeros or truncate.
        if frac.count < 6 {
            frac = frac.padding(toLength: 6, withPad: "0", startingAt: 0)
        } else if frac.count > 6 {
            frac = String(frac.prefix(6))
        }
        
        return posixNoTZMicro.date(from: "\(base).\(frac)")
    }
}

// MARK: - AnyCodable
//
// Used for backend fields like `raw_response` where the JSON is arbitrary.
// Minimal, JSON-compatible Codable wrapper.

struct AnyCodable: Codable, Sendable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let b = try? container.decode(Bool.self) {
            self.value = b
        } else if let i = try? container.decode(Int.self) {
            self.value = i
        } else if let d = try? container.decode(Double.self) {
            self.value = d
        } else if let s = try? container.decode(String.self) {
            self.value = s
        } else if let arr = try? container.decode([AnyCodable].self) {
            self.value = arr.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value is not decodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let b as Bool:
            try container.encode(b)
        case let i as Int:
            try container.encode(i)
        case let d as Double:
            try container.encode(d)
        case let s as String:
            try container.encode(s)
        case let arr as [Any]:
            try container.encode(arr.map(AnyCodable.init))
        case let dict as [String: Any]:
            try container.encode(dict.mapValues(AnyCodable.init))
        default:
            // Best-effort: if it's already Codable via Encodable bridging, fail loudly.
            throw EncodingError.invalidValue(
                value,
                .init(codingPath: encoder.codingPath, debugDescription: "AnyCodable value is not encodable")
            )
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull):
            return true
        case let (a as Bool, b as Bool):
            return a == b
        case let (a as Int, b as Int):
            return a == b
        case let (a as Double, b as Double):
            return a == b
        case let (a as String, b as String):
            return a == b
        case let (a as [Any], b as [Any]):
            return a.count == b.count // shallow equality; good enough for tests/debug
        case let (a as [String: Any], b as [String: Any]):
            return a.keys == b.keys // shallow equality; good enough for tests/debug
        default:
            return false
        }
    }
}

// MARK: - Mock implementation (deterministic, for UI + tests)

final class MockLevelUpAPIService: LevelUpAPIClient, @unchecked Sendable {
    private var authed: Bool = false
    
    func authenticate(deviceID: String) async throws -> LevelUpAuthResponse {
        authed = true
        return LevelUpAuthResponse(token: "mock-token-\(deviceID)", expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 30), deviceID: deviceID)
    }
    
    func createGoal(_ goal: LevelUpCreateGoalRequest) async throws -> LevelUpGoalResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        return LevelUpGoalResponse(
            id: "goal_mock_1",
            title: goal.title,
            description: goal.description,
            createdAt: Date(),
            targetDate: goal.targetDate,
            status: "active"
        )
    }
    
    func listGoals(status: String?) async throws -> [LevelUpGoalResponse] {
        guard authed else { throw LevelUpError.authenticationMissing }
        return []
    }
    
    func getGoalDetail(goalID: String) async throws -> LevelUpGoalDetailResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        return LevelUpGoalDetailResponse(
            id: goalID,
            title: "Mock Goal",
            description: nil,
            createdAt: Date(),
            targetDate: nil,
            status: "active",
            objectives: [],
            contexts: []
        )
    }
    
    func updateGoal(goalID: String, request: LevelUpUpdateGoalRequest) async throws -> LevelUpGoalResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        return LevelUpGoalResponse(id: goalID, title: request.title ?? "Mock Goal", description: nil, createdAt: Date(), targetDate: nil, status: request.status ?? "active")
    }
    
    func addContext(goalID: String, request: LevelUpAddContextRequest) async throws -> LevelUpContextResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        return LevelUpContextResponse(id: "ctx_1", content: request.content, source: request.source, createdAt: Date())
    }
    
    func startPlanGeneration(goalID: String) async throws -> LevelUpPlanJobResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        return LevelUpPlanJobResponse(jobID: "job_1", planID: "plan_1", status: "queued")
    }
    
    func getJob(jobID: String) async throws -> LevelUpJobStatusResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        // Always succeed quickly for deterministic UI tests.
        return LevelUpJobStatusResponse(jobID: jobID, status: "succeeded", planVersionID: "v1", error: nil)
    }
    
    func getPlan(planID: String) async throws -> LevelUpPlanVersionResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        try await Task.sleep(nanoseconds: 150_000_000) // small delay for UI realism
        
        let dependencies: [LevelUpDependencyResponse] = [
            .init(from: "obj_1", to: "obj_2", required: true),
            .init(from: "obj_2", to: "obj_3", required: true)
        ]
        
        let now = Date()
        let objectives: [LevelUpPlanObjectiveResponse] = [
            .init(
                id: "obj_1",
                goalId: "goal_mock_1",
                title: "Define success criteria",
                description: "Write 3 measurable outcomes that define success for this goal.",
                estimatedHours: 1.5,
                pointsValue: 120,
                tier: "Foundation",
                position: 0,
                status: "available",
                purpose: "Clarifies what you’re building toward and reduces ambiguity.",
                unlocks: "Unlocks planning objectives.",
                availableAt: now,
                completedAt: nil,
                completionNotes: nil,
                createdAt: now,
                updatedAt: now,
                dependencies: []
            ),
            .init(
                id: "obj_2",
                goalId: "goal_mock_1",
                title: "Draft a 1-page plan",
                description: "Create a simple plan with milestones and a first week schedule.",
                estimatedHours: 2.0,
                pointsValue: 160,
                tier: "Foundation",
                position: 1,
                status: "locked",
                purpose: "Creates a concrete path and reduces decision fatigue.",
                unlocks: "Unlocks execution objectives.",
                availableAt: nil,
                completedAt: nil,
                completionNotes: nil,
                createdAt: now,
                updatedAt: now,
                dependencies: [.init(from: "obj_1", to: "obj_2", required: true)]
            ),
            .init(
                id: "obj_3",
                goalId: "goal_mock_1",
                title: "Ship the first tiny deliverable",
                description: "Deliver something small that proves momentum (doc, prototype, or first commit).",
                estimatedHours: 3.0,
                pointsValue: 220,
                tier: "Core",
                position: 0,
                status: "locked",
                purpose: "Turns planning into action and builds confidence.",
                unlocks: "Unlocks feedback loop objectives.",
                availableAt: nil,
                completedAt: nil,
                completionNotes: nil,
                createdAt: now,
                updatedAt: now,
                dependencies: [.init(from: "obj_2", to: "obj_3", required: true)]
            )
        ]
        
        return LevelUpPlanVersionResponse(
            id: "plan_version_1",
            planId: planID,
            version: 1,
            promptHash: nil,
            rawResponse: nil,
            createdAt: now,
            objectives: objectives,
            dependencies: dependencies
        )
    }
    
    func startObjective(objectiveID: String) async throws -> LevelUpObjectiveResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        return LevelUpObjectiveResponse(
            id: objectiveID,
            title: "Started",
            description: "",
            estimatedHours: 0,
            pointsValue: 0,
            tier: "Foundation",
            position: 0,
            status: "running",
            purpose: "",
            unlocks: "",
            dependsOn: [],
            contextSources: []
        )
    }
    
    func completeObjective(objectiveID: String, notes: String?) async throws -> LevelUpObjectiveCompletionResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        return LevelUpObjectiveCompletionResponse(
            objectiveID: objectiveID,
            pointsEarned: 48,
            newLevel: 2,
            newTotalPoints: 148,
            unlockedObjectives: ["obj_2"],
            currentStreak: 1
        )
    }
    
    func skipObjective(objectiveID: String) async throws -> LevelUpObjectiveResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        return LevelUpObjectiveResponse(
            id: objectiveID,
            title: "Skipped",
            description: "",
            estimatedHours: 0,
            pointsValue: 0,
            tier: "Foundation",
            position: 0,
            status: "skipped",
            purpose: "",
            unlocks: "",
            dependsOn: [],
            contextSources: []
        )
    }
    
    func syncProgress() async throws -> LevelUpProgressResponse {
        guard authed else { throw LevelUpError.authenticationMissing }
        return LevelUpProgressResponse(currentLevel: 1, totalPoints: 0, pointsToNextLevel: 100, currentStreak: 0, longestStreak: 0, freezeDaysAvailable: 0)
    }
}

enum LevelUpAPIFactory {
    static func makeClient() -> LevelUpAPIClient {
        // Force mock mode for UI tests and whenever explicitly requested.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--levelup-mock-api") || args.contains("--ui-testing") {
            return MockLevelUpAPIService()
        }
        return LevelUpAPIService()
    }
}

