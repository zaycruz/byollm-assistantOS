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
    @Binding var safetyLevel: ChatView.SafetyLevel
    @Binding var provider: ChatView.Provider
    @AppStorage("appAppearance") private var appAppearanceRaw: String = AppAppearance.system.rawValue
    @State private var showingDeleteAlert = false
    @State private var showingPersonalization = false
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
            case .disconnected: return DesignSystem.Colors.textTertiary
            case .connecting: return DesignSystem.Colors.warning
            case .connected: return DesignSystem.Colors.success
            case .failed: return DesignSystem.Colors.error
            }
        }
        
        var text: String {
            switch self {
            case .disconnected: return "OFFLINE"
            case .connecting: return "CONNECTING..."
            case .connected: return "CONNECTED"
            case .failed: return "FAILED"
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
        NavigationStack {
            ZStack {
                NatureTechBackground().ignoresSafeArea()
                    .onTapGesture {
                        isServerFieldFocused = false
                    }
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        if isInSidePanel {
                            Button(action: { onBack?() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        
                        Text("Settings")
                            .font(DesignSystem.Typography.body().weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                            if isInSidePanel {
                                onDismiss?()
                            } else {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .frame(width: 44, height: 44)
                        }
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
                    VStack(spacing: 32) {
                        // Server Connection Section
                        VStack(alignment: .leading, spacing: 10) {
                            DSSectionHeader(title: "Connection")
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Server Address Field
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Server address")
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        
                                        TextField("e.g. 192.168.1.100:8080", text: $editingServerAddress)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .font(DesignSystem.Typography.body())
                                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                                            .padding(12)
                                            .background(DesignSystem.Colors.surfaceElevated)
                                            .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                                                    .stroke(isServerFieldFocused ? DesignSystem.Colors.accent : DesignSystem.Colors.border.opacity(0.8), lineWidth: 1)
                                            )
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
                                                if connectionStatus == .connected {
                                                    connectionStatus = .disconnected
                                                }
                                            }
                                    }
                                    
                                    // Connection Status & Test Button
                                    HStack(spacing: 12) {
                                        // Status Indicator
                                        HStack(spacing: 8) {
                                            Image(systemName: connectionStatus.icon)
                                                .font(.system(size: 12))
                                                .foregroundColor(connectionStatus.color)
                                            
                                            Text(connectionStatus.text)
                                                .font(DesignSystem.Typography.code())
                                                .foregroundColor(connectionStatus.color)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        // Test Connection Button
                                        Button(action: testConnection) {
                                            HStack(spacing: 6) {
                                                if isTestingConnection {
                                                    ProgressView()
                                                        .scaleEffect(0.6)
                                                        .tint(DesignSystem.Colors.textPrimary)
                                                } else {
                                                    Image(systemName: "bolt.fill")
                                                        .font(.system(size: 12))
                                                }
                                                Text("Test")
                                                    .font(DesignSystem.Typography.code())
                                                    .fontWeight(.bold)
                                            }
                                            .foregroundColor(DesignSystem.Colors.surface)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                editingServerAddress.isEmpty ? DesignSystem.Colors.surfaceElevated : DesignSystem.Colors.accent
                                            )
                                            .cornerRadius(4)
                                        }
                                        .disabled(editingServerAddress.isEmpty || isTestingConnection)
                                    }
                                    
                                    
                                    Text("All chat requests are sent to your server. The app does not run models locally.")
                                        .font(DesignSystem.Typography.caption())
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                                .padding(16)
                            }
                            .mattePanel()
                            .padding(.horizontal, 20)
                        }
                        
                        // Backend Section
                        VStack(alignment: .leading, spacing: 12) {
                            DSSectionHeader(title: "Backend")
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                // Provider routing (server-side)
                                HStack(spacing: 16) {
                                    Image(systemName: "point.3.connected.trianglepath.dotted")
                                        .font(.system(size: 18))
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        .frame(width: 24)
                                    
                                    Text("Provider")
                                        .font(DesignSystem.Typography.body())
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $provider) {
                                        ForEach(ChatView.Provider.allCases, id: \.self) { providerOption in
                                            Text(providerOption.displayName).tag(providerOption)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 200)
                                }
                                .padding(16)
                                
                                Divider().background(DesignSystem.Colors.separator).padding(.leading, 56)
                                
                                // Safety Level
                                HStack(spacing: 16) {
                                    Image(systemName: "shield.lefthalf.filled")
                                        .font(.system(size: 18))
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        .frame(width: 24)
                                    
                                    Text("Safety Protocols")
                                        .font(DesignSystem.Typography.body())
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    
                                    Spacer()
                                    
                                    Menu {
                                        ForEach(ChatView.SafetyLevel.allCases, id: \.self) { level in
                                            Button(action: {
                                                safetyLevel = level
                                            }) {
                                                HStack {
                                                    Text(level.displayName)
                                                    if safetyLevel == level {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(safetyLevel.displayName)
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundStyle(DesignSystem.Colors.accent)
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 10))
                                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(DesignSystem.Colors.surfaceElevated)
                                        .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous)
                                                .stroke(DesignSystem.Colors.border.opacity(0.75), lineWidth: DesignSystem.Layout.borderWidth)
                                        )
                                    }
                                }
                                .padding(16)
                            }
                            .mattePanel()
                            .padding(.horizontal, 20)
                        }
                        
                        // Experience Section
                        VStack(alignment: .leading, spacing: 12) {
                            DSSectionHeader(title: "Experience")
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                // Appearance
                                HStack(spacing: 16) {
                                    Image(systemName: "circle.lefthalf.filled")
                                        .font(.system(size: 18))
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        .frame(width: 24)
                                    
                                    Text("Appearance")
                                        .font(DesignSystem.Typography.body())
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $appAppearanceRaw) {
                                        ForEach(AppAppearance.allCases) { option in
                                            Text(option.title).tag(option.rawValue)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                    .frame(width: 220)
                                }
                                .padding(16)
                                
                                Divider().background(DesignSystem.Colors.separator).padding(.leading, 56)
                                
                                Button(action: { showingPersonalization = true }) {
                                    SettingsRow(
                                        icon: "slider.horizontal.3",
                                        title: "Personalization",
                                        showChevron: true
                                    )
                                }
                                
                                Divider().background(DesignSystem.Colors.separator).padding(.leading, 56)
                                
                                SettingsToggleRow(
                                    icon: "keyboard",
                                    title: "Auto-Keyboard",
                                    isOn: $showKeyboardOnLaunch
                                )
                            }
                            .mattePanel()
                            .padding(.horizontal, 20)
                        }
                        
                        // Data Section
                        VStack(alignment: .leading, spacing: 12) {
                            DSSectionHeader(title: "Data")
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                Button(action: { showingDeleteAlert = true }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 18))
                                            .foregroundStyle(DesignSystem.Colors.error)
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Purge Chat History")
                                                .font(DesignSystem.Typography.body())
                                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                            Text("Deletes all conversations stored on this device.")
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(16)
                                }
                                .buttonStyle(.plain)
                            }
                            .mattePanel()
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .alert("Purge History", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Execute Purge", role: .destructive) {
                conversationManager.deleteHistory()
            }
        } message: {
            Text("All conversation data will be permanently deleted. This action cannot be undone.")
        }
        .onAppear {
            if editingServerAddress.isEmpty {
                editingServerAddress = serverAddress
            }
        }
        .fullScreenCover(isPresented: $showingPersonalization) {
            PersonalizationView(
                systemPrompt: $systemPrompt
            )
        }
        .navigationBarHidden(true)
        }
    }
    
    private func testConnection() {
        guard !editingServerAddress.isEmpty else { return }
        
        isTestingConnection = true
        connectionStatus = .connecting
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
                .font(.system(size: 18))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 24)
            
            Text(title)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(16)
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
                .font(.system(size: 18))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 24)
            
            Text(title)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DesignSystem.Colors.accent)
        }
        .padding(16)
    }
}
