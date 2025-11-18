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
    let isUser: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool, timestamp: Date) {
        self.id = UUID()
        self.content = content
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
    
    init() {
        self.currentConversation = Conversation(messages: [], createdAt: Date())
        loadConversationHistory()
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
                let apiMessages = currentConversation.messages.prefix(currentConversation.messages.count - 1).map { message in
                    ChatMessage(
                        role: message.isUser ? "user" : "assistant",
                        content: message.content
                    )
                }
                
                var accumulatedResponse = ""
                
                // Send to server with streaming
                try await NetworkManager.shared.sendChatMessageStreaming(
                    to: serverAddress,
                    model: selectedModel,
                    messages: Array(apiMessages),
                    systemPrompt: systemPrompt,
                    temperature: 0.7,
                    maxTokens: 1024
                ) { chunk in
                    // Accumulate the chunks and update the message on the main thread
                    accumulatedResponse += chunk
                    
                    // Capture the current response to avoid data race
                    let currentResponse = accumulatedResponse
                    
                    Task { @MainActor in
                        // Update the message content
                        if messageIndex < self.currentConversation.messages.count {
                            self.currentConversation.messages[messageIndex] = Message(
                                content: currentResponse,
                                isUser: false,
                                timestamp: self.currentConversation.messages[messageIndex].timestamp
                            )
                        }
                    }
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

