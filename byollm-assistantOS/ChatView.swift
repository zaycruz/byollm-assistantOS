//
//  ChatView.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var conversationManager = ConversationManager()
    @State private var inputText = ""
    @State private var showSidePanel = false
    @State private var showSettings = false
    @State private var sidePanelView: SidePanelContentView = .chatHistory
    @State private var showKeyboardOnLaunch = true
    @State private var serverAddress = ""
    @State private var systemPrompt = ""
    @State private var selectedTheme: AppTheme = .ocean
    @State private var selectedFontStyle: FontStyle = .system
    @State private var selectedModel = "qwen2.5:latest"
    @State private var availableModels: [String] = ["qwen2.5:latest"]
    @FocusState private var isInputFocused: Bool
    
    enum AppTheme {
        case ocean, sunset, forest, midnight, lavender, crimson, coral, arctic
        
        var colors: [Color] {
            switch self {
            case .ocean:
                return [Color(red: 0.2, green: 0.4, blue: 0.35), Color(red: 0.15, green: 0.45, blue: 0.5)]
            case .sunset:
                return [Color(red: 0.95, green: 0.4, blue: 0.3), Color(red: 0.95, green: 0.65, blue: 0.3)]
            case .forest:
                return [Color(red: 0.15, green: 0.35, blue: 0.2), Color(red: 0.25, green: 0.45, blue: 0.25)]
            case .midnight:
                return [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.3)]
            case .lavender:
                return [Color(red: 0.4, green: 0.3, blue: 0.5), Color(red: 0.5, green: 0.4, blue: 0.6)]
            case .crimson:
                return [Color(red: 0.5, green: 0.15, blue: 0.2), Color(red: 0.6, green: 0.2, blue: 0.3)]
            case .coral:
                return [Color(red: 0.95, green: 0.5, blue: 0.45), Color(red: 0.95, green: 0.7, blue: 0.5)]
            case .arctic:
                return [Color(red: 0.7, green: 0.85, blue: 0.9), Color(red: 0.8, green: 0.9, blue: 0.95)]
            }
        }
    }
    
    enum FontStyle {
        case system, rounded, serif, monospaced
        
        func apply(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            switch self {
            case .system:
                return .system(size: size, weight: weight)
            case .rounded:
                return .system(size: size, weight: weight, design: .rounded)
            case .serif:
                return .system(size: size, weight: weight, design: .serif)
            case .monospaced:
                return .system(size: size, weight: weight, design: .monospaced)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Main Content
                ZStack {
                    // Gradient Background (Dynamic Theme)
                    LinearGradient(
                        colors: selectedTheme.colors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                // Top Bar
                ZStack {
                    HStack {
                        // Side Panel Button (Chat History) - Left
                        Button(action: { 
                            sidePanelView = .chatHistory
                            showSidePanel = true
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // New Chat Icon Button - Right
                        Button(action: { conversationManager.newConversation() }) {
                            Image(systemName: "square.and.pencil")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    
                    // Model Selector - Centered (aligned with Dynamic Island)
                    Menu {
                        ForEach(availableModels, id: \.self) { model in
                            Button(action: {
                                selectedModel = model
                            }) {
                                HStack {
                                    Text(formatModelName(model))
                                    if selectedModel == model {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(formatModelName(selectedModel))
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
                
                // Messages or Welcome Screen
                if conversationManager.currentConversation.messages.isEmpty {
                    WelcomeView(fontStyle: selectedFontStyle)
                } else {
                    MessagesListView(messages: conversationManager.currentConversation.messages, fontStyle: selectedFontStyle)
                }
                
                // Input Area
                VStack(spacing: 12) {
                    // Input Field
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        
                        HStack {
                            TextField("Ask anything", text: $inputText)
                                .foregroundColor(.white)
                                .focused($isInputFocused)
                                .submitLabel(.send)
                                .onSubmit {
                                    sendMessage()
                                }
                                .disabled(conversationManager.isLoading)
                            
                            if conversationManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else if !inputText.isEmpty {
                                Button(action: { sendMessage() }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(25)
                        
                        Button(action: {}) {
                            Image(systemName: "waveform")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
                    }
                }
                
                // Dimmed background overlay
                if showSidePanel {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showSidePanel = false
                        }
                }
                
                // Side panel
                if showSidePanel {
                    SidePanelContainerView(
                        conversationManager: conversationManager,
                        showKeyboardOnLaunch: $showKeyboardOnLaunch,
                        serverAddress: $serverAddress,
                        systemPrompt: $systemPrompt,
                        selectedTheme: $selectedTheme,
                        selectedFontStyle: $selectedFontStyle,
                        currentView: $sidePanelView,
                        isPresented: $showSidePanel
                    )
                    .frame(width: sidePanelView == .settings ? geometry.size.width : geometry.size.width * 0.85)
                    .transition(.move(edge: .leading))
                }
            }
            .animation(.easeOut(duration: 0.3), value: showSidePanel)
            .animation(.easeInOut(duration: 0.3), value: sidePanelView)
        }
        .onAppear {
            // Load saved server address
            if let savedAddress = UserDefaults.standard.string(forKey: "serverAddress") {
                serverAddress = savedAddress
                conversationManager.serverAddress = savedAddress
            }
            
            if showKeyboardOnLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isInputFocused = true
                }
            }
            loadModelsFromServer()
        }
        .onChange(of: serverAddress) { oldValue, newValue in
            conversationManager.serverAddress = newValue
            // Save to UserDefaults
            UserDefaults.standard.set(newValue, forKey: "serverAddress")
            loadModelsFromServer()
        }
        .onChange(of: systemPrompt) { oldValue, newValue in
            conversationManager.systemPrompt = newValue
        }
        .onChange(of: selectedModel) { oldValue, newValue in
            conversationManager.selectedModel = newValue
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        conversationManager.sendMessage(inputText)
        inputText = ""
    }
    
    private func formatModelName(_ modelName: String) -> String {
        // Remove ":latest" suffix and simplify model name
        let name = modelName.replacingOccurrences(of: ":latest", with: "")
        return name
    }
    
    private func loadModelsFromServer() {
        guard !serverAddress.isEmpty else { return }
        
        Task {
            do {
                let models = try await NetworkManager.shared.getModels(from: serverAddress)
                
                await MainActor.run {
                    if !models.isEmpty {
                        self.availableModels = models
                        // If the current selected model is not in the list, select the first one
                        if !models.contains(selectedModel) {
                            self.selectedModel = models.first ?? "qwen2.5:latest"
                        }
                    }
                }
            } catch {
                // Silently fail - keep default models
                print("Failed to load models from server: \(error.localizedDescription)")
            }
        }
    }
}

struct WelcomeView: View {
    let fontStyle: ChatView.FontStyle
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Meet AssistantOS")
                    .font(fontStyle.apply(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("BYOLLM - Bring Your Own LLM. Host your own large language models and interact with them seamlessly from your mobile device. Take control of your AI assistant with complete privacy and flexibility.")
                    .font(fontStyle.apply(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

struct MessagesListView: View {
    let messages: [Message]
    let fontStyle: ChatView.FontStyle
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 20) {
                    ForEach(messages) { message in
                        MessageBubble(message: message, fontStyle: fontStyle)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .onChange(of: messages.count) { oldValue, newValue in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let fontStyle: ChatView.FontStyle
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 0) {
                Text(formattedContent)
                    .font(fontStyle.apply(size: 17, weight: .regular))
                    .foregroundColor(.white)
                    .multilineTextAlignment(message.isUser ? .trailing : .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                message.isUser
                    ? Color.white.opacity(0.2)
                    : Color.white.opacity(0.1)
            )
            .cornerRadius(20)
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private var formattedContent: AttributedString {
        do {
            // Try to parse as full markdown (including headers, lists, code blocks)
            var attributed = try AttributedString(markdown: message.content)
            
            // Apply white color to all text
            for run in attributed.runs {
                let range = run.range
                attributed[range].foregroundColor = .white
            }
            
            return attributed
        } catch {
            // If markdown parsing fails, return plain text
            var attributed = AttributedString(message.content)
            attributed.foregroundColor = .white
            return attributed
        }
    }
}

enum SidePanelContentView {
    case chatHistory
    case settings
}

struct SidePanelContainerView: View {
    @ObservedObject var conversationManager: ConversationManager
    @Binding var showKeyboardOnLaunch: Bool
    @Binding var serverAddress: String
    @Binding var systemPrompt: String
    @Binding var selectedTheme: ChatView.AppTheme
    @Binding var selectedFontStyle: ChatView.FontStyle
    @Binding var currentView: SidePanelContentView
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            if currentView == .chatHistory {
                ChatHistoryView(
                    conversationManager: conversationManager,
                    currentView: $currentView,
                    isPresented: $isPresented
                )
                .transition(.move(edge: .leading))
            } else {
                SettingsView(
                    conversationManager: conversationManager,
                    showKeyboardOnLaunch: $showKeyboardOnLaunch,
                    serverAddress: $serverAddress,
                    systemPrompt: $systemPrompt,
                    selectedTheme: $selectedTheme,
                    selectedFontStyle: $selectedFontStyle,
                    isInSidePanel: true,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .chatHistory
                        }
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentView)
    }
}

struct ChatHistoryView: View {
    @ObservedObject var conversationManager: ConversationManager
    @Binding var currentView: SidePanelContentView
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Chat History")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { 
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                // Chat History List
                if conversationManager.conversationHistory.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No chat history")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.5))
                        Text("Start a conversation to see it here")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(conversationManager.conversationHistory) { conversation in
                                ConversationHistoryRow(conversation: conversation)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Settings Button at Bottom
                Button(action: {
                    currentView = .settings
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 30)
                        
                        Text("Settings")
                            .font(.body)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.05))
                }
            }
        }
    }
}

struct ConversationHistoryRow: View {
    let conversation: Conversation
    
    private var previewText: String {
        if let firstMessage = conversation.messages.first {
            return firstMessage.content
        }
        return "Empty conversation"
    }
    
    private var messageCount: Int {
        return conversation.messages.count
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: conversation.createdAt, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.caption2)
                    Text("\(messageCount)")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.5))
            }
            
            Text(previewText)
                .font(.body)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    ChatView()
}

