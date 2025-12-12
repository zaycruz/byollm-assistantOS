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
    @State private var presentedSheet: PresentedSheet?
    @State private var showKeyboardOnLaunch = true
    @State private var serverAddress = ""
    @State private var systemPrompt = ""
    @State private var selectedModel = "gpt-oss:latest"
    @State private var availableModels: [String] = ["gpt-oss:latest"]
    @State private var cloudModels: [String] = ["claude-sonnet-4-5"]
    @State private var safetyLevel: SafetyLevel = .medium
    @State private var reasoningEffort: ReasoningEffort = .medium
    @State private var provider: Provider = .local
    
    // Computed property for current available models based on provider
    private var currentAvailableModels: [String] {
        provider == .cloud ? cloudModels : availableModels
    }
    @State private var keyboardHeight: CGFloat = 0
    @State private var inputTextHeight: CGFloat = 36
    @FocusState private var isInputFocused: Bool
    @State private var isSidebarOpen: Bool = false
    @State private var sidebarDragX: CGFloat = 0
    
    enum Provider: String, CaseIterable {
        case local = "local"
        case cloud = "cloud"
        
        var displayName: String {
            switch self {
            case .local: return "Server (Local)"
            case .cloud: return "Server (Cloud)"
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Main Content
                ZStack {
                    // Background
                    NatureTechBackground()
                        .ignoresSafeArea()
                        .onTapGesture { isInputFocused = false }
                    
                    VStack(spacing: 0) {
                        // Top Bar
                        HStack {
                            Button(action: { openSidebar() }) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            
                            Spacer()
                            
                            VStack(spacing: 2) {
                                Text("Chat")
                                    .font(DesignSystem.Typography.body().weight(.semibold))
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                
                                Text(formatModelName(selectedModel))
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Button(action: { presentedSheet = .controls }) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { conversationManager.newConversation() }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                        .background(DesignSystem.Colors.chrome.opacity(0.98))
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundStyle(DesignSystem.Colors.separator),
                            alignment: .bottom
                        )
                        
                        // Messages Area
                        if conversationManager.currentConversation.messages.isEmpty {
                            WelcomeView(
                                isServerConfigured: !(serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
                                onOpenSettings: { presentedSheet = .settings }
                            )
                        } else {
                            MessagesListView(
                                messages: conversationManager.currentConversation.messages,
                                isLoading: conversationManager.isLoading,
                                isInputFocused: $isInputFocused
                            )
                        }
                        
                        // Input Area
                        VStack(spacing: 0) {
                            // Divider
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundStyle(DesignSystem.Colors.separator)
                            
                            HStack(alignment: .bottom, spacing: 12) {
                                // Input Field
                                ZStack(alignment: .topLeading) {
                                    if inputText.isEmpty {
                                        Text(serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Connect your server to chat…" : "Message your assistant…")
                                            .font(DesignSystem.Typography.body())
                                            .foregroundColor(DesignSystem.Colors.textTertiary)
                                            .padding(.horizontal, 4)
                                            .padding(.top, 8)
                                    }
                                    
                                    TextEditor(text: $inputText)
                                        .font(DesignSystem.Typography.body())
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .focused($isInputFocused)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .frame(height: inputTextHeight)
                                        .padding(.horizontal, -4)
                                        .padding(.vertical, -8)
                                        .onChange(of: inputText) { oldValue, newValue in
                                            if newValue.count > 10000 {
                                                inputText = String(newValue.prefix(10000))
                                            }
                                            
                                            if newValue.isEmpty {
                                                inputTextHeight = 36
                                            } else {
                                                let explicitLines = newValue.components(separatedBy: .newlines).count
                                                let estimatedWrappedLines = max(1, Int(ceil(Double(newValue.replacingOccurrences(of: "\n", with: "").count) / 30.0)))
                                                let totalLines = max(explicitLines, estimatedWrappedLines)
                                                let estimatedHeight = CGFloat(totalLines) * 22.0 + 12.0
                                                inputTextHeight = min(max(36, estimatedHeight), 120)
                                            }
                                        }
                                }
                                .frame(height: inputTextHeight)
                                .padding(12)
                                .background(DesignSystem.Colors.surfaceElevated)
                                .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                                        .stroke(isInputFocused ? DesignSystem.Colors.accent : DesignSystem.Colors.border.opacity(0.8), lineWidth: DesignSystem.Layout.borderWidth)
                                )
                                
                                // Send / Stop Button
                                if conversationManager.isLoading {
                                    Button(action: { conversationManager.stopGenerating() }) {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(DesignSystem.Colors.error)
                                            .frame(width: 44, height: 44)
                                            .background(DesignSystem.Colors.surfaceElevated)
                                            .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
                                    }
                                    .padding(.bottom, 0)
                                } else {
                                    Button(action: { sendMessage() }) {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 16))
                                            .foregroundStyle(inputText.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.surface)
                                            .frame(width: 44, height: 44)
                                            .background(inputText.isEmpty ? DesignSystem.Colors.surfaceElevated : DesignSystem.Colors.accent)
                                            .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
                                    }
                                    .disabled(inputText.isEmpty || serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .padding(.bottom, 0)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(DesignSystem.Colors.chrome.opacity(0.98))
                        }
                        .padding(.bottom, keyboardHeight > 0 ? 0 : 0)
                    }
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .controls:
                    ChatControlsSheetView(
                        serverAddress: serverAddress,
                        selectedModel: $selectedModel,
                        availableModels: currentAvailableModels,
                        provider: $provider,
                        safetyLevel: $safetyLevel,
                        reasoningEffort: $reasoningEffort,
                        supportsReasoningEffort: supportsReasoningEffort(for: selectedModel),
                        onOpenSettings: { presentedSheet = .settings }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                case .settings:
                    SettingsView(
                        conversationManager: conversationManager,
                        showKeyboardOnLaunch: $showKeyboardOnLaunch,
                        serverAddress: $serverAddress,
                        systemPrompt: $systemPrompt,
                        safetyLevel: $safetyLevel,
                        provider: $provider,
                        isInSidePanel: false,
                        onBack: nil,
                        onDismiss: { presentedSheet = nil }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            
            // Sidebar overlay (ChatGPT-style)
            if isSidebarOpen {
                Color.black.opacity(0.20)
                    .ignoresSafeArea()
                    .onTapGesture { closeSidebar() }
                    .transition(.opacity)
            }
            
            ChatSidebarView(
                conversationManager: conversationManager,
                isOpen: $isSidebarOpen,
                dragX: $sidebarDragX,
                width: min(340, geometry.size.width * 0.84),
                onSelectConversation: { conversation in
                    conversationManager.loadConversation(conversation)
                    closeSidebar()
                },
                onNewConversation: {
                    conversationManager.newConversation()
                    closeSidebar()
                },
                onOpenSettings: {
                    closeSidebar()
                    presentedSheet = .settings
                }
            )
        }
        .onAppear {
            setupOnAppear()
        }
        .onChange(of: serverAddress) { oldValue, newValue in
            conversationManager.serverAddress = newValue
            UserDefaults.standard.set(newValue, forKey: "serverAddress")
            loadModelsFromServer()
        }
        .onChange(of: systemPrompt) { oldValue, newValue in
            conversationManager.systemPrompt = newValue
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
        .onChange(of: provider) { oldValue, newValue in
            conversationManager.provider = newValue.rawValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "provider")
            updateModelForProvider(newValue)
        }
    }
    
    private func setupOnAppear() {
        conversationManager.newConversation()
        
        if let savedAddress = UserDefaults.standard.string(forKey: "serverAddress") {
            serverAddress = savedAddress
            conversationManager.serverAddress = savedAddress
        }
        
        if let savedModel = UserDefaults.standard.string(forKey: "selectedModel") {
            selectedModel = savedModel
            conversationManager.selectedModel = savedModel
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
        }
        
        updateModelForProvider(provider)
        
        if showKeyboardOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isInputFocused = true
            }
        }
        
        loadModelsFromServer()
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }
    
    private func updateModelForProvider(_ provider: Provider) {
        if provider == .cloud {
            if !cloudModels.contains(selectedModel) {
                selectedModel = cloudModels.first ?? "claude-sonnet-4-5"
                conversationManager.selectedModel = selectedModel
            }
        } else {
            if !availableModels.contains(selectedModel) {
                selectedModel = availableModels.first ?? "gpt-oss:latest"
                conversationManager.selectedModel = selectedModel
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        conversationManager.sendMessage(inputText)
        inputText = ""
        inputTextHeight = 36
    }
    
    private func formatModelName(_ modelName: String) -> String {
        return modelName.replacingOccurrences(of: ":latest", with: "")
    }
    
    private func supportsReasoningEffort(for model: String) -> Bool {
        let modelLower = model.lowercased()
        return modelLower.contains("gpt-oss") || modelLower.contains("gpt-o") || modelLower.contains("gpt-4o") || modelLower.contains("o1") || modelLower.contains("o3")
    }
    
    private func loadModelsFromServer() {
        guard !serverAddress.isEmpty else { return }
        Task {
            do {
                let models = try await NetworkManager.shared.getModels(from: serverAddress)
                await MainActor.run {
                    if !models.isEmpty {
                        self.availableModels = models
                        if !models.contains(selectedModel) {
                            self.selectedModel = models.first ?? "gpt-oss:latest"
                        }
                    }
                }
            } catch {
                print("Failed to load models: \(error.localizedDescription)")
            }
        }
    }
    
    private func openSidebar() {
        withAnimation(.easeOut(duration: 0.22)) {
            isSidebarOpen = true
            sidebarDragX = 0
        }
    }
    
    private func closeSidebar() {
        withAnimation(.easeOut(duration: 0.22)) {
            isSidebarOpen = false
            sidebarDragX = 0
        }
    }
}

struct WelcomeView: View {
    let isServerConfigured: Bool
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(DesignSystem.Colors.accent)
                .padding(.bottom, 6)
            
            Text("Ready")
                .font(DesignSystem.Typography.header())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Text(isServerConfigured ? "Start a conversation." : "Connect to your server to start chatting.")
                .font(DesignSystem.Typography.body())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            if !isServerConfigured {
                Button("Open Settings", systemImage: "link") {
                    onOpenSettings()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.top, 6)
            }
            
            Spacer()
        }
    }
}

// MARK: - Sheet routing

enum PresentedSheet: String, Identifiable {
    case controls
    case settings
    
    var id: String { rawValue }
}

// MARK: - Chat Controls

struct ChatControlsSheetView: View {
    let serverAddress: String
    @Binding var selectedModel: String
    let availableModels: [String]
    @Binding var provider: ChatView.Provider
    @Binding var safetyLevel: ChatView.SafetyLevel
    @Binding var reasoningEffort: ChatView.ReasoningEffort
    let supportsReasoningEffort: Bool
    let onOpenSettings: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                NatureTechBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        DSSectionHeader(title: "Connection")
                            .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Server")
                                        .font(DesignSystem.Typography.caption())
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    
                                    Text(serverAddress.isEmpty ? "Not configured" : serverAddress)
                                        .font(DesignSystem.Typography.body())
                                        .foregroundStyle(serverAddress.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Button("Settings", systemImage: "gearshape") {
                                    dismiss()
                                    onOpenSettings()
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                            }
                            
                            Text("All chat requests are sent to your server. This app does not run models locally.")
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .mattePanel()
                        .padding(.horizontal, 20)
                        
                        DSSectionHeader(title: "Chat")
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            controlsRow(title: "Provider", value: provider.displayName)
                                .overlay(alignment: .trailing) {
                                    Picker("", selection: $provider) {
                                        ForEach(ChatView.Provider.allCases, id: \.self) { option in
                                            Text(option.displayName).tag(option)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                    .frame(width: 190)
                                }
                            
                            Divider().background(DesignSystem.Colors.separator).padding(.leading, 16)
                            
                            controlsRow(title: "Safety", value: safetyLevel.displayName)
                                .overlay(alignment: .trailing) {
                                    Menu {
                                        ForEach(ChatView.SafetyLevel.allCases, id: \.self) { level in
                                            Button {
                                                safetyLevel = level
                                            } label: {
                                                if safetyLevel == level {
                                                    Label(level.displayName, systemImage: "checkmark")
                                                } else {
                                                    Text(level.displayName)
                                                }
                                            }
                                        }
                                    } label: {
                                        Text(safetyLevel.displayName)
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundStyle(DesignSystem.Colors.accent)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(DesignSystem.Colors.surfaceElevated)
                                            .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous)
                                                    .stroke(DesignSystem.Colors.border.opacity(0.75), lineWidth: DesignSystem.Layout.borderWidth)
                                            )
                                    }
                                }
                            
                            if supportsReasoningEffort {
                                Divider().background(DesignSystem.Colors.separator).padding(.leading, 16)
                                
                                controlsRow(title: "Reasoning", value: reasoningEffort.displayName)
                                    .overlay(alignment: .trailing) {
                                        Menu {
                                            ForEach(ChatView.ReasoningEffort.allCases, id: \.self) { effort in
                                                Button {
                                                    reasoningEffort = effort
                                                } label: {
                                                    if reasoningEffort == effort {
                                                        Label(effort.displayName, systemImage: "checkmark")
                                                    } else {
                                                        Text(effort.displayName)
                                                    }
                                                }
                                            }
                                        } label: {
                                            Text(reasoningEffort.displayName)
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(DesignSystem.Colors.surfaceElevated)
                                                .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous)
                                                        .stroke(DesignSystem.Colors.border.opacity(0.75), lineWidth: DesignSystem.Layout.borderWidth)
                                                )
                                        }
                                    }
                            }
                            
                            Divider().background(DesignSystem.Colors.separator).padding(.leading, 16)
                            
                            controlsRow(title: "Model", value: selectedModel)
                                .overlay(alignment: .trailing) {
                                    Menu {
                                        ForEach(availableModels, id: \.self) { model in
                                            Button {
                                                selectedModel = model
                                            } label: {
                                                if selectedModel == model {
                                                    Label(model, systemImage: "checkmark")
                                                } else {
                                                    Text(model)
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(selectedModel.replacingOccurrences(of: ":latest", with: ""))
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundStyle(DesignSystem.Colors.accent)
                                                .lineLimit(1)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(DesignSystem.Colors.surfaceElevated)
                                        .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous)
                                                .stroke(DesignSystem.Colors.border.opacity(0.75), lineWidth: DesignSystem.Layout.borderWidth)
                                        )
                                    }
                                }
                        }
                        .mattePanel()
                        .padding(.horizontal, 20)
                        
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
            }
        }
    }
    
    private func controlsRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.body())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Spacer(minLength: 12)
            Text(value)
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .opacity(0.0001) // keeps layout stable; real value shown in trailing control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Sidebar

