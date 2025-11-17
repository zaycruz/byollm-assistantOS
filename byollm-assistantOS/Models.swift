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
    var serverAddress: String?
    var systemPrompt: String?
    
    init() {
        self.currentConversation = Conversation(messages: [], createdAt: Date())
    }
    
    func sendMessage(_ content: String) {
        let userMessage = Message(content: content, isUser: true, timestamp: Date())
        currentConversation.messages.append(userMessage)
        
        // TODO: Replace with actual API call to serverAddress when configured
        // For now, simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let aiResponse = Message(
                content: self.serverAddress?.isEmpty ?? true 
                    ? "Please configure your server address in Settings to connect to your LLM."
                    : "This is a simulated response. API integration with \(self.serverAddress ?? "") coming soon.",
                isUser: false,
                timestamp: Date()
            )
            self.currentConversation.messages.append(aiResponse)
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

