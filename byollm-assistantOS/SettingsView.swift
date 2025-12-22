//
//  SettingsView.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
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
    @State private var showingDeleteAlert = false
    @State private var isLoadingModels = false
    @State private var showingPersonalization = false
    @State private var showingMemories = false
    @State private var editingServerAddress: String = ""
    @State private var connectionStatus: ConnectionStatus = .disconnected
    @State private var isTestingConnection = false
    @FocusState private var isServerFieldFocused: Bool
    
    // Side panel mode
    var isInSidePanel: Bool = false
    var onBack: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case failed
        
        var color: Color {
            switch self {
            case .disconnected: return .gray
            case .connecting: return .yellow
            case .connected: return .green
            case .failed: return .red
            }
        }
        
        var text: String {
            switch self {
            case .disconnected: return "Not Connected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .failed: return "Connection Failed"
            }
        }
        
        var icon: String {
            switch self {
            case .disconnected: return "circle"
            case .connecting: return "circle.dotted"
            case .connected: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                    .onTapGesture {
                        isServerFieldFocused = false
                    }
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        if isInSidePanel {
                            Button(action: { onBack?() }) {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        } else {
                            // Invisible spacer to balance the X button
                            Color.clear
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                        
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: { 
                            if isInSidePanel {
                                onDismiss?()
                            } else {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Server Connection Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Server Connection")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                            
                            VStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Server Address Field
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 16) {
                                            Image(systemName: "network")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .frame(width: 24)
                                            
                                            Text("Server Address")
                                                .foregroundColor(.white)
                                                .font(.body)
                                            
                                            Spacer()
                                        }
                                        
                                        TextField("Enter IP address (e.g., 192.168.1.100:8080)", text: $editingServerAddress)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(10)
                                            .focused($isServerFieldFocused)
                                            .keyboardType(.URL)
                                            .autocapitalization(.none)
                                            .autocorrectionDisabled()
                                            .submitLabel(.done)
                                            .onSubmit {
                                                isServerFieldFocused = false
                                            }
                                            .onChange(of: editingServerAddress) { oldValue, newValue in
                                                serverAddress = newValue
                                                // Reset connection status when address changes
                                                if connectionStatus == .connected {
                                                    connectionStatus = .disconnected
                                                }
                                            }
                                            .toolbar {
                                                ToolbarItemGroup(placement: .keyboard) {
                                                    Spacer()
                                                    Button("Done") {
                                                        isServerFieldFocused = false
                                                    }
                                                    .foregroundColor(.blue)
                                                }
                                            }
                                    }
                                    
                                    // Connection Status & Test Button
                                    HStack(spacing: 12) {
                                        // Status Indicator
                                        HStack(spacing: 8) {
                                            Image(systemName: connectionStatus.icon)
                                                .font(.body)
                                                .foregroundColor(connectionStatus.color)
                                            
                                            Text(connectionStatus.text)
                                                .font(.subheadline)
                                                .foregroundColor(connectionStatus.color)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        // Test Connection Button
                                        Button(action: testConnection) {
                                            HStack(spacing: 6) {
                                                if isTestingConnection {
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                        .tint(.white)
                                                } else {
                                                    Image(systemName: "bolt.fill")
                                                        .font(.subheadline)
                                                }
                                                Text("Test")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                LinearGradient(
                                                    colors: selectedTheme.colors,
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(10)
                                        }
                                        .disabled(editingServerAddress.isEmpty || isTestingConnection)
                                        .opacity(editingServerAddress.isEmpty ? 0.5 : 1.0)
                                    }
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                    
                                    // Model Provider Picker (Local/Cloud)
                                    HStack(spacing: 16) {
                                        Image(systemName: provider == .local ? "server.rack" : "cloud")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .frame(width: 24)
                                        
                                        Text("Model Provider")
                                            .foregroundColor(.white)
                                            .font(.body)
                                        
                                        Spacer()
                                        
                                        Picker("", selection: $provider) {
                                            ForEach(ChatView.Provider.allCases, id: \.self) { providerOption in
                                                Text(providerOption.displayName).tag(providerOption)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 140)
                                    }
                                    
                                    // Provider description
                                    Text(provider == .local ? "Uses local models (Ollama/vLLM)" : "Uses cloud models (Anthropic)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.leading, 40)
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                    
                                    // Model Selector
                                    HStack(spacing: 16) {
                                        Image(systemName: "cpu")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .frame(width: 24)
                                        
                                        Text("Model")
                                            .foregroundColor(.white)
                                            .font(.body)
                                        
                                        Spacer()
                                        
                                        // Refresh button
                                        Button(action: refreshModels) {
                                            if isLoadingModels {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .tint(.white.opacity(0.7))
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.subheadline)
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        }
                                        .frame(width: 28, height: 28)
                                        .disabled(isLoadingModels || editingServerAddress.isEmpty)
                                        
                                        Menu {
                                            ForEach(currentModels, id: \.self) { model in
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
                                                    .foregroundColor(.white.opacity(0.7))
                                                    .font(.body)
                                                    .lineLimit(1)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                        }
                                    }
                                    
                                    // Model description
                                    Text("Tap refresh to fetch models from server")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.leading, 40)
                                    
                                    // Reasoning Effort Picker (only for GPT-oss models)
                                    if supportsReasoningEffort {
                                        Divider()
                                            .background(Color.white.opacity(0.2))
                                        
                                        HStack(spacing: 16) {
                                            Image(systemName: "brain.head.profile")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .frame(width: 24)
                                            
                                            Text("Reasoning Effort")
                                                .foregroundColor(.white)
                                                .font(.body)
                                            
                                            Spacer()
                                            
                                            Menu {
                                                ForEach(ChatView.ReasoningEffort.allCases, id: \.self) { effort in
                                                    Button(action: {
                                                        reasoningEffort = effort
                                                    }) {
                                                        HStack {
                                                            Text(effort.rawValue.capitalized)
                                                            if reasoningEffort == effort {
                                                                Image(systemName: "checkmark")
                                                            }
                                                        }
                                                    }
                                                }
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Text(reasoningEffort.rawValue.capitalized)
                                                        .foregroundColor(.white.opacity(0.7))
                                                        .font(.body)
                                                    Image(systemName: "chevron.up.chevron.down")
                                                        .font(.caption2)
                                                        .foregroundColor(.white.opacity(0.5))
                                                }
                                            }
                                        }
                                        
                                        Text("Controls depth of model reasoning (low/medium/high)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(.leading, 40)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        }
                        
                        // App Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("App")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                            
                            VStack(spacing: 0) {
                                Button(action: { showingPersonalization = true }) {
                                    SettingsRow(
                                        icon: "person.circle",
                                        title: "Personalization",
                                        showChevron: true
                                    )
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 70)
                                
                                SettingsToggleRow(
                                    icon: "keyboard",
                                    title: "Show keyboard on launch",
                                    isOn: $showKeyboardOnLaunch
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 70)
                                
                                // Memories
                                Button(action: { showingMemories = true }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "brain.head.profile")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .frame(width: 24)
                                        
                                        Text("Memories")
                                            .foregroundColor(.white)
                                            .font(.body)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 70)
                                
                                Button(action: { showingDeleteAlert = true }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "trash")
                                            .font(.title3)
                                            .foregroundColor(.red)
                                            .frame(width: 24)
                                        
                                        Text("Delete conversation history")
                                            .foregroundColor(.red)
                                            .font(.body)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .alert("Delete Conversation History", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                conversationManager.deleteHistory()
            }
        } message: {
            Text("Are you sure you want to delete all conversation history? This action cannot be undone.")
        }
        .onAppear {
            // Initialize editing field with current value
            if editingServerAddress.isEmpty {
                editingServerAddress = serverAddress
            }
        }
        .fullScreenCover(isPresented: $showingPersonalization) {
            PersonalizationView(
                systemPrompt: $systemPrompt,
                selectedTheme: $selectedTheme,
                selectedFontStyle: $selectedFontStyle
            )
        }
        .fullScreenCover(isPresented: $showingMemories) {
            MemoriesView()
        }
        .navigationBarHidden(true)
        }
    }
    
    private var currentModels: [String] {
        provider == .cloud ? cloudModels : availableModels
    }
    
    private var supportsReasoningEffort: Bool {
        let modelLower = selectedModel.lowercased()
        return modelLower.contains("gpt-oss") || 
               modelLower.contains("gpt-o") || 
               modelLower.contains("gpt-4o") || 
               modelLower.contains("o1") || 
               modelLower.contains("o3")
    }
    
    private func formatModelName(_ modelName: String) -> String {
        modelName.replacingOccurrences(of: ":latest", with: "")
    }
    
    private func refreshModels() {
        guard !editingServerAddress.isEmpty else { return }
        
        isLoadingModels = true
        
        Task {
            do {
                let models = try await NetworkManager.shared.getModels(from: editingServerAddress)
                
                await MainActor.run {
                    isLoadingModels = false
                    if !models.isEmpty {
                        availableModels = models
                        if !models.contains(selectedModel) {
                            selectedModel = models.first ?? selectedModel
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingModels = false
                }
            }
        }
    }
    
    private func testConnection() {
        guard !editingServerAddress.isEmpty else { return }
        
        isTestingConnection = true
        connectionStatus = .connecting
        
        // Dismiss keyboard
        isServerFieldFocused = false
        
        Task {
            do {
                let success = try await NetworkManager.shared.testConnection(to: editingServerAddress)
                
                await MainActor.run {
                    isTestingConnection = false
                    connectionStatus = success ? .connected : .failed
                }
            } catch {
                await MainActor.run {
                    isTestingConnection = false
                    connectionStatus = .failed
                }
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let showChevron: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.white)
                .font(.body)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.white)
                .font(.body)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

