//
//  Models.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import Foundation

struct Message: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

struct AIModel: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let size: String
    let description: String
}

struct Conversation: Identifiable {
    let id = UUID()
    var messages: [Message]
    let createdAt: Date
}

class ConversationManager: ObservableObject {
    @Published var currentConversation: Conversation
    @Published var conversationHistory: [Conversation] = []
    @Published var isLoading: Bool = false
    var serverAddress: String?
    var systemPrompt: String?
    var selectedModel: String = "qwen2.5:latest"
    
    init() {
        self.currentConversation = Conversation(messages: [], createdAt: Date())
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
        
        Task {
            do {
                // Convert conversation messages to API format
                let apiMessages = currentConversation.messages.map { message in
                    ChatMessage(
                        role: message.isUser ? "user" : "assistant",
                        content: message.content
                    )
                }
                
                // Send to server
                let response = try await NetworkManager.shared.sendChatMessage(
                    to: serverAddress,
                    model: selectedModel,
                    messages: apiMessages,
                    systemPrompt: systemPrompt,
                    temperature: 0.7,
                    maxTokens: 1024
                )
                
                await MainActor.run {
                    let aiResponse = Message(
                        content: response,
                        isUser: false,
                        timestamp: Date()
                    )
                    self.currentConversation.messages.append(aiResponse)
                    self.isLoading = false
                }
            } catch let error as NetworkManager.NetworkError {
                await MainActor.run {
                    let errorMessage = Message(
                        content: "❌ Error: \(error.localizedDescription ?? "Unknown error")\n\nPlease check your server connection and try again.",
                        isUser: false,
                        timestamp: Date()
                    )
                    self.currentConversation.messages.append(errorMessage)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = Message(
                        content: "❌ Unexpected error: \(error.localizedDescription)\n\nPlease try again.",
                        isUser: false,
                        timestamp: Date()
                    )
                    self.currentConversation.messages.append(errorMessage)
                    self.isLoading = false
                }
            }
        }
    }
    
    func newConversation() {
        if !currentConversation.messages.isEmpty {
            conversationHistory.append(currentConversation)
        }
        currentConversation = Conversation(messages: [], createdAt: Date())
    }
    
    func deleteHistory() {
        conversationHistory.removeAll()
        currentConversation = Conversation(messages: [], createdAt: Date())
    }
}

