//
//  Models.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import Foundation
import SwiftData

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
    var provider: String = "local"  // "local" (Ollama/vLLM) or "cloud" (Anthropic)
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
                content: "Server not configured. Please set your server address in Settings to start chatting.\n\nAll chat requests are sent to your server; the app does not run models locally.",
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
                
                print("Sending \(apiMessages.count) messages to API")
                print("Using model: \(selectedModel)")
                print("Provider: \(provider)")
                print("Safety level: \(safetyLevel)")
                
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
                
                let composedPrompt = self.composedSystemPrompt()
                
                // Send to server with streaming
                try await NetworkManager.shared.sendChatMessageStreaming(
                    to: serverAddress,
                    model: selectedModel,
                    messages: Array(apiMessages),
                    systemPrompt: composedPrompt,
                    provider: provider,
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
    
    // MARK: - Prompt composition (profile appended)
    
    private func composedSystemPrompt() -> String? {
        let base = systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let profile = profilePrompt()
        
        var parts: [String] = []
        if !base.isEmpty { parts.append(base) }
        if let profile, !profile.isEmpty { parts.append(profile) }
        
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }
    
    private func profilePrompt() -> String? {
        let name = (UserDefaults.standard.string(forKey: "userProfile.name") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let occupation = (UserDefaults.standard.string(forKey: "userProfile.occupation") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let about = (UserDefaults.standard.string(forKey: "userProfile.about") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        var lines: [String] = []
        if !name.isEmpty { lines.append("Name: \(name)") }
        if !occupation.isEmpty { lines.append("Occupation: \(occupation)") }
        if !about.isEmpty { lines.append("About: \(about)") }
        
        guard !lines.isEmpty else { return nil }
        return "User Profile\n" + lines.joined(separator: "\n")
    }
}

// MARK: - Level Up (SwiftData models)

enum LevelUpGoalStatus: String, Codable, CaseIterable {
    case active
    case completed
    case archived
}

enum LevelUpObjectiveStatus: String, Codable, CaseIterable {
    case locked
    case available
    case inProgress
    case completed
    case skipped
}

extension LevelUpGoalStatus {
    static func fromAPI(_ raw: String) -> LevelUpGoalStatus {
        switch raw.lowercased() {
        case "active": return .active
        case "completed": return .completed
        case "archived": return .archived
        default: return .active
        }
    }
}

extension LevelUpObjectiveStatus {
    static func fromAPI(_ raw: String) -> LevelUpObjectiveStatus {
        let normalized = raw.lowercased()
        switch normalized {
        case "locked": return .locked
        case "available", "unlocked": return .available
        case "in_progress", "inprogress", "running", "started": return .inProgress
        case "completed", "done": return .completed
        case "skipped": return .skipped
        default: return .locked
        }
    }
}

@Model
final class LevelUpGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var goalDescription: String?
    var createdAt: Date
    var targetDate: Date?
    var status: LevelUpGoalStatus
    
    // Server tracking
    var serverID: String?
    var lastSyncedAt: Date?
    
    // Client-side pinning (max 3 pinned goals)
    var isPinned: Bool = false
    var pinnedAt: Date?
    
    // Relationships - use simple relationships without inverse to avoid circular reference
    @Relationship(deleteRule: .cascade) var objectives: [LevelUpObjective] = []
    @Relationship(deleteRule: .cascade) var contexts: [LevelUpContext] = []
    
    init(
        id: UUID = UUID(),
        title: String,
        goalDescription: String? = nil,
        createdAt: Date = Date(),
        targetDate: Date? = nil,
        status: LevelUpGoalStatus = .active,
        serverID: String? = nil,
        lastSyncedAt: Date? = nil,
        isPinned: Bool = false,
        pinnedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.goalDescription = goalDescription
        self.createdAt = createdAt
        self.targetDate = targetDate
        self.status = status
        self.serverID = serverID
        self.lastSyncedAt = lastSyncedAt
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
    }
    
    var totalObjectives: Int { objectives.count }
    
    var completedObjectives: Int {
        objectives.filter { $0.status == .completed }.count
    }
    
    var progressPercentage: Double {
        guard totalObjectives > 0 else { return 0 }
        return Double(completedObjectives) / Double(totalObjectives)
    }
}

// MARK: - Goal Pinning Helpers

enum LevelUpGoalPinning {
    static let maxPinnedGoals = 3
    
    /// Pins a goal and enforces the max-3 limit by unpinning the oldest if needed.
    /// Returns the goal that was unpinned (if any) so the caller can show feedback.
    @discardableResult
    static func pin(_ goal: LevelUpGoal, allGoals: [LevelUpGoal]) -> LevelUpGoal? {
        guard !goal.isPinned else { return nil }
        
        let currentlyPinned = allGoals.filter { $0.isPinned }.sorted {
            ($0.pinnedAt ?? .distantPast) < ($1.pinnedAt ?? .distantPast)
        }
        
        var unpinnedGoal: LevelUpGoal?
        
        // If already at max, unpin the oldest
        if currentlyPinned.count >= maxPinnedGoals, let oldest = currentlyPinned.first {
            oldest.isPinned = false
            oldest.pinnedAt = nil
            unpinnedGoal = oldest
        }
        
        goal.isPinned = true
        goal.pinnedAt = Date()
        
        return unpinnedGoal
    }
    
    /// Unpins a goal.
    static func unpin(_ goal: LevelUpGoal) {
        goal.isPinned = false
        goal.pinnedAt = nil
    }
    
    /// Returns pinned goals sorted by pinnedAt (most recent first for display).
    static func pinnedGoals(from goals: [LevelUpGoal]) -> [LevelUpGoal] {
        goals.filter { $0.isPinned }.sorted {
            ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast)
        }
    }
    
    /// Auto-pins the most recently created goal if no goals are pinned.
    /// Returns true if a goal was auto-pinned.
    @discardableResult
    static func autoPinIfNeeded(activeGoals: [LevelUpGoal]) -> Bool {
        let pinned = activeGoals.filter { $0.isPinned }
        guard pinned.isEmpty, let mostRecent = activeGoals.max(by: { $0.createdAt < $1.createdAt }) else {
            return false
        }
        mostRecent.isPinned = true
        mostRecent.pinnedAt = Date()
        return true
    }
}

@Model
final class LevelUpObjective {
    @Attribute(.unique) var id: UUID
    var serverID: String?
    
    // Core properties
    var title: String
    var objectiveDescription: String
    var estimatedHours: Double
    var pointsValue: Int
    var tier: String // "Foundation", "Core", "Advanced"
    var position: Int
    
    // State
    var status: LevelUpObjectiveStatus
    var availableAt: Date?
    var completedAt: Date?
    var completionNotes: String?
    
    // Metadata
    var purpose: String
    var unlocks: String
    var createdAt: Date
    
    // Relationships - simplified to avoid circular references
    var goal: LevelUpGoal?
    @Relationship var dependencies: [LevelUpObjective] = []
    @Relationship var dependents: [LevelUpObjective] = []
    @Relationship var contextSources: [LevelUpContext] = []
    
    init(
        id: UUID = UUID(),
        serverID: String? = nil,
        title: String,
        objectiveDescription: String,
        estimatedHours: Double,
        pointsValue: Int,
        tier: String,
        position: Int,
        status: LevelUpObjectiveStatus = .locked,
        availableAt: Date? = nil,
        completedAt: Date? = nil,
        completionNotes: String? = nil,
        purpose: String = "",
        unlocks: String = "",
        createdAt: Date = Date(),
        goal: LevelUpGoal? = nil
    ) {
        self.id = id
        self.serverID = serverID
        self.title = title
        self.objectiveDescription = objectiveDescription
        self.estimatedHours = estimatedHours
        self.pointsValue = pointsValue
        self.tier = tier
        self.position = position
        self.status = status
        self.availableAt = availableAt
        self.completedAt = completedAt
        self.completionNotes = completionNotes
        self.purpose = purpose
        self.unlocks = unlocks
        self.createdAt = createdAt
        self.goal = goal
    }
    
    var isAvailable: Bool {
        status == .available || status == .inProgress
    }
    
    var isLocked: Bool { status == .locked }
    
    var formattedEstimate: String {
        let hours = Int(estimatedHours)
        let minutes = Int((estimatedHours - Double(hours)) * 60)
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

@Model
final class LevelUpContext {
    @Attribute(.unique) var id: UUID
    var serverID: String?
    
    var content: String
    var source: String?
    var createdAt: Date
    
    // Relationships - simplified
    var goal: LevelUpGoal?
    @Relationship var influencedObjectives: [LevelUpObjective] = []
    
    init(
        id: UUID = UUID(),
        serverID: String? = nil,
        content: String,
        source: String? = nil,
        createdAt: Date = Date(),
        goal: LevelUpGoal? = nil
    ) {
        self.id = id
        self.serverID = serverID
        self.content = content
        self.source = source
        self.createdAt = createdAt
        self.goal = goal
    }
    
    var characterCount: Int { content.count }
}

@Model
final class LevelUpUserProgress {
    @Attribute(.unique) var id: UUID
    
    // Progression
    var currentLevel: Int
    var totalPoints: Int
    var pointsToNextLevel: Int
    
    // Streaks
    var currentStreak: Int
    var longestStreak: Int
    var lastActivityDate: Date?
    var freezeDaysAvailable: Int
    
    // Settings
    var dailyReminderEnabled: Bool
    var dailyReminderTime: Date
    var notificationsEnabled: Bool
    
    init(
        id: UUID = UUID(),
        currentLevel: Int = 1,
        totalPoints: Int = 0,
        pointsToNextLevel: Int = 100,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastActivityDate: Date? = nil,
        freezeDaysAvailable: Int = 0,
        dailyReminderEnabled: Bool = false,
        dailyReminderTime: Date = Date(),
        notificationsEnabled: Bool = false
    ) {
        self.id = id
        self.currentLevel = currentLevel
        self.totalPoints = totalPoints
        self.pointsToNextLevel = pointsToNextLevel
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActivityDate = lastActivityDate
        self.freezeDaysAvailable = freezeDaysAvailable
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderTime = dailyReminderTime
        self.notificationsEnabled = notificationsEnabled
    }
    
    var levelProgress: Double {
        let currentStart = LevelUpProgression.pointsForLevel(currentLevel)
        let nextStart = LevelUpProgression.pointsForLevel(currentLevel + 1)
        let range = Double(nextStart - currentStart)
        let earned = Double(totalPoints - currentStart)
        return min(max(earned / range, 0), 1)
    }
}

struct LevelUpPathUpdate: Codable {
    var timestamp: Date
    var addedObjectiveIDs: [UUID]
    var modifiedObjectiveIDs: [UUID]
    var removedObjectiveIDs: [UUID]
    var reason: String
}

// MARK: - Deterministic progression helpers (testable)

enum LevelUpProgression {
    static func pointsForLevel(_ level: Int) -> Int {
        max(1, level) * max(1, level) * 100
    }
    
    static func level(forTotalPoints points: Int) -> Int {
        max(1, Int(sqrt(Double(max(points, 0)) / 100.0)))
    }
    
    static func pointsToNextLevel(level: Int, totalPoints: Int) -> Int {
        let nextStart = pointsForLevel(level + 1)
        return max(0, nextStart - totalPoints)
    }
    
    static func updateStreak(
        currentStreak: Int,
        longestStreak: Int,
        lastActivityDate: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> (current: Int, longest: Int, lastActivityDate: Date) {
        let today = calendar.startOfDay(for: now)
        let last = lastActivityDate.map { calendar.startOfDay(for: $0) }
        
        var updatedStreak = currentStreak
        var updatedLongest = longestStreak
        
        if let last {
            let daysSince = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            if daysSince == 0 {
                // no change
            } else if daysSince == 1 {
                updatedStreak = max(1, updatedStreak + 1)
                updatedLongest = max(updatedLongest, updatedStreak)
            } else {
                updatedStreak = 1
                updatedLongest = max(updatedLongest, updatedStreak)
            }
        } else {
            updatedStreak = 1
            updatedLongest = max(updatedLongest, updatedStreak)
        }
        
        return (updatedStreak, updatedLongest, now)
    }
}

