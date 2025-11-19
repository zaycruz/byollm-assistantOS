//
//  Models.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import Foundation

struct Message: Identifiable, Equatable, Codable {
    let id: UUID
    let content: String
    let thinkingContent: String?  // Stores thinking tokens separately
    let isUser: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool, timestamp: Date, thinkingContent: String? = nil) {
        self.id = UUID()
        self.content = content
        self.thinkingContent = thinkingContent
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

struct AIModel: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let size: String
    let description: String
}

struct Conversation: Identifiable, Codable {
    let id: UUID
    var messages: [Message]
    let createdAt: Date
    
    init(messages: [Message], createdAt: Date) {
        self.id = UUID()
        self.messages = messages
        self.createdAt = createdAt
    }
}

@MainActor
class ConversationManager: ObservableObject {
    @Published var currentConversation: Conversation
    @Published var conversationHistory: [Conversation] = []
    @Published var isLoading: Bool = false
    var serverAddress: String?
    var systemPrompt: String?
    var selectedModel: String = "qwen2.5:latest"
    var safetyLevel: String = "medium"
    
    init() {
        self.currentConversation = Conversation(messages: [], createdAt: Date())
        loadConversationHistory()
    }
    
    // MARK: - Thinking Token Parsing
    
    /// Check if the current model supports thinking tokens (Qwen models)
    private func shouldParseThinkingTokens() -> Bool {
        let modelLower = selectedModel.lowercased()
        return modelLower.contains("qwen") || modelLower.contains("qwq")
    }
    
    /// Parses response to separate thinking tokens from actual content
    /// Supports multiple formats: <think>, <thinking>, and similar tags
    private func parseThinkingTokens(from response: String) -> (thinking: String?, content: String) {
        // Only parse thinking tokens for Qwen models
        guard shouldParseThinkingTokens() else {
            print("⏭️ Skipping thinking token parsing (not a Qwen model)")
            return (thinking: nil, content: response)
        }
        
        print("🔍 Attempting to parse thinking tokens from response (\(response.count) chars)")
        print("📝 First 200 chars: \(response.prefix(200))")
        
        var cleanedResponse = response
        var thinkingContent: String? = nil
        
        // Pattern 1: <think>...</think> or <thinking>...</thinking>
        let thinkPatterns = [
            #"<think>(.*?)</think>"#,
            #"<thinking>(.*?)</thinking>"#,
            #"<THINK>(.*?)</THINK>"#,
            #"<THINKING>(.*?)</THINKING>"#
        ]
        
        for pattern in thinkPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                let nsRange = NSRange(cleanedResponse.startIndex..<cleanedResponse.endIndex, in: cleanedResponse)
                
                if let match = regex.firstMatch(in: cleanedResponse, options: [], range: nsRange) {
                    print("✅ Found thinking tokens with pattern: \(pattern)")
                    
                    // Extract thinking content
                    if let thinkRange = Range(match.range(at: 1), in: cleanedResponse) {
                        thinkingContent = String(cleanedResponse[thinkRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        print("💭 Extracted thinking content: \(thinkingContent?.count ?? 0) chars")
                    }
                    
                    // Remove thinking tags from response
                    if let fullRange = Range(match.range, in: cleanedResponse) {
                        cleanedResponse.removeSubrange(fullRange)
                        cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                        print("✂️ Cleaned response: \(cleanedResponse.count) chars")
                    }
                    
                    break
                }
            }
        }
        
        if thinkingContent == nil {
            print("❌ No thinking tokens found in response")
        }
        
        return (thinking: thinkingContent, content: cleanedResponse)
    }
    
    // MARK: - Persistence
    
    private func saveConversationHistory() {
        // Also save the current conversation if it has messages
        var historyToSave = conversationHistory
        if !currentConversation.messages.isEmpty {
            // Check if current conversation is already in history (by id)
            if let index = historyToSave.firstIndex(where: { $0.id == currentConversation.id }) {
                // Update existing entry
                historyToSave[index] = currentConversation
            } else {
                // Add current conversation at the beginning
                historyToSave.insert(currentConversation, at: 0)
            }
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(historyToSave)
            UserDefaults.standard.set(data, forKey: "conversationHistory")
        } catch {
            print("Failed to save conversation history: \(error)")
        }
    }
    
