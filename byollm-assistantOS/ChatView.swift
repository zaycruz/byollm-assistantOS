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
    @State private var showSettings = false
    @State private var showKeyboardOnLaunch = true
    @State private var serverAddress = ""
    @State private var systemPrompt = ""
    @State private var selectedTheme: AppTheme = .ocean
    @State private var selectedFontStyle: FontStyle = .system
    @State private var selectedModel = "SmolLM 3 3B"
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
                HStack(spacing: 12) {
                    // Settings Button
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    
                    // New Chat Button
                    Button(action: { conversationManager.newConversation() }) {
                        Image(systemName: "message")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Model Selector
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Text(selectedModel)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(25)
                    }
                    
                    Spacer()
                    
                    // New Chat Icon Button (right side)
                    Button(action: { conversationManager.newConversation() }) {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                // Messages or Welcome Screen
                if conversationManager.currentConversation.messages.isEmpty {
                    WelcomeView(fontStyle: selectedFontStyle)
                } else {
                    MessagesListView(messages: conversationManager.currentConversation.messages, fontStyle: selectedFontStyle)
                }
                
                // Input Area
                VStack(spacing: 12) {
                    // Suggestion Chips (only when no messages)
                    if conversationManager.currentConversation.messages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                SuggestionChip(title: "Plan", subtitle: "a trip to Paris")
                                SuggestionChip(title: "Tell me", subtitle: "something fascinating")
                                SuggestionChip(title: "Begin", subtitle: "meditation")
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
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
                        
                        Button(action: {}) {
                            Image(systemName: "lightbulb")
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
                            
                            if !inputText.isEmpty {
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
        .sheet(isPresented: $showSettings) {
            SettingsView(
                conversationManager: conversationManager,
                showKeyboardOnLaunch: $showKeyboardOnLaunch,
                serverAddress: $serverAddress,
                systemPrompt: $systemPrompt,
                selectedTheme: $selectedTheme,
                selectedFontStyle: $selectedFontStyle
            )
        }
        .onAppear {
            if showKeyboardOnLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isInputFocused = true
                }
            }
        }
        .onChange(of: serverAddress) { newValue in
            conversationManager.serverAddress = newValue
        }
        .onChange(of: systemPrompt) { newValue in
            conversationManager.systemPrompt = newValue
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        conversationManager.sendMessage(inputText)
        inputText = ""
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
                .onChange(of: messages.count) { _ in
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
            
            Text(message.content)
                .font(fontStyle.apply(size: 17, weight: .regular))
                .foregroundColor(.white)
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
}

struct SuggestionChip: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
    }
}

#Preview {
    ChatView()
}

