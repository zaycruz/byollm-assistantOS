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
    @State private var safetyLevel: SafetyLevel = .medium
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool
    
    enum SafetyLevel: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        var displayName: String {
            rawValue.capitalized
        }
    }
    
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
                    .onTapGesture {
                        // Dismiss keyboard when tapping outside
                        isInputFocused = false
                    }
                    
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
                    MessagesListView(messages: conversationManager.currentConversation.messages, fontStyle: selectedFontStyle, isLoading: conversationManager.isLoading, isInputFocused: $isInputFocused)
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
                .padding(.bottom, keyboardHeight > 0 ? 8 : 40)
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
                        safetyLevel: $safetyLevel,
                        currentView: $sidePanelView,
                        isPresented: $showSidePanel
                    )
                    .frame(width: sidePanelView == .settings ? geometry.size.width : geometry.size.width * 0.85)
                    .transition(.move(edge: .leading))
                }
            }
            .animation(.easeOut(duration: 0.3), value: showSidePanel)
            .animation(.easeInOut(duration: 0.3), value: sidePanelView)
            .overlay(
                // Invisible edge swipe area
                HStack {
                    // Left edge for opening sidebar
                    Color.clear
                        .frame(width: 30)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    if value.translation.width > 50 && !showSidePanel {
                                        withAnimation {
                                            sidePanelView = .chatHistory
                                            showSidePanel = true
                                        }
                                    }
                                }
                        )
                    
                    Spacer()
                        .allowsHitTesting(false) // Allow taps to pass through
                }
                .allowsHitTesting(!showSidePanel) // Only intercept when sidebar is closed
            )
            .simultaneousGesture(
                // Global gesture for closing sidebar
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        // Swipe from right to left to close side panel
                        if value.translation.width < -100 && showSidePanel {
                            withAnimation {
                                showSidePanel = false
                            }
                        }
                    }
            )
        }
        .onAppear {
            // Load saved server address
            if let savedAddress = UserDefaults.standard.string(forKey: "serverAddress") {
                serverAddress = savedAddress
                conversationManager.serverAddress = savedAddress
            }
            
            // Load saved safety level
            if let savedLevel = UserDefaults.standard.string(forKey: "safetyLevel"),
               let level = SafetyLevel(rawValue: savedLevel) {
                safetyLevel = level
                conversationManager.safetyLevel = level.rawValue
            }
            
            if showKeyboardOnLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isInputFocused = true
                }
            }
            loadModelsFromServer()
            
            // Setup keyboard notifications
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    keyboardHeight = 0
                }
            }
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
        .onChange(of: safetyLevel) { oldValue, newValue in
            conversationManager.safetyLevel = newValue.rawValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "safetyLevel")
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
    let isLoading: Bool
    @FocusState.Binding var isInputFocused: Bool
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 20) {
                    ForEach(messages) { message in
                        MessageBubble(message: message, fontStyle: fontStyle)
                            .id(message.id)
                    }
                    
                    // Show typing indicator when loading and last message is not empty
                    if isLoading && (messages.last?.content.isEmpty ?? true) {
                        TypingIndicator()
                            .id("typing-indicator")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Dismiss keyboard when tapping on messages
                    isInputFocused = false
                }
                .onChange(of: messages.count) { oldValue, newValue in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isLoading) { oldValue, newValue in
                    if newValue {
                        withAnimation {
                            proxy.scrollTo("typing-indicator", anchor: .bottom)
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
        if message.isUser {
            // User message: compact bubble on the right
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text(message.content)
                        .font(fontStyle.apply(size: 17, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.2))
                .cornerRadius(20)
                .frame(maxWidth: 280, alignment: .trailing)
            }
        } else {
            // AI message: full width, no bubble
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(parseMessageContent(message.content).enumerated()), id: \.offset) { index, block in
                    switch block {
                    case .text(let attributedContent):
                        Text(attributedContent)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    
                    case .code(let code, let language):
                        VStack(alignment: .leading, spacing: 4) {
                            if let lang = language, !lang.isEmpty {
                                Text(lang)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.top, 8)
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(code)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(12)
                            }
                        }
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    
                    case .toolResult(let result):
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.caption)
                                Text("Tool Result")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white.opacity(0.7))
                            
                            Text(result)
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(8)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 8)
        }
    }
    
    enum ContentBlock {
        case text(AttributedString)
        case code(String, language: String?)
        case toolResult(String)
    }
    
    private func parseMessageContent(_ content: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        var currentText = ""
        
        let lines = content.components(separatedBy: .newlines)
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // Check for code block start
            if line.hasPrefix("```") {
                // Save any accumulated text
                if !currentText.isEmpty {
                    blocks.append(.text(parseMarkdown(currentText.trimmingCharacters(in: .whitespacesAndNewlines))))
                    currentText = ""
                }
                
                // Extract language if specified
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                
                // Collect code lines until closing ```
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                
                let code = codeLines.joined(separator: "\n")
                blocks.append(.code(code, language: language.isEmpty ? nil : language))
                i += 1
                continue
            }
            
            // Check for tool result patterns (customize this based on your LLM's output format)
            if line.contains("Tool:") || line.contains("Result:") || line.hasPrefix("[") && line.contains("]") {
                // Save any accumulated text
                if !currentText.isEmpty {
                    blocks.append(.text(parseMarkdown(currentText.trimmingCharacters(in: .whitespacesAndNewlines))))
                    currentText = ""
                }
                
                var toolResultLines: [String] = [line]
                i += 1
                
                // Collect subsequent lines that look like tool output
                while i < lines.count && (lines[i].isEmpty || lines[i].hasPrefix(" ") || lines[i].hasPrefix("\t") || lines[i].contains(":")) {
                    toolResultLines.append(lines[i])
                    i += 1
                    
                    // Break if we hit a code block or regular text
                    if i < lines.count && (lines[i].hasPrefix("```") || (!lines[i].isEmpty && !lines[i].hasPrefix(" ") && !lines[i].contains(":"))) {
                        break
                    }
                }
                
                blocks.append(.toolResult(toolResultLines.joined(separator: "\n")))
                continue
            }
            
            // Regular text line
            currentText += line + "\n"
            i += 1
        }
        
        // Add any remaining text
        if !currentText.isEmpty {
            blocks.append(.text(parseMarkdown(currentText.trimmingCharacters(in: .whitespacesAndNewlines))))
        }
        
        return blocks
    }
    
    private func parseMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: .newlines)
        
        for (lineIndex, line) in lines.enumerated() {
            var lineText = line
            var isBold = false
            var currentString = ""
            var attributedLine = AttributedString()
            
            // Check if line starts with markdown header
            if lineText.hasPrefix("# ") {
                lineText = String(lineText.dropFirst(2))
                var headerAttr = AttributedString(lineText)
                headerAttr.font = fontStyle.apply(size: 24, weight: .bold)
                headerAttr.foregroundColor = .white
                attributedLine.append(headerAttr)
            } else if lineText.hasPrefix("## ") {
                lineText = String(lineText.dropFirst(3))
                var headerAttr = AttributedString(lineText)
                headerAttr.font = fontStyle.apply(size: 20, weight: .bold)
                headerAttr.foregroundColor = .white
                attributedLine.append(headerAttr)
            } else if lineText.hasPrefix("### ") {
                lineText = String(lineText.dropFirst(4))
                var headerAttr = AttributedString(lineText)
                headerAttr.font = fontStyle.apply(size: 18, weight: .bold)
                headerAttr.foregroundColor = .white
                attributedLine.append(headerAttr)
            } else if lineText.hasPrefix("- ") || lineText.hasPrefix("* ") {
                // Bullet point - parse inline formatting
                attributedLine = parseInlineFormatting(lineText)
            } else {
                // Regular text - parse inline formatting
                attributedLine = parseInlineFormatting(lineText)
            }
            
            result.append(attributedLine)
            
            // Add newline between lines (except for the last one)
            if lineIndex < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        
        return result
    }
    
    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString()
        var currentText = ""
        var i = text.startIndex
        
        while i < text.endIndex {
            let char = text[i]
            
            // Check for bold markers (**)
            if char == "*" && text.index(after: i) < text.endIndex && text[text.index(after: i)] == "*" {
                // Found **, save current text if any
                if !currentText.isEmpty {
                    var normalAttr = AttributedString(currentText)
                    normalAttr.font = fontStyle.apply(size: 17, weight: .regular)
                    normalAttr.foregroundColor = .white
                    result.append(normalAttr)
                    currentText = ""
                }
                
                // Skip the two asterisks
                i = text.index(i, offsetBy: 2)
                
                // Find the closing **
                var boldText = ""
                while i < text.endIndex {
                    if text[i] == "*" && text.index(after: i) < text.endIndex && text[text.index(after: i)] == "*" {
                        // Found closing **
                        var boldAttr = AttributedString(boldText)
                        boldAttr.font = fontStyle.apply(size: 17, weight: .bold)
                        boldAttr.foregroundColor = .white
                        result.append(boldAttr)
                        
                        // Skip closing **
                        i = text.index(i, offsetBy: 2)
                        break
                    } else {
                        boldText.append(text[i])
                        i = text.index(after: i)
                    }
                }
            } else {
                currentText.append(char)
                i = text.index(after: i)
            }
        }
        
        // Add any remaining text
        if !currentText.isEmpty {
            var normalAttr = AttributedString(currentText)
            normalAttr.font = fontStyle.apply(size: 17, weight: .regular)
            normalAttr.foregroundColor = .white
            result.append(normalAttr)
        }
        
        return result
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
    @Binding var safetyLevel: ChatView.SafetyLevel
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
                    safetyLevel: $safetyLevel,
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
                                ConversationHistoryRow(
                                    conversation: conversation,
                                    conversationManager: conversationManager,
                                    isPresented: $isPresented
                                )
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
    @ObservedObject var conversationManager: ConversationManager
    @Binding var isPresented: Bool
    
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
        Button(action: {
            conversationManager.loadConversation(conversation)
            isPresented = false
        }) {
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
        .buttonStyle(PlainButtonStyle())
    }
}

struct TypingIndicator: View {
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationAmount == Double(index) ? 1.3 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: animationAmount
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
            .frame(maxWidth: 280, alignment: .leading)
            
            Spacer()
        }
        .onAppear {
            animationAmount = 1.0
        }
    }
}

#Preview {
    ChatView()
}