private struct ChatSidebarView: View {
    @ObservedObject var conversationManager: ConversationManager
    @Binding var isOpen: Bool
    @Binding var dragX: CGFloat
    let width: CGFloat
    let onSelectConversation: (Conversation) -> Void
    let onNewConversation: () -> Void
    let onOpenSettings: () -> Void
    
    private var offsetX: CGFloat {
        let closedX = -width
        if isOpen {
            return min(0, dragX)
        } else {
            return closedX
        }
    }
    
    private var conversationsForDisplay: [Conversation] {
        // Show the current conversation at the top if it has content.
        var list: [Conversation] = []
        if !conversationManager.currentConversation.messages.isEmpty {
            list.append(conversationManager.currentConversation)
        }
        list.append(contentsOf: conversationManager.conversationHistory)
        return list
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chats")
                    .font(DesignSystem.Typography.title())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button(action: { isOpen = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(DesignSystem.Colors.chrome.opacity(0.98))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(DesignSystem.Colors.separator),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: 10) {
                    Button(action: onNewConversation) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.accent)
                            Text("New chat")
                                .font(DesignSystem.Typography.body().weight(.semibold))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)
                    .mattePanel()
                    
                    Button(action: onOpenSettings) {
                        HStack(spacing: 10) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Text("Settings")
                                .font(DesignSystem.Typography.body())
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)
                    .mattePanel()
                    
                    DSSectionHeader(title: "Recent")
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 8) {
                        ForEach(conversationsForDisplay) { conversation in
                            Button {
                                onSelectConversation(conversation)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(title(for: conversation))
                                        .font(DesignSystem.Typography.body())
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .lineLimit(1)
                                    
                                    Text(conversation.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(DesignSystem.Typography.caption())
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                }
                                .padding(14)
                            }
                            .buttonStyle(.plain)
                            .mattePanel()
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: width)
        .background(DesignSystem.Colors.surface1)
        .overlay(
            Rectangle()
                .frame(width: 0.5)
                .foregroundStyle(DesignSystem.Colors.separator),
            alignment: .trailing
        )
        .offset(x: offsetX)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard isOpen else { return }
                    dragX = min(0, value.translation.width)
                }
                .onEnded { value in
                    guard isOpen else { return }
                    let shouldClose = value.translation.width < -width * 0.25
                    withAnimation(.easeOut(duration: 0.22)) {
                        isOpen = !shouldClose
                        dragX = 0
                    }
                }
        )
        .animation(.easeOut(duration: 0.22), value: isOpen)
        .allowsHitTesting(isOpen || dragX != 0)
    }
    
    private func title(for conversation: Conversation) -> String {
        let first = conversation.messages.first?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if first.isEmpty { return "New chat" }
        return String(first.prefix(60))
    }
}

