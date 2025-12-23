//
//  NetworkManager.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import Foundation

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
    init(
        model: String,
        messages: [ChatMessage],
        provider: String? = nil,
        temperature: Double?,
        stream: Bool,
        safetyLevel: String?,
        reasoningEffort: String? = nil,
        conversationId: String? = nil,
        includeReasoning: Bool? = nil
    ) {
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

/// Local file/image attachment for multipart chat requests.
struct ChatCompletionFile {
    let filename: String
    let mimeType: String
    let data: Data
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
        let reasoningContent: String?  // For GPT-oss thinking (reasoning_content)
        let reasoning: String?  // For Ollama native reasoning output
        
        enum CodingKeys: String, CodingKey {
            case role, content, reasoning
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
        let reasoningContent: String?  // For GPT-oss thinking (reasoning_content)
        let reasoning: String?  // For Ollama native reasoning output
        
        enum CodingKeys: String, CodingKey {
            case role, content, reasoning
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
    
    private func normalizeServerAddress(_ serverAddress: String) throws -> String {
        guard !serverAddress.isEmpty else {
            throw NetworkError.invalidURL
        }
        var urlString = serverAddress
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        return urlString
    }
    
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
        let urlString = try normalizeServerAddress(serverAddress)
        
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
    
    // MARK: - Chat (JSON or multipart with attachments)
    
    private func buildChatRequest(
        model: String,
        messages: [ChatMessage],
        systemPrompt: String?,
        provider: String?,
        temperature: Double,
        stream: Bool,
        safetyLevel: String?,
        reasoningEffort: String?,
        conversationId: String?
    ) -> ChatRequest {
        var allMessages: [ChatMessage] = []
        if let systemPrompt, !systemPrompt.isEmpty {
            allMessages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        allMessages.append(contentsOf: messages)
        
        return ChatRequest(
            model: model,
            messages: allMessages,
            provider: provider,
            temperature: temperature,
            stream: stream,
            safetyLevel: safetyLevel,
            reasoningEffort: reasoningEffort,
            conversationId: conversationId,
            includeReasoning: reasoningEffort != nil ? true : nil
        )
    }
    
    private func makeMultipartBody(
        boundary: String,
        payloadJson: String,
        files: [ChatCompletionFile]
    ) -> Data {
        var body = Data()
        
        // payload (required): JSON string
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"payload\"\r\n\r\n".data(using: .utf8)!)
        body.append(payloadJson.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // files (optional, repeated)
        for file in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
    
    // Send chat message
    func sendChatMessage(
        to serverAddress: String,
        model: String,
        messages: [ChatMessage],
        files: [ChatCompletionFile] = [],
        systemPrompt: String? = nil,
        provider: String? = nil,
        safetyLevel: String? = nil,
        temperature: Double = 0.7,
        reasoningEffort: String? = nil,
        conversationId: String? = nil
    ) async throws -> String {
        let urlString = try normalizeServerAddress(serverAddress)
        
        guard let url = URL(string: "\(urlString)/v1/chat/completions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0
        
        let chatRequest = buildChatRequest(
            model: model,
            messages: messages,
            systemPrompt: systemPrompt,
            provider: provider,
            temperature: temperature,
            stream: false,
            safetyLevel: safetyLevel,
            reasoningEffort: reasoningEffort,
            conversationId: conversationId
        )
        
        if files.isEmpty {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(chatRequest)
            
            // Debug: Print the actual JSON being sent
            if let jsonData = request.httpBody,
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Sending request to server:")
                print(jsonString)
            }
        } else {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            let payloadData = try JSONEncoder().encode(chatRequest)
            let payloadJson = String(decoding: payloadData, as: UTF8.self)
            request.httpBody = makeMultipartBody(boundary: boundary, payloadJson: payloadJson, files: files)
            
            print("Sending multipart request with \(files.count) file(s)")
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
        files: [ChatCompletionFile] = [],
        systemPrompt: String? = nil,
        provider: String? = nil,
        safetyLevel: String? = nil,
        temperature: Double = 0.7,
        reasoningEffort: String? = nil,
        conversationId: String? = nil,
        onChunk: @escaping (String) -> Void,
        onReasoningChunk: @escaping (String) -> Void = { _ in }
    ) async throws {
        let urlString = try normalizeServerAddress(serverAddress)
        
        guard let url = URL(string: "\(urlString)/v1/chat/completions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120.0
        
        let chatRequest = buildChatRequest(
            model: model,
            messages: messages,
            systemPrompt: systemPrompt,
            provider: provider,
            temperature: temperature,
            stream: true,
            safetyLevel: safetyLevel,
            reasoningEffort: reasoningEffort,
            conversationId: conversationId
        )
        
        if files.isEmpty {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(chatRequest)
            
            // Debug: Print the actual JSON being sent
            if let jsonData = request.httpBody,
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Sending streaming request to server:")
                print(jsonString)
            }
        } else {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            let payloadData = try JSONEncoder().encode(chatRequest)
            let payloadJson = String(decoding: payloadData, as: UTF8.self)
            request.httpBody = makeMultipartBody(boundary: boundary, payloadJson: payloadJson, files: files)
            
            print("Sending streaming multipart request with \(files.count) file(s)")
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
                            
                            // Handle reasoning content (for GPT-oss models via reasoning_content)
                            if let reasoningContent = streamResponse.choices.first?.delta.reasoningContent {
                                print("🧠 Reasoning content chunk (reasoning_content): \(reasoningContent.prefix(100))")
                                onReasoningChunk(reasoningContent)
                            }
                            
                            // Handle reasoning (for Ollama native reasoning output)
                            if let reasoning = streamResponse.choices.first?.delta.reasoning {
                                print("🧠 Reasoning chunk (reasoning): \(reasoning.prefix(100))")
                                onReasoningChunk(reasoning)
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
                            
                            // Handle reasoning content (for GPT-oss models via reasoning_content)
                            if let reasoningContent = streamResponse.choices.first?.delta.reasoningContent {
                                print("🧠 Final reasoning content chunk (reasoning_content): \(reasoningContent.prefix(100))")
                                onReasoningChunk(reasoningContent)
                            }
                            
                            // Handle reasoning (for Ollama native reasoning output)
                            if let reasoning = streamResponse.choices.first?.delta.reasoning {
                                print("🧠 Final reasoning chunk (reasoning): \(reasoning.prefix(100))")
                                onReasoningChunk(reasoning)
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