    private func loadConversationHistory() {
        guard let data = UserDefaults.standard.data(forKey: "conversationHistory") else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedHistory = try decoder.decode([Conversation].self, from: data)
            
            // Load the most recent conversation as current, rest as history
            if let mostRecent = loadedHistory.first {
                currentConversation = mostRecent
                conversationHistory = Array(loadedHistory.dropFirst())
            } else {
                conversationHistory = loadedHistory
            }
        } catch {
            print("Failed to load conversation history: \(error)")
            conversationHistory = []
        }
    }
    
    func sendMessage(_ content: String) {
        let userMessage = Message(content: content, isUser: true, timestamp: Date())
        currentConversation.messages.append(userMessage)
        
        // Check if server is configured
        guard let serverAddress = serverAddress, !serverAddress.isEmpty else {
            let errorMessage = Message(
                content: "⚠️ Please configure your server address in Settings → Server Connection to start chatting with your LLM.",
                isUser: false,
                timestamp: Date()
            )
            currentConversation.messages.append(errorMessage)
            return
        }
        
        isLoading = true
        
        // Create an empty message for streaming response
        let placeholderMessage = Message(content: "", isUser: false, timestamp: Date())
        currentConversation.messages.append(placeholderMessage)
        let messageIndex = currentConversation.messages.count - 1
        
        Task {
            do {
                // Convert conversation messages to API format (excluding the placeholder)
                // For assistant messages, we send only the content without thinking tags
                // (thinking is internal to the model and shouldn't be in conversation history)
                let apiMessages = currentConversation.messages.prefix(currentConversation.messages.count - 1).map { message in
                    ChatMessage(
                        role: message.isUser ? "user" : "assistant",
                        content: message.content  // Content is already cleaned (thinking removed)
                    )
                }
                
                print("📤 Sending \(apiMessages.count) messages to API")
                
                var accumulatedResponse = ""
                
                // Send to server with streaming
                try await NetworkManager.shared.sendChatMessageStreaming(
                    to: serverAddress,
                    model: selectedModel,
                    messages: Array(apiMessages),
                    systemPrompt: systemPrompt,
                    safetyLevel: safetyLevel,
                    temperature: 0.7
                ) { chunk in
                    // Accumulate the chunks and update the message on the main thread
                    accumulatedResponse += chunk
                    
                    // Debug: Log chunk and accumulated length
                    print("📦 Chunk received (\(chunk.count) chars), total accumulated: \(accumulatedResponse.count) chars")
                    
                    // Capture the current response to avoid data race
                    let currentResponse = accumulatedResponse
                    
                    Task { @MainActor in
                        // For Qwen models, show the raw accumulated response during streaming
                        // We'll parse thinking tokens at the end to avoid cutting off incomplete tags
                        if messageIndex < self.currentConversation.messages.count {
                            if self.shouldParseThinkingTokens() {
                                // During streaming, show everything (including incomplete tags)
                                // This prevents truncation and shows the thinking process in real-time
                                self.currentConversation.messages[messageIndex] = Message(
                                    content: currentResponse,
                                    isUser: false,
                                    timestamp: self.currentConversation.messages[messageIndex].timestamp,
                                    thinkingContent: nil
                                )
                            } else {
                                // For non-Qwen models, just show the content normally
                                self.currentConversation.messages[messageIndex] = Message(
                                    content: currentResponse,
                                    isUser: false,
                                    timestamp: self.currentConversation.messages[messageIndex].timestamp,
                                    thinkingContent: nil
                                )
                            }
                        }
                    }
                }
                
                // After streaming is complete, parse thinking tokens
                print("✅ Streaming complete! Total response: \(accumulatedResponse.count) chars")
                print("📄 Full response preview: \(accumulatedResponse.prefix(500))")
                
                let finalParsed = self.parseThinkingTokens(from: accumulatedResponse)
                if messageIndex < self.currentConversation.messages.count {
                    self.currentConversation.messages[messageIndex] = Message(
                        content: finalParsed.content,
                        isUser: false,
                        timestamp: self.currentConversation.messages[messageIndex].timestamp,
                        thinkingContent: finalParsed.thinking
                    )
                }
                
                self.isLoading = false
                self.saveConversationHistory()
            } catch let error as NetworkManager.NetworkError {
                // Replace the placeholder with an error message
                if messageIndex < self.currentConversation.messages.count {
                    self.currentConversation.messages[messageIndex] = Message(
                        content: "❌ Error: \(error.localizedDescription ?? "Unknown error")\n\nPlease check your server connection and try again.",
                        isUser: false,
                        timestamp: self.currentConversation.messages[messageIndex].timestamp
                    )
                }
                self.isLoading = false
                self.saveConversationHistory()
            } catch {
                // Replace the placeholder with an error message
                if messageIndex < self.currentConversation.messages.count {
                    self.currentConversation.messages[messageIndex] = Message(
                        content: "❌ Unexpected error: \(error.localizedDescription)\n\nPlease try again.",
                        isUser: false,
                        timestamp: self.currentConversation.messages[messageIndex].timestamp
                    )
                }
                self.isLoading = false
                self.saveConversationHistory()
            }
        }
    }
    
    func newConversation() {
        if !currentConversation.messages.isEmpty {
            // Only add to history if not already there
            if !conversationHistory.contains(where: { $0.id == currentConversation.id }) {
                conversationHistory.insert(currentConversation, at: 0)
            }
        }
        currentConversation = Conversation(messages: [], createdAt: Date())
        saveConversationHistory()
    }
    
    func deleteHistory() {
        conversationHistory.removeAll()
        currentConversation = Conversation(messages: [], createdAt: Date())
        saveConversationHistory()
    }
    
    func loadConversation(_ conversation: Conversation) {
        // Save current conversation if it has messages and is not already in history
        if !currentConversation.messages.isEmpty && !conversationHistory.contains(where: { $0.id == currentConversation.id }) {
            conversationHistory.insert(currentConversation, at: 0)
        }
        
        // Remove the selected conversation from history
        conversationHistory.removeAll { $0.id == conversation.id }
        
        // Set as current conversation
        currentConversation = conversation
        
        saveConversationHistory()
    }
}