struct MessagesListView: View {
    let messages: [Message]
    let isLoading: Bool
    @FocusState.Binding var isInputFocused: Bool
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if isLoading && (messages.last?.content.isEmpty ?? true) {
                        ThinkingIndicator()
                            .id("thinking-indicator")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .onTapGesture {
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
    @State private var isThinkingExpanded = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.accentSoft)
                        .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                                .stroke(DesignSystem.Colors.accentStroke, lineWidth: DesignSystem.Layout.borderWidth)
                        )
                        .shadow(color: DesignSystem.Colors.accent.opacity(0.10), radius: 18, x: 0, y: 10)
                }
                .frame(maxWidth: 320, alignment: .trailing)
            } else {
                // AI Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: 24, height: 24)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous)
                            .stroke(DesignSystem.Colors.border.opacity(0.8), lineWidth: DesignSystem.Layout.borderWidth)
                    )
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Thinking Content
                    if let thinkingContent = message.thinkingContent, !thinkingContent.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isThinkingExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "brain")
                                        .font(.system(size: 12))
                                    Text("PROCESS")
                                        .font(DesignSystem.Typography.caption().weight(.semibold))
                                    Spacer()
                                    Image(systemName: isThinkingExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .padding(8)
                                .background(DesignSystem.Colors.surfaceHighlight)
                            }
                            .buttonStyle(.plain)
                            
                            if isThinkingExpanded {
                                Text(thinkingContent)
                                    .font(DesignSystem.Typography.code())
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DesignSystem.Colors.background2)
                            }
                        }
                        .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                .stroke(DesignSystem.Colors.border.opacity(0.75), lineWidth: DesignSystem.Layout.borderWidth)
                        )
                    }
                    
                    // Message Content
                    Text(LocalizedStringKey(message.content))
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineSpacing(4)
                }
                .padding(14)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                        .stroke(DesignSystem.Colors.border.opacity(0.65), lineWidth: DesignSystem.Layout.borderWidth)
                )
            }
        }
    }
}

struct ThinkingIndicator: View {
    @State private var blink = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 24, height: 24)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous)
                        .stroke(DesignSystem.Colors.border.opacity(0.8), lineWidth: DesignSystem.Layout.borderWidth)
                )
            
            Text("PROCESSING...")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.accent)
                .opacity(blink ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: blink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            blink = true
        }
    }
}


#Preview {
    ChatView()
}
