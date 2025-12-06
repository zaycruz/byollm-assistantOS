//
//  ChatView.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ChatView: View {
    @StateObject private var conversationManager = ConversationManager()
    @State private var inputText = ""
    @State private var showSidePanel = false
    @State private var showSettings = false
    @State private var sidePanelView: SidePanelContentView = .navigation
    @State private var showKeyboardOnLaunch = true
    @State private var serverAddress = ""
    @State private var systemPrompt = ""
    @State private var selectedTheme: AppTheme = .ocean
    @State private var selectedFontStyle: FontStyle = .system
    @State private var selectedModel = "gpt-oss:latest"
    @State private var availableModels: [String] = ["gpt-oss:latest"]
    @State private var safetyLevel: SafetyLevel = .medium
    @State private var reasoningEffort: ReasoningEffort = .medium
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool
    
    @State private var showPhotosPicker = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var selectedPhotosItems: [PhotosPickerItem] = []
    @State private var attachedImages: [UIImage] = []
    @State private var attachedFileURLs: [URL] = []
    
    enum SafetyLevel: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        var displayName: String {
            rawValue.capitalized
        }
    }
    
    enum ReasoningEffort: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        var displayName: String {
            rawValue.capitalized
        }
    }
    
    enum AppTheme: String, CaseIterable {
        case ocean, sunset, forest, midnight, lavender, crimson, coral, arctic, cyberpunk, smokeGrey
        
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
            case .cyberpunk:
                return [
                    Color(red: 0.02, green: 0.02, blue: 0.08),      // Deep void black
                    Color(red: 0.12, green: 0.0, blue: 0.18),       // Dark purple undertone
                    Color(red: 0.45, green: 0.0, blue: 0.35),       // Neon magenta glow
                    Color(red: 0.0, green: 0.65, blue: 0.75)        // Electric cyan accent
                ]
            case .smokeGrey:
                return [
                    Color(red: 0.12, green: 0.12, blue: 0.14),      // Charcoal black
                    Color(red: 0.22, green: 0.22, blue: 0.25),      // Deep smoke
                    Color(red: 0.32, green: 0.32, blue: 0.36)       // Silver smoke
                ]
            }
        }
        
        var displayName: String {
            switch self {
            case .ocean: return "Ocean"
            case .sunset: return "Sunset"
            case .forest: return "Forest"
            case .midnight: return "Midnight"
            case .lavender: return "Lavender"
            case .crimson: return "Crimson"
            case .coral: return "Coral"
            case .arctic: return "Arctic"
            case .cyberpunk: return "Cyberpunk"
            case .smokeGrey: return "Smoke Grey"
            }
        }
        
        var description: String {
            switch self {
            case .ocean: return "Calm teal and blue"
            case .sunset: return "Warm orange tones"
            case .forest: return "Natural green hues"
            case .midnight: return "Deep blue night"
            case .lavender: return "Soft purple shades"
            case .crimson: return "Bold red burgundy"
            case .coral: return "Vibrant coral peach"
            case .arctic: return "Cool light blue"
            case .cyberpunk: return "Blade Runner neon nights"
            case .smokeGrey: return "Sleek neutral grey"
            }
        }
    }
    
    enum FontStyle: String, CaseIterable {
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
        
        var displayName: String {
            switch self {
            case .system: return "System"
            case .rounded: return "Rounded"
            case .serif: return "Serif"
            case .monospaced: return "Monospaced"
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
                                Menu {
                                    Button(action: { 
                                        sidePanelView = .settings
                                        showSidePanel = true
                                    }) {
                                        Label("Settings", systemImage: "gearshape")
                                    }
                                    
                                    Button(action: { 
                                        sidePanelView = .notes
                                        showSidePanel = true
                                    }) {
                                        Label("Notes", systemImage: "note.text")
                                    }
                                    
                                    Button(action: { 
                                        sidePanelView = .chatHistory
                                        showSidePanel = true
                                    }) {
                                        Label("Conversations", systemImage: "message")
                                    }
                                    
                                    Button(action: { 
                                        sidePanelView = .arise
                                        showSidePanel = true
                                    }) {
                                        Label("ARISE", systemImage: "tree")
                                    }
                                } label: {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                
                                Spacer()
                                
                                // Apps Button - Right
                                Button(action: { 
                                    // TODO: Handle apps page
                                }) {
                                    Image(systemName: "square.grid.2x2")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                
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
                            if !attachedImages.isEmpty || !attachedFileURLs.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(attachedImages.indices, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: attachedImages[index])
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                
                                                Button(action: {
                                                    attachedImages.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(.black.opacity(0.5)))
                                                }
                                                .offset(x: 6, y: -6)
                                            }
                                        }
                                        
                                        ForEach(attachedFileURLs.indices, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                VStack(spacing: 4) {
                                                    Image(systemName: "doc.fill")
                                                        .font(.title2)
                                                        .foregroundColor(.white)
                                                    Text(attachedFileURLs[index].lastPathComponent)
                                                        .font(.caption2)
                                                        .foregroundColor(.white.opacity(0.8))
                                                        .lineLimit(1)
                                                        .frame(maxWidth: 50)
                                                }
                                                .frame(width: 60, height: 60)
                                                .background(Color.white.opacity(0.2))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                
                                                Button(action: {
                                                    attachedFileURLs.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(.black.opacity(0.5)))
                                                }
                                                .offset(x: 6, y: -6)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .frame(height: 70)
                            }
                            
                            // Input Field
                            HStack(spacing: 12) {
                                Menu {
                                    Button(action: { showPhotosPicker = true }) {
                                        Label("Photo Library", systemImage: "photo.on.rectangle")
                                    }
                                    
                                    Button(action: { showCamera = true }) {
                                        Label("Take Photo", systemImage: "camera")
                                    }
                                    
                                    Button(action: { showDocumentPicker = true }) {
                                        Label("Choose File", systemImage: "doc")
                                    }
                                } label: {
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
                                        // Stop button when loading
                                        Button(action: { 
                                            conversationManager.stopGenerating()
                                        }) {
                                            Image(systemName: "stop.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.red)
                                        }
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
            }
            .sheet(isPresented: $showSidePanel) {
                if sidePanelView == .settings {
                    SettingsView(
                        conversationManager: conversationManager,
                        showKeyboardOnLaunch: $showKeyboardOnLaunch,
                        serverAddress: $serverAddress,
                        systemPrompt: $systemPrompt,
                        selectedTheme: $selectedTheme,
                        selectedFontStyle: $selectedFontStyle,
                        safetyLevel: $safetyLevel,
                        selectedModel: $selectedModel,
                        availableModels: $availableModels,
                        reasoningEffort: $reasoningEffort,
                        isInSidePanel: false,
                        onBack: {
                            showSidePanel = false
                        },
                        onDismiss: {
                            showSidePanel = false
                        }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                } else if sidePanelView == .chatHistory {
                    ChatHistorySheetView(
                        conversationManager: conversationManager,
                        isPresented: $showSidePanel
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                } else if sidePanelView == .notes {
                    NotesView(
                        isInSidePanel: false,
                        onBack: {
                            showSidePanel = false
                        },
                        onDismiss: {
                            showSidePanel = false
                        }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                } else if sidePanelView == .arise {
                    ARISEView(
                        isInSidePanel: false,
                        onBack: {
                            showSidePanel = false
                        },
                        onDismiss: {
                            showSidePanel = false
                        }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotosItems, maxSelectionCount: 5, matching: .images)
            .onChange(of: selectedPhotosItems) { oldValue, newValue in
                Task {
                    for item in newValue {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            attachedImages.append(image)
                        }
                    }
                    selectedPhotosItems = []
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView(image: Binding(
                    get: { nil },
                    set: { image in
                        if let image = image {
                            attachedImages.append(image)
                        }
                    }
                ))
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView(fileURLs: $attachedFileURLs)
            }
        }
        .onAppear {
            // Start with a fresh conversation on app launch
            conversationManager.newConversation()
            
            // Load saved server address
            if let savedAddress = UserDefaults.standard.string(forKey: "serverAddress") {
                serverAddress = savedAddress
                conversationManager.serverAddress = savedAddress
            }
            
            // Load saved selected model
            if let savedModel = UserDefaults.standard.string(forKey: "selectedModel") {
                selectedModel = savedModel
                conversationManager.selectedModel = savedModel
            } else {
                // Sync the default selected model to conversation manager
                conversationManager.selectedModel = selectedModel
            }
            
            // Load saved safety level
            if let savedLevel = UserDefaults.standard.string(forKey: "safetyLevel"),
               let level = SafetyLevel(rawValue: savedLevel) {
                safetyLevel = level
                conversationManager.safetyLevel = level.rawValue
            }
            
            // Load saved reasoning effort
            if let savedEffort = UserDefaults.standard.string(forKey: "reasoningEffort"),
               let effort = ReasoningEffort(rawValue: savedEffort) {
                reasoningEffort = effort
                conversationManager.reasoningEffort = effort.rawValue
            }
            
            // Load saved theme
            if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
               let theme = AppTheme(rawValue: savedTheme) {
                selectedTheme = theme
            }
            
            // Load saved font style
            if let savedFont = UserDefaults.standard.string(forKey: "selectedFontStyle"),
               let font = FontStyle(rawValue: savedFont) {
                selectedFontStyle = font
            }
            
            // Load saved system prompt
            if let savedPrompt = UserDefaults.standard.string(forKey: "systemPrompt") {
                systemPrompt = savedPrompt
                conversationManager.systemPrompt = savedPrompt
            }
            
            if showKeyboardOnLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isInputFocused = true
                }
            }
            
            // Load models AFTER server address is set
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
        .onChange(of: selectedModel) { oldValue, newValue in
            conversationManager.selectedModel = newValue
            UserDefaults.standard.set(newValue, forKey: "selectedModel")
        }
        .onChange(of: safetyLevel) { oldValue, newValue in
            conversationManager.safetyLevel = newValue.rawValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "safetyLevel")
        }
        .onChange(of: reasoningEffort) { oldValue, newValue in
            conversationManager.reasoningEffort = newValue.rawValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "reasoningEffort")
        }
        .onChange(of: selectedTheme) { oldValue, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedTheme")
        }
        .onChange(of: selectedFontStyle) { oldValue, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedFontStyle")
        }
        .onChange(of: systemPrompt) { oldValue, newValue in
            conversationManager.systemPrompt = newValue
            UserDefaults.standard.set(newValue, forKey: "systemPrompt")
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
    
    private func supportsReasoningEffort(for model: String) -> Bool {
        let modelLower = model.lowercased()
        return modelLower.contains("gpt-oss") || 
               modelLower.contains("gpt-o") || 
               modelLower.contains("gpt-4o") || 
               modelLower.contains("o1") || 
               modelLower.contains("o3")
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
                            self.selectedModel = models.first ?? "gpt-oss:latest"
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
        Spacer()
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
                    
                    // Show "Thinking..." text when loading and last message is empty
                    if isLoading && (messages.last?.content.isEmpty ?? true) {
                        ThinkingIndicator(fontStyle: fontStyle)
                            .id("thinking-indicator")
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
                            proxy.scrollTo("thinking-indicator", anchor: .bottom)
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
    @State private var isThinkingExpanded = false
    
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
                // Debug: Print thinking content availability
                let _ = {
                    if let thinking = message.thinkingContent {
                        print("💭 Thinking content found: \(thinking.prefix(100))...")
                    } else {
                        print("❌ No thinking content for message")
                    }
                }()
                
                // Thinking section (collapsible)
                if let thinkingContent = message.thinkingContent, !thinkingContent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        // Thinking header button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isThinkingExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "brain")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.purple.opacity(0.9))
                                
                                Text("Thinking Process")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Spacer()
                                
                                Image(systemName: isThinkingExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.purple.opacity(0.8))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.1)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Expanded thinking content
                        if isThinkingExpanded {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow.opacity(0.8))
                                    Text("Model's internal reasoning")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                        .italic()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                                
                                ScrollView {
                                    Text(thinkingContent)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.85))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 300)
                            }
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                        }
                    }
                }
                
                // Main message content
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
                        
                    case .table(let tableData):
                        MarkdownTableView(data: tableData)
                            .padding(.vertical, 8)
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
        case table(TableData)
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
            
            // Check for Table
            // A table block typically starts with a header row containing pipes, followed by a separator row
            if line.contains("|") {
                let potentialHeader = line
                if i + 1 < lines.count {
                    let potentialSeparator = lines[i+1]
                    let separatorTrimmed = potentialSeparator.trimmingCharacters(in: .whitespaces)
                    
                    // Check if separator line looks like |---|---| or ---|---
                    // Must contain | and - and NOT contain alphanumeric characters (except maybe alignment colons :)
                    let isSeparator = separatorTrimmed.contains("|") && 
                                     separatorTrimmed.contains("-") && 
                                     !separatorTrimmed.contains(where: { $0.isLetter })
                    
                    if isSeparator {
                        // Found a table start!
                        if !currentText.isEmpty {
                            blocks.append(.text(parseMarkdown(currentText.trimmingCharacters(in: .whitespacesAndNewlines))))
                            currentText = ""
                        }
                        
                        var tableLines: [String] = [potentialHeader, potentialSeparator]
                        i += 2
                        
                        // Collect subsequent rows
                        while i < lines.count {
                            let rowLine = lines[i]
                            if !rowLine.trimmingCharacters(in: .whitespaces).isEmpty && rowLine.contains("|") {
                                tableLines.append(rowLine)
                                i += 1
                            } else {
                                break
                            }
                        }
                        
                        if let tableData = parseTable(tableLines) {
                            blocks.append(.table(tableData))
                        } else {
                            // Fallback: treat as text if parsing failed
                            currentText += tableLines.joined(separator: "\n") + "\n"
                        }
                        continue
                    }
                }
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
    
    private func parseTable(_ lines: [String]) -> TableData? {
        guard lines.count >= 2 else { return nil }
        
        func parseRow(_ line: String) -> [String] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Remove leading/trailing pipes if present
            var content = trimmed
            if content.hasPrefix("|") { content.removeFirst() }
            if content.hasSuffix("|") { content.removeLast() }
            
            // Split by pipe
            return content.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        let headers = parseRow(lines[0])
        guard !headers.isEmpty else { return nil }
        
        var rows: [[String]] = []
        for i in 2..<lines.count {
            let row = parseRow(lines[i])
            // Only add if it looks like a valid row (has content)
            if !row.isEmpty {
                // Pad with empty strings if fewer cells than headers
                var paddedRow = row
                if paddedRow.count < headers.count {
                    paddedRow.append(contentsOf: Array(repeating: "", count: headers.count - paddedRow.count))
                }
                // Truncate if more cells than headers
                if paddedRow.count > headers.count {
                    paddedRow = Array(paddedRow.prefix(headers.count))
                }
                rows.append(paddedRow)
            }
        }
        
        return TableData(headers: headers, rows: rows)
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
        do {
            var attributed = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            
            // Set base font and color
            // SwiftUI will apply bold/italic traits from markdown on top of this base font
            attributed.font = fontStyle.apply(size: 17, weight: .regular)
            attributed.foregroundColor = .white
            
            return attributed
        } catch {
            // Fallback to plain text if parsing fails
            var attributed = AttributedString(text)
            attributed.font = fontStyle.apply(size: 17, weight: .regular)
            attributed.foregroundColor = .white
            return attributed
        }
    }
}

enum SidePanelContentView {
    case navigation
    case chatHistory
    case settings
    case notes
    case arise
}

struct SidePanelContainerView: View {
    @ObservedObject var conversationManager: ConversationManager
    @Binding var showKeyboardOnLaunch: Bool
    @Binding var serverAddress: String
    @Binding var systemPrompt: String
    @Binding var selectedTheme: ChatView.AppTheme
    @Binding var selectedFontStyle: ChatView.FontStyle
    @Binding var safetyLevel: ChatView.SafetyLevel
    @Binding var selectedModel: String
    @Binding var availableModels: [String]
    @Binding var reasoningEffort: ChatView.ReasoningEffort
    @Binding var currentView: SidePanelContentView
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            if currentView == .navigation {
                NavigationSidebarView(
                    conversationManager: conversationManager,
                    currentView: $currentView,
                    isPresented: $isPresented
                )
                .transition(.move(edge: .leading))
            } else if currentView == .chatHistory {
                ChatHistoryView(
                    conversationManager: conversationManager,
                    currentView: $currentView,
                    isPresented: $isPresented
                )
                .transition(.move(edge: .leading))
            } else if currentView == .notes {
                NotesView(
                    isInSidePanel: true,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .navigation
                        }
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
                .transition(.move(edge: .trailing))
            } else if currentView == .arise {
                ARISEView(
                    isInSidePanel: true,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .navigation
                        }
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
                .transition(.move(edge: .trailing))
            } else {
                SettingsView(
                    conversationManager: conversationManager,
                    showKeyboardOnLaunch: $showKeyboardOnLaunch,
                    serverAddress: $serverAddress,
                    systemPrompt: $systemPrompt,
                    selectedTheme: $selectedTheme,
                    selectedFontStyle: $selectedFontStyle,
                    safetyLevel: $safetyLevel,
                    selectedModel: $selectedModel,
                    availableModels: $availableModels,
                    reasoningEffort: $reasoningEffort,
                    isInSidePanel: true,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .navigation
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

// New sheet-style conversation history view
struct ChatHistorySheetView: View {
    @ObservedObject var conversationManager: ConversationManager
    @Binding var isPresented: Bool
    @State private var searchText = ""
    
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversationManager.conversationHistory
        }
        return conversationManager.conversationHistory.filter { conversation in
            conversation.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var shouldShowCurrentConversation: Bool {
        guard !conversationManager.currentConversation.messages.isEmpty else {
            return false
        }
        
        if searchText.isEmpty {
            return true
        }
        
        return conversationManager.currentConversation.messages.contains { message in
            message.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar at top
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search", text: $searchText)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    // Conversations List
                    if conversationManager.conversationHistory.isEmpty && conversationManager.currentConversation.messages.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No conversations")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Text("Start a conversation to see it here")
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.8))
                            Spacer()
                        }
                    } else if !searchText.isEmpty && !shouldShowCurrentConversation && filteredConversations.isEmpty {
                        // Show "no results" when searching
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No results found")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.8))
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                // Section header
                                HStack {
                                    Text(searchText.isEmpty ? "Recents" : "Search Results")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                
                                // Current conversation if it has messages and matches search
                                if shouldShowCurrentConversation {
                                    ConversationSheetRow(
                                        conversation: conversationManager.currentConversation,
                                        conversationManager: conversationManager,
                                        isPresented: $isPresented,
                                        isCurrent: true
                                    )
                                }
                                
                                // History (filtered)
                                ForEach(filteredConversations) { conversation in
                                    ConversationSheetRow(
                                        conversation: conversation,
                                        conversationManager: conversationManager,
                                        isPresented: $isPresented,
                                        isCurrent: false
                                    )
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct ConversationSheetRow: View {
    let conversation: Conversation
    @ObservedObject var conversationManager: ConversationManager
    @Binding var isPresented: Bool
    let isCurrent: Bool
    @State private var offset: CGFloat = 0
    
    private var previewText: String {
        if let firstMessage = conversation.messages.first(where: { $0.isUser }) {
            return firstMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Empty conversation"
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: conversation.createdAt, relativeTo: Date())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                // Main conversation row - placed FIRST so it's behind
                Button(action: {
                    // Only respond to tap if not swiped
                    if offset == 0 {
                        if !isCurrent {
                            conversationManager.loadConversation(conversation)
                        }
                        isPresented = false
                    } else {
                        // Close the swipe if open
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                        }
                    }
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(previewText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.systemBackground))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .zIndex(1)
                .offset(x: offset)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -80)
                            } else if offset < 0 {
                                offset = min(value.translation.width + offset, 0)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if value.translation.width < -40 && offset > -40 {
                                    offset = -80
                                } else if value.translation.width > 40 || (offset < 0 && value.translation.width > 0) {
                                    offset = 0
                                } else if offset < -40 {
                                    offset = -80
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
                
                // Delete button background (revealed on swipe) - behind the main row
                if offset < 0 {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                if !isCurrent {
                                    conversationManager.conversationHistory.removeAll { $0.id == conversation.id }
                                } else {
                                    conversationManager.newConversation()
                                }
                                offset = 0
                            }
                        }) {
                            VStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.white)
                                    .font(.title3)
                            }
                            .frame(width: 80)
                            .frame(maxHeight: .infinity)
                            .background(Color.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .zIndex(0)
                }
            }
            .clipped()
            
            Divider()
                .padding(.leading, 20)
        }
    }
}

struct ConversationHistoryRow: View {
    let conversation: Conversation
    @ObservedObject var conversationManager: ConversationManager
    @Binding var isPresented: Bool
    @State private var offset: CGFloat = 0
    
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
        ZStack(alignment: .trailing) {
            // Main conversation row - placed FIRST
            Button(action: {
                // Only load conversation if not swiped
                if offset == 0 {
                    conversationManager.loadConversation(conversation)
                    isPresented = false
                } else {
                    // Close the swipe if open
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                    }
                }
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
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .zIndex(1)
            .offset(x: offset)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -70)
                        } else if offset < 0 {
                            offset = min(value.translation.width + offset, 0)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if value.translation.width < -35 && offset > -35 {
                                offset = -70
                            } else if value.translation.width > 35 || (offset < 0 && value.translation.width > 0) {
                                offset = 0
                            } else if offset < -35 {
                                offset = -70
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
            
            // Delete button (revealed on swipe) - only show when offset is negative
            if offset < 0 {
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                    .frame(width: 70)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
                    .onTapGesture {
                        withAnimation {
                            conversationManager.conversationHistory.removeAll { $0.id == conversation.id }
                            offset = 0
                        }
                    }
                }
                .padding(.horizontal, 16)
                .zIndex(0)
            }
        }
        .clipped()
    }
}

struct ThinkingIndicator: View {
    let fontStyle: ChatView.FontStyle
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Thinking")
                    .font(fontStyle.apply(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                // Animated dots
                HStack(spacing: 3) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 4, height: 4)
                            .opacity(animationAmount == Double(index) ? 0.3 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: animationAmount
                            )
                    }
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

// MARK: - Navigation Sidebar
struct NavigationSidebarView: View {
    @ObservedObject var conversationManager: ConversationManager
    @Binding var currentView: SidePanelContentView
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var projects = ["New project"]
    
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversationManager.conversationHistory
        }
        return conversationManager.conversationHistory.filter { conversation in
            conversation.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var shouldShowCurrentConversation: Bool {
        guard !conversationManager.currentConversation.messages.isEmpty else {
            return false
        }
        
        if searchText.isEmpty {
            return true
        }
        
        return conversationManager.currentConversation.messages.contains { message in
            message.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var isSearching: Bool {
        !searchText.isEmpty
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search Bar and New Chat Button
                HStack(spacing: 8) {
                    // Search Bar - Takes more width
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                        
                        TextField("Search", text: $searchText)
                            .foregroundColor(.white)
                            .font(.system(size: 17))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    
                    // New Chat Button - Smaller and more compact
                    Button(action: { 
                        conversationManager.newConversation()
                        isPresented = false
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // Only show main navigation items when not searching
                        if !isSearching {
                            // Main Navigation Items - Grouped
                            VStack(spacing: 0) {
                                NavItem(icon: "sparkles", title: "Atlas", isFirst: true) {
                                    isPresented = false
                                }
                                
                                NavItem(icon: "note.text", title: "Notes") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentView = .notes
                                    }
                                }
                                
                                NavItem(icon: "tree", title: "ARISE") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentView = .arise
                                    }
                                }
                                
                                NavItem(icon: "book", title: "Library") {
                                    // Handle library tap
                                }
                                
                                NavItem(icon: "clock", title: "Codex", isLast: true) {
                                    // Handle Codex tap
                                }
                            }
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            
                            // Projects Section - Grouped
                            VStack(spacing: 0) {
                                ForEach(Array(projects.enumerated()), id: \.element) { index, project in
                                    NavItem(
                                        icon: "folder",
                                        title: project,
                                        isFirst: index == 0,
                                        isLast: index == projects.count - 1
                                    ) {
                                        // Handle project tap
                                    }
                                }
                            }
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                        
                        // Show search results or conversation history
                        if isSearching && !shouldShowCurrentConversation && filteredConversations.isEmpty {
                            // No results found
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No results found")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            // Conversation History - Ungrouped, just a list
                            VStack(alignment: .leading, spacing: 8) {
                                // Show section header when searching
                                if isSearching {
                                    Text("Search Results")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                }
                                
                                // Current Conversation (if it has messages and matches search)
                                if shouldShowCurrentConversation {
                                    ConversationNavItem(
                                        conversation: conversationManager.currentConversation,
                                        conversationManager: conversationManager,
                                        isPresented: $isPresented,
                                        isCurrent: true
                                    )
                                    .padding(.horizontal, 16)
                                }
                                
                                // Conversation History (filtered)
                                ForEach(filteredConversations) { conversation in
                                    ConversationNavItem(
                                        conversation: conversation,
                                        conversationManager: conversationManager,
                                        isPresented: $isPresented,
                                        isCurrent: false
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                
                // Bottom Settings Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .settings
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        
                        Text("Settings")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct ConversationNavItem: View {
    let conversation: Conversation
    @ObservedObject var conversationManager: ConversationManager
    @Binding var isPresented: Bool
    let isCurrent: Bool
    @State private var offset: CGFloat = 0
    
    private var previewText: String {
        if let firstMessage = conversation.messages.first(where: { $0.isUser }) {
            let text = firstMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "Empty conversation" : text
        }
        return "Empty conversation"
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Main conversation item - simple text button - placed FIRST
            Button(action: {
                // Only load conversation if not swiped
                if offset == 0 {
                    if !isCurrent {
                        conversationManager.loadConversation(conversation)
                    }
                    isPresented = false
                } else {
                    // Close the swipe if open
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                    }
                }
            }) {
                Text(previewText)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .background(Color.black)
            .zIndex(1)
            .offset(x: offset)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -70)
                        } else if offset < 0 {
                            offset = min(value.translation.width + offset, 0)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if value.translation.width < -35 && offset > -35 {
                                offset = -70
                            } else if value.translation.width > 35 || (offset < 0 && value.translation.width > 0) {
                                offset = 0
                            } else if offset < -35 {
                                offset = -70
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
            
            // Delete button (revealed on swipe) - only show when offset is negative
            if offset < 0 {
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.white)
                    }
                    .frame(width: 70)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .onTapGesture {
                        withAnimation {
                            if !isCurrent {
                                conversationManager.conversationHistory.removeAll { $0.id == conversation.id }
                            } else {
                                conversationManager.newConversation()
                            }
                            offset = 0
                        }
                    }
                }
                .zIndex(0)
            }
        }
        .clipped()
    }
}

struct NavItem: View {
    let icon: String
    let title: String
    var isFirst: Bool = false
    var isLast: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            // Add subtle divider between items (not on last item)
            Group {
                if !isLast {
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 0.5)
                            .padding(.leading, 56) // Indent to align with text
                    }
                }
            }
        )
    }
}

// MARK: - Camera Picker
struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        
        init(_ parent: CameraPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Document Picker
struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var fileURLs: [URL]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.fileURLs.append(contentsOf: urls)
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ChatView()
}

