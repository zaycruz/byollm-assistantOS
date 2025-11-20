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
    var reasoningEffort: String = "medium"  // New property for reasoning effort
    private var currentTask: Task<Void, Never>?  // Track the current generation task
    
    init() {
        self.currentConversation = Conversation(messages: [], createdAt: Date())
        loadConversationHistory()
    }
    
    // MARK: - Stop Generation
    
    func stopGenerating() {
        print("🛑 Stopping generation...")
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        saveConversationHistory()
    }
    
    // MARK: - Thinking Token Parsing
    
    /// Check if the current model supports thinking tokens (Qwen and GPT-oss models)
    private func shouldParseThinkingTokens() -> Bool {
        let modelLower = selectedModel.lowercased()
        // Check for various naming patterns
        let hasQwen = modelLower.contains("qwen") || modelLower.contains("qwq")
        let hasGPTO = modelLower.contains("gpt-o") || modelLower.contains("gpto")
        let hasGPTOss = modelLower.contains("gpt-oss") || modelLower.contains("gptoss")
        let hasO1 = modelLower.contains("o1") || modelLower.contains("o3")
        
        let shouldParse = hasQwen || hasGPTO || hasGPTOss || hasO1
        print("🔍 shouldParseThinkingTokens for '\(selectedModel)': \(shouldParse)")
        return shouldParse
    }
    
    /// Check if the current model supports reasoning effort (GPT-oss and GPT-o models)
    func supportsReasoningEffort() -> Bool {
        let modelLower = selectedModel.lowercased()
        return modelLower.contains("gpt-oss") || modelLower.contains("gpt-o") || modelLower.contains("gpt-4o") || modelLower.contains("o1") || modelLower.contains("o3")
    }
    
    /// Parses response to separate thinking tokens from actual content
    /// Supports multiple formats: <think>, <thinking>, and similar tags
    /// Handles multiple thinking blocks by concatenating them
    private func parseThinkingTokens(from response: String) -> (thinking: String?, content: String) {
        // Only parse thinking tokens for models that support it
        guard shouldParseThinkingTokens() else {
            print("⏭️ Skipping thinking token parsing (model: \(selectedModel))")
            return (thinking: nil, content: response)
        }
        
        print("🔍 Parsing thinking tokens from response (\(response.count) chars)")
        print("📝 First 300 chars: \(response.prefix(300))")
        
        var cleanedResponse = response
        var allThinkingContent: [String] = []
        
        // Pattern 1: <think>...</think> or <thinking>...</thinking>
        // Make it case-insensitive and handle variations
        let thinkPatterns = [
            #"<think>(.*?)</think>"#,
            #"<thinking>(.*?)</thinking>"#,
            #"<THINK>(.*?)</THINK>"#,
            #"<THINKING>(.*?)</THINKING>"#,
            #"<Think>(.*?)</Think>"#,
            #"<Thinking>(.*?)</Thinking>"#
        ]
        
        // Process all patterns and collect all thinking blocks
        for pattern in thinkPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let nsRange = NSRange(cleanedResponse.startIndex..<cleanedResponse.endIndex, in: cleanedResponse)
                let matches = regex.matches(in: cleanedResponse, options: [], range: nsRange)
                
                if !matches.isEmpty {
                    print("✅ Found \(matches.count) thinking blocks with pattern: \(pattern)")
                    
                    // Extract all thinking content (in reverse to maintain string indices)
                    for match in matches.reversed() {
                        // Extract thinking content
                        if let thinkRange = Range(match.range(at: 1), in: cleanedResponse) {
                            let thinking = String(cleanedResponse[thinkRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            allThinkingContent.insert(thinking, at: 0) // Insert at front to maintain order
                            print("💭 Extracted thinking block: \(thinking.count) chars")
                        }
                        
                        // Remove thinking tags and content from response
                        if let fullRange = Range(match.range, in: cleanedResponse) {
                            cleanedResponse.removeSubrange(fullRange)
                        }
                    }
                    
                    // Clean up the response after removing all thinking blocks
                    cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("✂️ Cleaned response after removing \(matches.count) thinking blocks: \(cleanedResponse.count) chars")
                    
                    // Break after finding matches with one pattern
                    break
                }
            }
        }
        
        let finalThinking = allThinkingContent.isEmpty ? nil : allThinkingContent.joined(separator: "\n\n---\n\n")
        
        if finalThinking == nil {
            print("❌ No thinking tokens found in response")
            print("📋 Checking if <think> appears anywhere: \(response.contains("<think>"))")
            print("📋 Checking if <thinking> appears anywhere: \(response.contains("<thinking>"))")
        } else {
            print("✅ Consolidated \(allThinkingContent.count) thinking blocks into \(finalThinking!.count) chars")
        }
        
        return (thinking: finalThinking, content: cleanedResponse)
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
        
        currentTask = Task {
            do {
                // Check for cancellation
                try Task.checkCancellation()
                
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
                print("🤖 Using model: \(selectedModel)")
                print("⚙️ Safety level: \(safetyLevel)")
                
                var accumulatedResponse = ""
                var accumulatedReasoning = ""
                var isInsideThinkTag = false
                var thinkTagBuffer = ""
                var allThinkingBlocks: [String] = []  // Store multiple thinking blocks
                
                // Only send reasoning effort for models that support it (GPT-o models)
                let effectiveReasoningEffort = supportsReasoningEffort() ? reasoningEffort : nil
                
                print("🔧 Reasoning effort: \(effectiveReasoningEffort ?? "nil (not supported by this model)")")
                print("🧠 Supports reasoning effort: \(supportsReasoningEffort())")
                print("🔍 Should parse thinking tokens: \(shouldParseThinkingTokens())")
                print("🆔 Conversation ID: \(currentConversation.id.uuidString)")
                
                // Send to server with streaming
                try await NetworkManager.shared.sendChatMessageStreaming(
                    to: serverAddress,
                    model: selectedModel,
                    messages: Array(apiMessages),
                    systemPrompt: systemPrompt,
                    safetyLevel: safetyLevel,
                    temperature: 0.7,
                    reasoningEffort: effectiveReasoningEffort,
                    conversationId: currentConversation.id.uuidString,
                    onChunk: { chunk in
                        // Check for cancellation in the callback
                        guard !Task.isCancelled else { return }
                        
                        // For models with separate reasoning_content field, just accumulate normally
                        if effectiveReasoningEffort != nil {
                            accumulatedResponse += chunk
                            
                            let currentResponse = accumulatedResponse
                            let currentReasoning = accumulatedReasoning
                            
                            Task { @MainActor in
                                guard !Task.isCancelled else { return }
                                if messageIndex < self.currentConversation.messages.count {
                                    self.currentConversation.messages[messageIndex] = Message(
                                        content: currentResponse,
                                        isUser: false,
                                        timestamp: self.currentConversation.messages[messageIndex].timestamp,
                                        thinkingContent: currentReasoning.isEmpty ? nil : currentReasoning
                                    )
                                }
                            }
                        } else if self.shouldParseThinkingTokens() {
                            // For Qwen models, parse thinking tags in real-time during streaming
                            var processedChunk = chunk
                            
                            // Check if we're inside a think tag
                            if isInsideThinkTag {
                                // Look for closing tag
                                if let closeIndex = processedChunk.range(of: "</think>", options: .caseInsensitive) ??
                                   processedChunk.range(of: "</thinking>", options: .caseInsensitive) {
                                    // Extract thinking content before close tag
                                    let thinkingPart = String(processedChunk[..<closeIndex.lowerBound])
                                    thinkTagBuffer += thinkingPart
                                    
                                    // Store this thinking block
                                    allThinkingBlocks.append(thinkTagBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
                                    
                                    // Consolidate all thinking blocks
                                    accumulatedReasoning = allThinkingBlocks.joined(separator: "\n\n---\n\n")
                                    
                                    // Take content after close tag
                                    processedChunk = String(processedChunk[closeIndex.upperBound...])
                                    isInsideThinkTag = false
                                    thinkTagBuffer = ""
                                    
                                    print("💭 Closed think tag, total thinking blocks: \(allThinkingBlocks.count), total chars: \(accumulatedReasoning.count)")
                                } else {
                                    // Still inside think tag, accumulate in buffer (but don't display it)
                                    thinkTagBuffer += processedChunk
                                    processedChunk = ""
                                }
                            }
                            
                            // Check for opening think tag
                            if let openRange = processedChunk.range(of: "<think>", options: .caseInsensitive) ??
                               processedChunk.range(of: "<thinking>", options: .caseInsensitive) {
                                // Take content before open tag
                                let beforeThink = String(processedChunk[..<openRange.lowerBound])
                                accumulatedResponse += beforeThink
                                
                                // Start accumulating thinking content
                                isInsideThinkTag = true
                                thinkTagBuffer = ""
                                
                                // Check if closing tag is in same chunk
                                let afterOpen = String(processedChunk[openRange.upperBound...])
                                if let closeRange = afterOpen.range(of: "</think>", options: .caseInsensitive) ??
                                   afterOpen.range(of: "</thinking>", options: .caseInsensitive) {
                                    // Complete think tag in single chunk
                                    let thinkingContent = String(afterOpen[..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                                    allThinkingBlocks.append(thinkingContent)
                                    accumulatedReasoning = allThinkingBlocks.joined(separator: "\n\n---\n\n")
                                    
                                    // Take content after close tag
                                    let afterClose = String(afterOpen[closeRange.upperBound...])
                                    accumulatedResponse += afterClose
                                    
                                    isInsideThinkTag = false
                                    print("💭 Complete think tag in single chunk: \(thinkingContent.count) chars, total blocks: \(allThinkingBlocks.count)")
                                } else {
                                    // Think tag continues in next chunks
                                    thinkTagBuffer = afterOpen
                                }
                            } else if !isInsideThinkTag {
                                // Normal content outside think tags - only display this
                                accumulatedResponse += processedChunk
                            }
                            
                            let currentResponse = accumulatedResponse
                            let currentReasoning = accumulatedReasoning
                            
                            Task { @MainActor in
                                guard !Task.isCancelled else { return }
                                if messageIndex < self.currentConversation.messages.count {
                                    self.currentConversation.messages[messageIndex] = Message(
                                        content: currentResponse,
                                        isUser: false,
                                        timestamp: self.currentConversation.messages[messageIndex].timestamp,
                                        thinkingContent: currentReasoning.isEmpty ? nil : currentReasoning
                                    )
                                }
                            }
                        } else {
                            // No thinking parsing needed
                            accumulatedResponse += chunk
                            
                            let currentResponse = accumulatedResponse
                            
                            Task { @MainActor in
                                guard !Task.isCancelled else { return }
                                if messageIndex < self.currentConversation.messages.count {
                                    self.currentConversation.messages[messageIndex] = Message(
                                        content: currentResponse,
                                        isUser: false,
                                        timestamp: self.currentConversation.messages[messageIndex].timestamp,
                                        thinkingContent: nil
                                    )
                                }
                            }
                        }
                    },
                    onReasoningChunk: { reasoningChunk in
                        // Accumulate the reasoning chunks (from GPT-oss reasoning_content field)
                        accumulatedReasoning += reasoningChunk
                        
                        print("🧠 Reasoning chunk received (\(reasoningChunk.count) chars), total reasoning: \(accumulatedReasoning.count) chars")
                        
                        let currentResponse = accumulatedResponse
                        let currentReasoning = accumulatedReasoning
                        
                        Task { @MainActor in
                            // Update the message with current content and reasoning
                            if messageIndex < self.currentConversation.messages.count {
                                self.currentConversation.messages[messageIndex] = Message(
                                    content: currentResponse,
                                    isUser: false,
                                    timestamp: self.currentConversation.messages[messageIndex].timestamp,
                                    thinkingContent: currentReasoning
                                )
                            }
                        }
                    }
                )
                
                // After streaming is complete, finalize the message
                print("✅ Streaming complete!")
                print("📄 Total content: \(accumulatedResponse.count) chars")
                print("💭 Total reasoning: \(accumulatedReasoning.count) chars")
                
                // For Qwen models, parse thinking tokens from content
                // For GPT-oss models, reasoning content is already separated
                let finalParsed: (thinking: String?, content: String)
                if self.shouldParseThinkingTokens() && accumulatedReasoning.isEmpty {
                    // Qwen models: parse <think> tags from content
                    finalParsed = self.parseThinkingTokens(from: accumulatedResponse)
                    print("🔍 Parsed Qwen thinking tokens: \(finalParsed.thinking?.count ?? 0) chars")
                } else if !accumulatedReasoning.isEmpty {
                    // GPT-oss models: use the separate reasoning_content field
                    finalParsed = (thinking: accumulatedReasoning, content: accumulatedResponse)
                    print("🔍 Using GPT-oss reasoning_content: \(accumulatedReasoning.count) chars")
                } else {
                    // No thinking content
                    finalParsed = (thinking: nil, content: accumulatedResponse)
                }
                
                if messageIndex < self.currentConversation.messages.count {
                    self.currentConversation.messages[messageIndex] = Message(
                        content: finalParsed.content,
                        isUser: false,
                        timestamp: self.currentConversation.messages[messageIndex].timestamp,
                        thinkingContent: finalParsed.thinking
                    )
                }
                
                self.isLoading = false
                self.currentTask = nil
                self.saveConversationHistory()
            } catch is CancellationError {
                // Task was cancelled - this is expected
                print("⏹️ Generation was stopped by user")
                self.isLoading = false
                self.currentTask = nil
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
                self.currentTask = nil
                self.saveConversationHistory()
            } catch {
                // Check if it's a cancellation error (in case it wasn't caught above)
                if Task.isCancelled {
                    print("⏹️ Generation was stopped by user (caught in generic handler)")
                    self.isLoading = false
                    self.currentTask = nil
                    self.saveConversationHistory()
                    return
                }
                
                // Replace the placeholder with an error message
                if messageIndex < self.currentConversation.messages.count {
                    self.currentConversation.messages[messageIndex] = Message(
                        content: "❌ Unexpected error: \(error.localizedDescription)\n\nPlease try again.",
                        isUser: false,
                        timestamp: self.currentConversation.messages[messageIndex].timestamp
                    )
                }
                self.isLoading = false
                self.currentTask = nil
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

