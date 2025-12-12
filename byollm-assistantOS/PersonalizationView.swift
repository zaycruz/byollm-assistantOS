//
//  PersonalizationView.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import SwiftUI

struct PersonalizationView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var systemPrompt: String
    @State private var selectedTab: PersonalizationTab = .aboutMe
    @State private var baseStyle: BaseStyle = .nerdy
    @State private var customInstructions: String = ""
    @State private var nickname: String = ""
    @State private var occupation: String = ""
    @State private var moreAboutYou: String = ""
    @State private var showingStylePicker = false
    @State private var showingSaveConfirmation = false
    @FocusState private var focusedField: Field?
    
    enum PersonalizationTab: String, CaseIterable {
        case aboutMe = "About Me"
        case experience = "Experience"
    }
    
    enum Field: Hashable {
        case customInstructions, nickname, occupation, moreAboutYou
    }
    
    enum BaseStyle: String, CaseIterable, Identifiable {
        case defaultStyle = "Default"
        case professional = "Professional"
        case friendly = "Friendly"
        case candid = "Candid"
        case quirky = "Quirky"
        case efficient = "Efficient"
        case nerdy = "Nerdy"
        case cynical = "Cynical"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .defaultStyle: return "Balanced style and tone"
            case .professional: return "Polished and precise"
            case .friendly: return "Warm and chatty"
            case .candid: return "Direct and encouraging"
            case .quirky: return "Playful and imaginative"
            case .efficient: return "Concise and plain"
            case .nerdy: return "Exploratory and enthusiastic"
            case .cynical: return "Critical and sarcastic"
            }
        }
    }
    
    let personalityTraits = ["Chatty", "Witty", "Straight shooting", "Encouraging", "Generous"]
    
    var body: some View {
        ZStack {
            NatureTechBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("Personalization")
                        .font(DesignSystem.Typography.header())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: savePersonalization) {
                        Text("SAVE")
                            .font(DesignSystem.Typography.code())
                            .fontWeight(.bold)
                            .foregroundColor(hasChanges ? DesignSystem.Colors.surface : DesignSystem.Colors.textTertiary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                hasChanges ? DesignSystem.Colors.accent : DesignSystem.Colors.surfaceHighlight
                            )
                            .cornerRadius(4)
                    }
                    .disabled(!hasChanges)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 0.5).foregroundStyle(DesignSystem.Colors.separator), alignment: .bottom)
                
                // Tab Selector
                HStack(spacing: 0) {
                    ForEach(PersonalizationTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            VStack(spacing: 8) {
                                Text(tab.rawValue.uppercased())
                                    .font(DesignSystem.Typography.caption())
                                    .fontWeight(selectedTab == tab ? .bold : .regular)
                                    .foregroundColor(selectedTab == tab ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                                
                                Rectangle()
                                    .fill(selectedTab == tab ? DesignSystem.Colors.accent : Color.clear)
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                ScrollView {
                    if selectedTab == .aboutMe {
                        aboutMeContent
                    } else {
                        experienceContent
                    }
                }
            }
        }
        .onAppear {
            loadPersonalization()
        }
        .alert("Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Your personalization settings have been saved.")
        }
        .sheet(isPresented: $showingStylePicker) {
            StylePickerSheet(selectedStyle: $baseStyle, isPresented: $showingStylePicker)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var aboutMeContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Base style and tone
            VStack(alignment: .leading, spacing: 8) {
                Text("BASE STYLE")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Button(action: { showingStylePicker = true }) {
                    HStack {
                        Text(baseStyle.rawValue)
                            .font(DesignSystem.Typography.body())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .padding()
                    .background(DesignSystem.Colors.surfaceHighlight)
                    .cornerRadius(DesignSystem.Layout.cornerRadius)
                }
                
                Text("Set the style and tone ChatGPT uses when responding.")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            
            // Custom instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("CUSTOM INSTRUCTIONS")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                ZStack(alignment: .topLeading) {
                    if customInstructions.isEmpty {
                        Text("Be innovative. Share strong opinions. Be practical.")
                            .font(DesignSystem.Typography.body())
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: $customInstructions)
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(height: 150)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .focused($focusedField, equals: .customInstructions)
                }
                .background(DesignSystem.Colors.surfaceHighlight)
                .cornerRadius(DesignSystem.Layout.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                        .stroke(focusedField == .customInstructions ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            
            // Your nickname
            VStack(alignment: .leading, spacing: 8) {
                Text("NICKNAME")
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                TextField("Zay", text: $nickname)
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding()
                    .background(DesignSystem.Colors.surfaceHighlight)
                    .cornerRadius(DesignSystem.Layout.cornerRadius)
                    .focused($focusedField, equals: .nickname)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                            .stroke(focusedField == .nickname ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }
    
    private var experienceContent: some View {
        VStack(alignment: .leading, spacing: 32) {
        }
        .padding(.top, 20)
    }
    
    private var hasChanges: Bool {
        true
    }
    
    private func loadPersonalization() {
        customInstructions = systemPrompt
        nickname = UserDefaults.standard.string(forKey: "userProfile.name") ?? ""
        occupation = UserDefaults.standard.string(forKey: "userProfile.occupation") ?? ""
        moreAboutYou = UserDefaults.standard.string(forKey: "userProfile.about") ?? ""
    }
    
    private func savePersonalization() {
        // Persist user profile separately so it can be appended to the prompt at send-time.
        UserDefaults.standard.set(nickname.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "userProfile.name")
        UserDefaults.standard.set(occupation.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "userProfile.occupation")
        UserDefaults.standard.set(moreAboutYou.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "userProfile.about")
        
        // Keep the system prompt focused on instructions and style.
        var promptParts: [String] = []
        if !baseStyle.rawValue.isEmpty {
            promptParts.append("Style: \(baseStyle.rawValue) - \(baseStyle.description)")
        }
        let instructions = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !instructions.isEmpty {
            promptParts.append(instructions)
        }
        systemPrompt = promptParts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        showingSaveConfirmation = true
    }
}

struct ThemeCardButton: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? DesignSystem.Colors.textPrimary.opacity(0.9) : Color.clear, lineWidth: 3)
                    )
                
                Text(name)
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
            }
        }
    }
}

struct StylePickerSheet: View {
    @Binding var selectedStyle: PersonalizationView.BaseStyle
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                NatureTechBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(PersonalizationView.BaseStyle.allCases) { style in
                            Button(action: {
                                selectedStyle = style
                                isPresented = false
                            }) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(style.rawValue)
                                            .font(DesignSystem.Typography.body())
                                            .foregroundColor(DesignSystem.Colors.textPrimary)
                                        Text(style.description)
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundColor(DesignSystem.Colors.textTertiary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedStyle == style {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(DesignSystem.Colors.accent)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .contentShape(Rectangle())
                            }
                            
                            if style != PersonalizationView.BaseStyle.allCases.last {
                                Divider().background(DesignSystem.Colors.border).padding(.leading, 20)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Style & Tone")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
