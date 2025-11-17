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
    @Binding var selectedTheme: ChatView.AppTheme
    @Binding var selectedFontStyle: ChatView.FontStyle
    @State private var selectedTab: PersonalizationTab = .aboutMe
    @State private var baseStyle: BaseStyle = .nerdy
    @State private var customInstructions: String = ""
    @State private var nickname: String = ""
    @State private var occupation: String = ""
    @State private var moreAboutYou: String = ""
    @State private var showingStylePicker = false
    @State private var showingPresetPicker = false
    @State private var showingSaveConfirmation = false
    @FocusState private var focusedField: Field?
    
    enum PersonalizationTab: String, CaseIterable {
        case aboutMe = "About Me"
        case experience = "Experience"
    }
    
    enum PresetTheme: String, CaseIterable, Identifiable {
        case darkMode = "Dark Mode"
        case lightMode = "Light Mode"
        case dracula = "Dracula"
        case monokai = "Monokai"
        case solarizedDark = "Solarized Dark"
        case solarizedLight = "Solarized Light"
        case nord = "Nord"
        case gruvbox = "Gruvbox"
        case tokyoNight = "Tokyo Night"
        case oneDark = "One Dark"
        case materialTheme = "Material Theme"
        case nightOwl = "Night Owl"
        case cobalt2 = "Cobalt 2"
        case synthwave = "Synthwave '84"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .darkMode: return "Classic dark interface with high contrast"
            case .lightMode: return "Clean light interface for bright environments"
            case .dracula: return "Dark purple theme with vibrant colors"
            case .monokai: return "Warm dark theme with rich syntax highlighting"
            case .solarizedDark: return "Precision colors for reduced eyestrain"
            case .solarizedLight: return "Light variant with balanced contrast"
            case .nord: return "Arctic, north-bluish color palette"
            case .gruvbox: return "Retro groove with warm earth tones"
            case .tokyoNight: return "Clean dark theme inspired by Tokyo nights"
            case .oneDark: return "Iconic Atom editor dark theme"
            case .materialTheme: return "Google Material Design colors"
            case .nightOwl: return "Fine-tuned for night owls"
            case .cobalt2: return "Dusty blue with vibrant accents"
            case .synthwave: return "Neon-inspired retro cyberpunk theme"
            }
        }
        
        var theme: ChatView.AppTheme {
            switch self {
            case .darkMode: return .midnight
            case .lightMode: return .arctic
            case .dracula: return .midnight
            case .monokai: return .crimson
            case .solarizedDark: return .ocean
            case .solarizedLight: return .arctic
            case .nord: return .ocean
            case .gruvbox: return .sunset
            case .tokyoNight: return .midnight
            case .oneDark: return .midnight
            case .materialTheme: return .ocean
            case .nightOwl: return .midnight
            case .cobalt2: return .ocean
            case .synthwave: return .lavender
            }
        }
        
        var font: ChatView.FontStyle {
            switch self {
            case .darkMode: return .system
            case .lightMode: return .system
            case .dracula: return .rounded
            case .monokai: return .monospaced
            case .solarizedDark: return .serif
            case .solarizedLight: return .serif
            case .nord: return .system
            case .gruvbox: return .rounded
            case .tokyoNight: return .rounded
            case .oneDark: return .monospaced
            case .materialTheme: return .system
            case .nightOwl: return .rounded
            case .cobalt2: return .monospaced
            case .synthwave: return .rounded
            }
        }
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
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("Personalization")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: savePersonalization) {
                        Text("Save")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(hasChanges ? .white : .gray)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                hasChanges ? Color.white.opacity(0.15) : Color.clear
                            )
                            .cornerRadius(20)
                    }
                    .disabled(!hasChanges)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                // Tab Selector
                HStack(spacing: 0) {
                    ForEach(PersonalizationTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            VStack(spacing: 8) {
                                Text(tab.rawValue)
                                    .font(.body)
                                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                                    .foregroundColor(selectedTab == tab ? .white : .gray)
                                
                                Rectangle()
                                    .fill(selectedTab == tab ? Color.white : Color.clear)
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 20)
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
        .sheet(isPresented: $showingPresetPicker) {
            PresetThemePickerSheet(
                selectedTheme: $selectedTheme,
                selectedFontStyle: $selectedFontStyle,
                isPresented: $showingPresetPicker
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var aboutMeContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Base style and tone
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Base style and tone")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Button(action: { showingStylePicker = true }) {
                                HStack {
                                    Text(baseStyle.rawValue)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            Text("Set the style and tone ChatGPT uses when responding.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        
                        // Custom instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom instructions")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ZStack(alignment: .topLeading) {
                                if customInstructions.isEmpty {
                                    Text("Take a forward-thinking view. Be innovative and think outside the box. Readily share strong opinions. Be practical above all. Always explain and articulate well, don't be too succinct. Always use your memory to get context for conversations")
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                
                                TextEditor(text: $customInstructions)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 150)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .focused($focusedField, equals: .customInstructions)
                            }
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            
                            // Personality trait chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(personalityTraits, id: \.self) { trait in
                                        Text(trait)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.15))
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Your nickname
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your nickname")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("Zay", text: $nickname)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .focused($focusedField, equals: .nickname)
                        }
                        .padding(.horizontal, 20)
                        
                        // Your occupation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your occupation")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("Engineer, student, etc.", text: $occupation)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .focused($focusedField, equals: .occupation)
                        }
                        .padding(.horizontal, 20)
                        
                        // More about you
                        VStack(alignment: .leading, spacing: 8) {
                            Text("More about you")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ZStack(alignment: .topLeading) {
                                if moreAboutYou.isEmpty {
                                    Text("I like writing code, I use Python. I am interested in building cool projects.")
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                
                                TextEditor(text: $moreAboutYou)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 100)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .focused($focusedField, equals: .moreAboutYou)
                            }
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Memory section
                        Button(action: {}) {
                            HStack(spacing: 12) {
                                Image(systemName: "book.pages")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                
                                Text("Memory")
                                    .font(.body)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
        }
        .padding(.top, 20)
    }
    
    private var experienceContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Pre-configured Themes Dropdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Pre-configured Themes")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                Button(action: { showingPresetPicker = true }) {
                    HStack {
                        Text("Choose a preset theme")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                
                Text("Popular color and font combinations")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.horizontal, 20)
            
            // Custom Theme Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom Theme")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                Text("Build your own color palette")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ThemeCardButton(name: "Ocean", colors: [Color(red: 0.2, green: 0.4, blue: 0.35), Color(red: 0.15, green: 0.45, blue: 0.5)], description: "Calm teal and blue", isSelected: selectedTheme == .ocean, action: { selectedTheme = .ocean })
                        ThemeCardButton(name: "Sunset", colors: [Color(red: 0.95, green: 0.4, blue: 0.3), Color(red: 0.95, green: 0.65, blue: 0.3)], description: "Warm orange tones", isSelected: selectedTheme == .sunset, action: { selectedTheme = .sunset })
                        ThemeCardButton(name: "Forest", colors: [Color(red: 0.15, green: 0.35, blue: 0.2), Color(red: 0.25, green: 0.45, blue: 0.25)], description: "Natural green hues", isSelected: selectedTheme == .forest, action: { selectedTheme = .forest })
                        ThemeCardButton(name: "Midnight", colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.3)], description: "Deep blue night", isSelected: selectedTheme == .midnight, action: { selectedTheme = .midnight })
                        ThemeCardButton(name: "Lavender", colors: [Color(red: 0.4, green: 0.3, blue: 0.5), Color(red: 0.5, green: 0.4, blue: 0.6)], description: "Soft purple shades", isSelected: selectedTheme == .lavender, action: { selectedTheme = .lavender })
                        ThemeCardButton(name: "Crimson", colors: [Color(red: 0.5, green: 0.15, blue: 0.2), Color(red: 0.6, green: 0.2, blue: 0.3)], description: "Bold red burgundy", isSelected: selectedTheme == .crimson, action: { selectedTheme = .crimson })
                        ThemeCardButton(name: "Coral", colors: [Color(red: 0.95, green: 0.5, blue: 0.45), Color(red: 0.95, green: 0.7, blue: 0.5)], description: "Vibrant coral peach", isSelected: selectedTheme == .coral, action: { selectedTheme = .coral })
                        ThemeCardButton(name: "Arctic", colors: [Color(red: 0.7, green: 0.85, blue: 0.9), Color(red: 0.8, green: 0.9, blue: 0.95)], description: "Cool light blue", isSelected: selectedTheme == .arctic, action: { selectedTheme = .arctic })
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Font Style Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Font Style")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                Text("Select a typography style for the interface")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    FontStyleCardButton(name: "System", description: "Default iOS font", isSelected: selectedFontStyle == .system, fontStyle: .system, action: { selectedFontStyle = .system })
                    FontStyleCardButton(name: "Rounded", description: "Friendly rounded font", isSelected: selectedFontStyle == .rounded, fontStyle: .rounded, action: { selectedFontStyle = .rounded })
                    FontStyleCardButton(name: "Serif", description: "Classic serif font", isSelected: selectedFontStyle == .serif, fontStyle: .serif, action: { selectedFontStyle = .serif })
                    FontStyleCardButton(name: "Monospaced", description: "Code-style monospaced", isSelected: selectedFontStyle == .monospaced, fontStyle: .monospaced, action: { selectedFontStyle = .monospaced })
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .padding(.top, 20)
    }
    
    private var hasChanges: Bool {
        true // Simplified for now
    }
    
    private func loadPersonalization() {
        // Parse existing system prompt if available
        customInstructions = systemPrompt
    }
    
    private func savePersonalization() {
        // Construct system prompt from all fields
        var prompt = ""
        
        if !baseStyle.rawValue.isEmpty {
            prompt += "Style: \(baseStyle.rawValue) - \(baseStyle.description)\n\n"
        }
        
        if !customInstructions.isEmpty {
            prompt += "Instructions: \(customInstructions)\n\n"
        }
        
        if !nickname.isEmpty {
            prompt += "User's nickname: \(nickname)\n"
        }
        
        if !occupation.isEmpty {
            prompt += "User's occupation: \(occupation)\n"
        }
        
        if !moreAboutYou.isEmpty {
            prompt += "More about user: \(moreAboutYou)\n"
        }
        
        systemPrompt = prompt
        showingSaveConfirmation = true
    }
}

