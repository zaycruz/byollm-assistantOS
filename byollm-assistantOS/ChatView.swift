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
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var voiceService = VoiceService()
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var voiceWebSocket = VoiceWebSocketManager()
    @State private var inputText = ""
    @State private var showSidePanel = false
    @State private var showSettings = false
    @State private var sidePanelView: SidePanelContentView = .navigation
    @State private var showKeyboardOnLaunch = true
    @State private var serverAddress = ""
    @State private var systemPrompt = ""
    @State private var selectedTheme: AppTheme = .obsidian
    @State private var selectedFontStyle: FontStyle = .system
    @State private var selectedModel = "gpt-oss:latest"
    @State private var availableModels: [String] = ["gpt-oss:latest"]
    @State private var cloudModels: [String] = ["claude-sonnet-4-5"]
    @State private var safetyLevel: SafetyLevel = .medium
    @State private var reasoningEffort: ReasoningEffort = .medium
    @State private var provider: Provider = .local
    
    // Attachment states
    @State private var showAttachmentOptions = false
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showFilePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    private struct PendingAttachment: Identifiable {
        let id = UUID()
        let data: Data
        let previewData: Data?
        let filename: String
        let mimeType: String
    }
    
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var attachmentUploadError: String?
    
    // Voice Mode state (integrated in chat, not separate view)
    @State private var isVoiceModeActive = false
    @State private var voiceModeWaveformPhase: CGFloat = 0
    @State private var shouldSpeakNextResponse = false
    
    // Computed property for current available models based on provider
    private var currentAvailableModels: [String] {
        provider == .cloud ? cloudModels : availableModels
    }
    @State private var keyboardHeight: CGFloat = 0
    @State private var inputTextHeight: CGFloat = 28
    @FocusState private var isInputFocused: Bool
    
    enum Provider: String, CaseIterable {
        case local = "local"
        case cloud = "cloud"
        
        var displayName: String {
            switch self {
            case .local: return "Local"
            case .cloud: return "Cloud"
            }
        }
    }
    
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
    
    enum AppTheme {
        case obsidian, ocean, sunset, forest, midnight, lavender, crimson, coral, arctic
        
        var colors: [Color] {
            switch self {
            case .obsidian:
                // Smooth dark gradient with subtle depth
                return [
                    Color(red: 0.08, green: 0.08, blue: 0.10),
                    Color(red: 0.06, green: 0.06, blue: 0.08),
                    Color(red: 0.04, green: 0.04, blue: 0.06),
                    Color(red: 0.03, green: 0.03, blue: 0.04),
                    Color(red: 0.02, green: 0.02, blue: 0.03)
                ]
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
        
        var storageValue: String {
            switch self {
            case .obsidian: return "obsidian"
            case .ocean: return "ocean"
            case .sunset: return "sunset"
            case .forest: return "forest"
            case .midnight: return "midnight"
            case .lavender: return "lavender"
            case .crimson: return "crimson"
            case .coral: return "coral"
            case .arctic: return "arctic"
            }
        }
        
        init?(storageValue: String) {
            switch storageValue {
            case "obsidian": self = .obsidian
            case "ocean": self = .ocean
            case "sunset": self = .sunset
            case "forest": self = .forest
            case "midnight": self = .midnight
            case "lavender": self = .lavender
            case "crimson": self = .crimson
            case "coral": self = .coral
            case "arctic": self = .arctic
            default: return nil
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
        
        var storageValue: String {
            switch self {
            case .system: return "system"
            case .rounded: return "rounded"
            case .serif: return "serif"
            case .monospaced: return "monospaced"
            }
        }
        
        init?(storageValue: String) {
            switch storageValue {
            case "system": self = .system
            case "rounded": self = .rounded
            case "serif": self = .serif
            case "monospaced": self = .monospaced
            default: return nil
            }
        }
    }
    
    var body: some View {
        bodyWithModifiers
    }
    
    private var bodyWithModifiers: some View {
        bodyWithSettingsModifiers
            .onChange(of: provider) { _, newValue in handleProviderChange(newValue) }
            .onChange(of: speechRecognizer.transcript) { _, newValue in handleTranscriptChange(newValue) }
    }
    
    private var bodyWithSettingsModifiers: some View {
        bodyWithBasicModifiers
            .onChange(of: systemPrompt) { _, newValue in handleSystemPromptChange(newValue) }
            .onChange(of: selectedModel) { _, newValue in handleSelectedModelChange(newValue) }
            .onChange(of: safetyLevel) { _, newValue in handleSafetyLevelChange(newValue) }
            .onChange(of: reasoningEffort) { _, newValue in handleReasoningEffortChange(newValue) }
    }
    
    private var bodyWithBasicModifiers: some View {
        mainContent
            .onAppear(perform: handleOnAppear)
            .onChange(of: serverAddress) { _, newValue in handleServerAddressChange(newValue) }
            .onChange(of: showKeyboardOnLaunch) { _, newValue in UserDefaults.standard.set(newValue, forKey: "showKeyboardOnLaunch") }
            .onChange(of: selectedTheme) { _, newValue in UserDefaults.standard.set(newValue.storageValue, forKey: "selectedTheme") }
            .onChange(of: selectedFontStyle) { _, newValue in UserDefaults.standard.set(newValue.storageValue, forKey: "selectedFontStyle") }
    }
    
    private func handleOnAppear() {
        conversationManager.newConversation()
        
        if let savedAddress = UserDefaults.standard.string(forKey: "serverAddress") {
            serverAddress = savedAddress
            conversationManager.serverAddress = savedAddress
            voiceService.configure(serverAddress: savedAddress)
            voiceWebSocket.configure(serverAddress: savedAddress)
        }
        
        if UserDefaults.standard.object(forKey: "showKeyboardOnLaunch") != nil {
            showKeyboardOnLaunch = UserDefaults.standard.bool(forKey: "showKeyboardOnLaunch")
        }
        
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(storageValue: savedTheme) {
            selectedTheme = theme
        }
        if let savedFont = UserDefaults.standard.string(forKey: "selectedFontStyle"),
           let font = FontStyle(storageValue: savedFont) {
            selectedFontStyle = font
        }
        
        if let savedSystemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") {
            systemPrompt = savedSystemPrompt
            conversationManager.systemPrompt = savedSystemPrompt
        }
        
        if let savedModel = UserDefaults.standard.string(forKey: "selectedModel") {
            selectedModel = savedModel
            conversationManager.selectedModel = savedModel
        } else {
            conversationManager.selectedModel = selectedModel
        }
        
        if let savedLevel = UserDefaults.standard.string(forKey: "safetyLevel"),
           let level = SafetyLevel(rawValue: savedLevel) {
            safetyLevel = level
            conversationManager.safetyLevel = level.rawValue
        }
        
        if let savedEffort = UserDefaults.standard.string(forKey: "reasoningEffort"),
           let effort = ReasoningEffort(rawValue: savedEffort) {
            reasoningEffort = effort
            conversationManager.reasoningEffort = effort.rawValue
        }
        
        if let savedProvider = UserDefaults.standard.string(forKey: "provider"),
           let providerValue = Provider(rawValue: savedProvider) {
            provider = providerValue
            conversationManager.provider = providerValue.rawValue
        } else {
            conversationManager.provider = provider.rawValue
        }
        
        if provider == .cloud && !cloudModels.contains(selectedModel) {
            selectedModel = cloudModels.first ?? "claude-sonnet-4-5"
            conversationManager.selectedModel = selectedModel
        }
        
        if showKeyboardOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isInputFocused = true
            }
        }
        
        loadModelsFromServer()
        setupKeyboardNotifications()
    }
    
    private func setupKeyboardNotifications() {
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
    
    private func handleServerAddressChange(_ newValue: String) {
        conversationManager.serverAddress = newValue
        UserDefaults.standard.set(newValue, forKey: "serverAddress")
        voiceService.configure(serverAddress: newValue)
        voiceWebSocket.configure(serverAddress: newValue)
        loadModelsFromServer()
    }
    
    private func handleSystemPromptChange(_ newValue: String) {
        conversationManager.systemPrompt = newValue
        UserDefaults.standard.set(newValue, forKey: "systemPrompt")
    }
    
    private func handleSelectedModelChange(_ newValue: String) {
        conversationManager.selectedModel = newValue
        UserDefaults.standard.set(newValue, forKey: "selectedModel")
    }
    
    private func handleSafetyLevelChange(_ newValue: SafetyLevel) {
        conversationManager.safetyLevel = newValue.rawValue
        UserDefaults.standard.set(newValue.rawValue, forKey: "safetyLevel")
    }
    
    private func handleReasoningEffortChange(_ newValue: ReasoningEffort) {
        conversationManager.reasoningEffort = newValue.rawValue
        UserDefaults.standard.set(newValue.rawValue, forKey: "reasoningEffort")
    }
    
    private func handleProviderChange(_ newValue: Provider) {
        conversationManager.provider = newValue.rawValue
        UserDefaults.standard.set(newValue.rawValue, forKey: "provider")
        
        if newValue == .cloud {
            if !cloudModels.contains(selectedModel) {
                selectedModel = cloudModels.first ?? "claude-sonnet-4-5"
            }
        } else {
            if !availableModels.contains(selectedModel) {
                selectedModel = availableModels.first ?? "gpt-oss:latest"
            }
        }
    }
    
    private func handleTranscriptChange(_ newValue: String) {
        if speechRecognizer.isRecording && !newValue.isEmpty {
            inputText = newValue
        }
    }
    
    private var mainContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                ZStack {
                    LinearGradient(
                        colors: selectedTheme.colors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .onTapGesture {
                        isInputFocused = false
                    }
                    
                    
                    VStack(spacing: 0) {
                        topBar
                        messagesContent
                        chatInputArea
                            .padding(.bottom, keyboardHeight > 0 ? 8 : 40)
                    }
                }
            }
            .sheet(isPresented: $showSidePanel) {
                sheetContent
            }
            .confirmationDialog("Add Attachment", isPresented: $showAttachmentOptions, titleVisibility: .visible) {
                Button("Photo Library") {
                    showImagePicker = true
                }
                Button("Take Photo") {
                    showCamera = true
                }
                Button("Choose File") {
                    showFilePicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    if let newValue = newValue,
                       let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await addImageAttachment(image)
                        await MainActor.run { selectedPhotoItem = nil }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newValue in
                guard let image = newValue else { return }
                Task {
                    await addImageAttachment(image)
                    await MainActor.run { selectedImage = nil }
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item]) { result in
                switch result {
                case .success(let url):
                    Task {
                        await addFileAttachment(from: url)
                    }
                case .failure(let error):
                    print("File selection error: \(error)")
                }
            }
            .alert("Upload failed", isPresented: Binding(
                get: { attachmentUploadError != nil },
                set: { newValue in
                    if !newValue { attachmentUploadError = nil }
                }
            )) {
                Button("OK", role: .cancel) { attachmentUploadError = nil }
            } message: {
                Text(attachmentUploadError ?? "")
            }
        }
    }
    
    @ViewBuilder
    private var sheetContent: some View {
        if sidePanelView == .settings {
            SettingsView(
                conversationManager: conversationManager,
                showKeyboardOnLaunch: $showKeyboardOnLaunch,
                serverAddress: $serverAddress,
                systemPrompt: $systemPrompt,
                selectedTheme: $selectedTheme,
                selectedFontStyle: $selectedFontStyle,
                safetyLevel: $safetyLevel,
                provider: $provider,
                selectedModel: $selectedModel,
                availableModels: $availableModels,
                cloudModels: $cloudModels,
                reasoningEffort: $reasoningEffort,
                isInSidePanel: false,
                onBack: { showSidePanel = false },
                onDismiss: { showSidePanel = false }
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
        }
    }
    
    private var topBar: some View {
        HStack {
            HStack(spacing: 16) {
                Button(action: { 
                    sidePanelView = .settings
                    showSidePanel = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Button(action: { 
                    sidePanelView = .chatHistory
                    showSidePanel = true
                }) {
                    Image(systemName: "message")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.15))
            .cornerRadius(25)
            
            Spacer()
            
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
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private var messagesContent: some View {
        if conversationManager.currentConversation.messages.isEmpty {
            WelcomeView(fontStyle: selectedFontStyle)
        } else {
            MessagesListView(
                messages: conversationManager.currentConversation.messages,
                fontStyle: selectedFontStyle,
                isLoading: conversationManager.isLoading,
                isInputFocused: $isInputFocused
            )
        }
    }
    
    private var chatInputArea: some View {
        HStack(spacing: 10) {
            // Plus button - outside the glass container
            Button(action: { showAttachmentOptions = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .overlay(alignment: .topTrailing) {
                if !pendingAttachments.isEmpty {
                    Text("\(pendingAttachments.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(6)
                        .background(Color.white)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
            
            // Glass input container
            glassInputContainer
            
            // Voice mode button - outside the glass container
            voiceModeButton
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    private var glassInputContainer: some View {
        HStack(spacing: 8) {
            if speechRecognizer.isRecording && !isVoiceModeActive {
                // STT Recording mode - compact waveform
                sttRecordingContent
            } else {
                // Normal text input with mic
                normalInputContent
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
    
    private var normalInputContent: some View {
        VStack(spacing: 10) {
            if !pendingAttachments.isEmpty {
                attachmentPreviewStrip
            }
            
            HStack(spacing: 8) {
                // Text field
                ZStack(alignment: .leading) {
                    if inputText.isEmpty {
                        Text("Ask anything")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    TextField("", text: $inputText, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .focused($isInputFocused)
                        .lineLimit(1...4)
                        .disabled(conversationManager.isLoading)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.sentences)
                        .onSubmit { if !inputText.isEmpty { sendMessage() } }
                }
                .frame(maxWidth: .infinity)
                
                // Mic button inside the glass
                Button(action: { speechRecognizer.startRecording() }) {
                    Image(systemName: "mic")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    private var attachmentPreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(pendingAttachments) { attachment in
                    attachmentPreviewTile(for: attachment)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: 58)
    }
    
    @ViewBuilder
    private func attachmentPreviewTile(for attachment: PendingAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
                .overlay {
                    if attachment.mimeType.lowercased().hasPrefix("image/"),
                       let image = UIImage(data: attachment.previewData ?? attachment.data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                            .cornerRadius(14)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            Text(attachment.filename)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                }
                .frame(width: 58, height: 58)
            
            Button(action: { removePendingAttachment(attachment.id) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.55))
                    )
            }
            .padding(6)
        }
    }
    
    private func removePendingAttachment(_ id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }
    
    private func makeThumbnailJPEG(from image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1.0
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
    
    private var sttRecordingContent: some View {
        HStack(spacing: 12) {
            // Stop button
            Button(action: {
                speechRecognizer.stopRecording()
                if !speechRecognizer.transcript.isEmpty {
                    inputText = speechRecognizer.transcript
                }
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            
            // Waveform
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { index in
                    WaveformBar(index: index)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            
            // Send button
            Button(action: {
                speechRecognizer.stopRecording()
                if !speechRecognizer.transcript.isEmpty {
                    inputText = speechRecognizer.transcript
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !inputText.isEmpty { sendMessage() }
                    }
                }
            }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 28, height: 28)
                    .background(Color.white)
                    .clipShape(Circle())
            }
        }
    }
    
    @ViewBuilder
    private var voiceModeButton: some View {
        if conversationManager.isLoading {
            // Stop button when generating
            Button(action: { conversationManager.stopGenerating() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        } else if !inputText.isEmpty {
            // Send button when there's text
            Button(action: { sendMessage() }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
            }
        } else if isVoiceModeActive {
            // End voice mode button - shows different states
            Button(action: {
                // While the assistant is generating/speaking, treat this as a "Stop" (barge-in) button.
                // Otherwise, exit voice mode entirely.
                if voiceWebSocket.isSpeaking || voiceWebSocket.isProcessing {
                    voiceWebSocket.interruptCurrentTurn()
                } else {
                    endVoiceMode()
                }
            }) {
                HStack(spacing: 4) {
                    if voiceWebSocket.isSpeaking {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14))
                    } else if voiceWebSocket.isListening {
                        VoiceModeWaveform()
                    } else if voiceWebSocket.isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.black)
                    } else {
                        VoiceModeWaveform()
                    }
                    Text((voiceWebSocket.isSpeaking || voiceWebSocket.isProcessing) ? "Stop" : "End")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.white)
                .clipShape(Capsule())
            }
        } else {
            // Start voice mode button
            Button(action: { startVoiceMode() }) {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Voice Mode Functions (WebSocket-based)
    
    private func startVoiceMode() {
        isVoiceModeActive = true
        
        // Set up callback for when response completes (to resume listening)
        voiceWebSocket.onResponseComplete = {
            resumeListeningAfterResponse()
        }
        
        // Set up callback for when transcript is received (add to chat)
        voiceWebSocket.onTranscript = { text in
            addVoiceUserMessage(text)
        }
        
        // Set up callback for when AI response is complete (add to chat)
        voiceWebSocket.onAIResponse = { text in
            addVoiceAIMessage(text)
        }
        
        // Connect and start listening
        voiceWebSocket.connect()
        
        // Small delay to ensure connection before starting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            voiceWebSocket.startListening()
        }
    }
    
    private func endVoiceMode() {
        isVoiceModeActive = false
        shouldSpeakNextResponse = false
        voiceWebSocket.onResponseComplete = nil
        voiceWebSocket.onTranscript = nil
        voiceWebSocket.onAIResponse = nil
        voiceWebSocket.stopListening()
        voiceWebSocket.disconnect()
    }
    
    private func resumeListeningAfterResponse() {
        guard isVoiceModeActive else { return }
        
        // Small delay before resuming to avoid picking up speaker audio
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if isVoiceModeActive && !voiceWebSocket.isSpeaking {
                voiceWebSocket.startListening()
            }
        }
    }
    
    // Called after AI response to speak it (REST fallback)
    private func speakResponse(_ text: String) {
        guard voiceService.isTTSAvailable else { return }
        
        Task {
            await voiceService.speak(text: text)
        }
    }
    
    // Add voice transcript as user message
    private func addVoiceUserMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let message = Message(content: text, isUser: true, timestamp: Date())
        conversationManager.currentConversation.messages.append(message)
    }
    
    // Add voice response as AI message
    private func addVoiceAIMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let message = Message(content: text, isUser: false, timestamp: Date())
        conversationManager.currentConversation.messages.append(message)
    }

    @ViewBuilder
    private var inputActionButton: some View {
        if conversationManager.isLoading {
            Button(action: { conversationManager.stopGenerating() }) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.red)
            }
        } else if !inputText.isEmpty {
            Button(action: { sendMessage() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
        }
    }
    
    private func updateInputHeight(for text: String) {
        if text.isEmpty {
            inputTextHeight = 28
        } else {
            let explicitLines = text.components(separatedBy: .newlines).count
            let estimatedWrappedLines = max(1, Int(ceil(Double(text.replacingOccurrences(of: "\n", with: "").count) / 35.0)))
            let totalLines = max(explicitLines, estimatedWrappedLines)
            let estimatedHeight = CGFloat(totalLines) * 20.0 + 8.0
            inputTextHeight = min(max(28, estimatedHeight), 120)
        }
    }
    
    // MARK: - Attachments (multipart /v1/chat/completions)
    
    private func addImageAttachment(_ image: UIImage) async {
        // Prefer JPEG for predictable server inlining behavior and smaller size.
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            await MainActor.run {
                attachmentUploadError = "Failed to encode image."
            }
            return
        }
        
        let preview = makeThumbnailJPEG(from: image, maxDimension: 512, quality: 0.82)
        
        let filename = "image-\(Int(Date().timeIntervalSince1970)).jpg"
        await MainActor.run {
            pendingAttachments.append(PendingAttachment(data: data, previewData: preview, filename: filename, mimeType: "image/jpeg"))
        }
    }
    
    private func addFileAttachment(from url: URL) async {
        var didStartAccessing = false
        if url.startAccessingSecurityScopedResource() {
            didStartAccessing = true
        }
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            let filename = url.lastPathComponent.isEmpty ? "file" : url.lastPathComponent
            let ext = url.pathExtension
            let mimeType = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
            await MainActor.run {
                pendingAttachments.append(PendingAttachment(data: data, previewData: nil, filename: filename, mimeType: mimeType))
            }
        } catch {
            await MainActor.run {
                attachmentUploadError = error.localizedDescription
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let files = pendingAttachments.map { ChatCompletionFile(filename: $0.filename, mimeType: $0.mimeType, data: $0.data) }
        let messageAttachments = pendingAttachments.map { attachment in
            MessageAttachment(
                filename: attachment.filename,
                mimeType: attachment.mimeType,
                thumbnailData: attachment.previewData
            )
        }
        conversationManager.sendMessage(inputText, files: files, messageAttachments: messageAttachments)
        inputText = ""
        inputTextHeight = 28
        pendingAttachments.removeAll()
        attachmentUploadError = nil
        
        // Note: Voice mode now uses WebSocket which handles TTS internally
        // The shouldSpeakNextResponse flag is kept for potential REST fallback
        if shouldSpeakNextResponse {
            shouldSpeakNextResponse = false
        }
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
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text("BYOLLM")
                    .font(fontStyle.apply(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                
                Text("Bring Your Own LLM")
                    .font(fontStyle.apply(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
    }
}

struct MessagesListView: View {
    let messages: [Message]
    let fontStyle: ChatView.FontStyle
    let isLoading: Bool
    @FocusState.Binding var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewHeight: CGFloat = 0

    private var showScrollButton: Bool {
        // Show button if we have messages and scrolled up more than 150 points
        messages.count > 1 && scrollOffset > 150
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { outerGeo in
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 20) {
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
                        .background(
                            GeometryReader { contentGeo in
                                Color.clear
                                    .preference(key: ScrollOffsetKey.self, value: contentGeo.frame(in: .named("scroll")).minY)
                                    .onAppear {
                                        contentHeight = contentGeo.size.height
                                    }
                                    .onChange(of: contentGeo.size.height) { _, newHeight in
                                        contentHeight = newHeight
                                    }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isInputFocused = false
                        }
                        .onAppear {
                            scrollProxy = proxy
                            viewHeight = outerGeo.size.height
                            // Scroll to bottom on initial load
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if let lastMessage = messages.last {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
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
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    // Calculate how far from bottom we are
                    // offset is negative when scrolled up
                    let maxOffset = contentHeight - outerGeo.size.height
                    let distanceFromBottom = maxOffset + offset
                    scrollOffset = max(0, distanceFromBottom)
                }
            }
            
            // Scroll to bottom button
            if showScrollButton {
                Button(action: {
                    if let lastMessage = messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.bottom, 24)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: showScrollButton)
            }
        }
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
                
                VStack(alignment: .trailing, spacing: 8) {
                    if let attachments = message.attachments, !attachments.isEmpty {
                        userMessageAttachmentsView(attachments)
                    }
                    
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
    
    @ViewBuilder
    private func userMessageAttachmentsView(_ attachments: [MessageAttachment]) -> some View {
        // Right-align attachments to match the outgoing bubble alignment.
        HStack {
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(attachments) { attachment in
                        userAttachmentTile(attachment)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(width: 280, alignment: .trailing)
        }
        .frame(height: 190)
    }
    
    @ViewBuilder
    private func userAttachmentTile(_ attachment: MessageAttachment) -> some View {
        let isImage = attachment.mimeType.lowercased().hasPrefix("image/")
        
        if isImage, let thumb = attachment.thumbnailData, let image = UIImage(data: thumb) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 190, height: 190)
                .clipped()
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text(attachment.filename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: 190, height: 190)
            .background(Color.white.opacity(0.12))
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
            )
        }
    }
}

enum SidePanelContentView {
    case navigation
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
    @Binding var provider: ChatView.Provider
    @Binding var selectedModel: String
    @Binding var availableModels: [String]
    @Binding var cloudModels: [String]
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
            } else {
                SettingsView(
                    conversationManager: conversationManager,
                    showKeyboardOnLaunch: $showKeyboardOnLaunch,
                    serverAddress: $serverAddress,
                    systemPrompt: $systemPrompt,
                    selectedTheme: $selectedTheme,
                    selectedFontStyle: $selectedFontStyle,
                    safetyLevel: $safetyLevel,
                    provider: $provider,
                    selectedModel: $selectedModel,
                    availableModels: $availableModels,
                    cloudModels: $cloudModels,
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

// MARK: - Waveform Bar (Recording Animation)
struct WaveformBar: View {
    let index: Int
    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.white.opacity(0.6))
            .frame(width: 3, height: height)
            .onAppear {
                withAnimation(
                    Animation
                        .easeInOut(duration: Double.random(in: 0.3...0.6))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.05)
                ) {
                    height = CGFloat.random(in: 8...28)
                }
            }
    }
}

// MARK: - Voice Mode Waveform (End Button)
struct VoiceModeWaveform: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.black)
                    .frame(width: 2, height: barHeight(for: index))
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                phase += 0.5
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let base: CGFloat = 10
        let variation = sin(phase + CGFloat(index) * 0.8) * 5
        return max(4, base + variation)
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
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
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ChatView()
}