struct PresetThemePickerSheet: View {
    @Binding var selectedTheme: ChatView.AppTheme
    @Binding var selectedFontStyle: ChatView.FontStyle
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(PersonalizationView.PresetTheme.allCases) { preset in
                            Button(action: {
                                selectedTheme = preset.theme
                                selectedFontStyle = preset.font
                                isPresented = false
                            }) {
                                HStack(spacing: 16) {
                                    // Theme preview circle
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: preset.theme.colors,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 50, height: 50)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.rawValue)
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Text(preset.description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedTheme == preset.theme && selectedFontStyle == preset.font {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .contentShape(Rectangle())
                            }
                            
                            if preset != PersonalizationView.PresetTheme.allCases.last {
                                Divider()
                                    .padding(.leading, 86)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Pre-configured Themes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ThemeCardButton: View {
    let name: String
    let colors: [Color]
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Theme Preview
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 120, height: 120)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
                )
                
                VStack(spacing: 4) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 120)
            }
        }
    }
}

struct FontStyleCardButton: View {
    let name: String
    let description: String
    let isSelected: Bool
    let fontStyle: ChatView.FontStyle
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(fontStyle.apply(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.white.opacity(isSelected ? 0.1 : 0.05))
            .cornerRadius(12)
        }
    }
}

struct StylePickerSheet: View {
    @Binding var selectedStyle: PersonalizationView.BaseStyle
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
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
                                            .font(.body)
                                            .fontWeight(.regular)
                                            .foregroundColor(.primary)
                                        Text(style.description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedStyle == style {
                                        Image(systemName: "checkmark")
                                            .font(.body)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .contentShape(Rectangle())
                            }
                            
                            if style != PersonalizationView.BaseStyle.allCases.last {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Base style and tone")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

