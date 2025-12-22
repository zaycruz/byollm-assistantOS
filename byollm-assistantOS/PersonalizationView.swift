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
    
    @State private var fullName: String = ""
    @State private var nickname: String = ""
    @State private var personalPreferences: String = ""
    @State private var showingSaveConfirmation = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case fullName, nickname, personalPreferences
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .onTapGesture {
                    focusedField = nil
                }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Profile")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer for centering
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 30)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Full Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            TextField("Enter your name", text: $fullName)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .focused($focusedField, equals: .fullName)
                        }
                        
                        // Nickname
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nickname")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            TextField("Enter your nickname", text: $nickname)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .focused($focusedField, equals: .nickname)
                        }
                        
                        // Update Profile Button
                        Button(action: saveProfile) {
                            Text("Update Profile")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 8)
                        
                        // Personal Preferences
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Personal Preferences")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            ZStack(alignment: .topLeading) {
                                if personalPreferences.isEmpty {
                                    Text("Tell us about your preferences...")
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                
                                TextEditor(text: $personalPreferences)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 120)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .focused($focusedField, equals: .personalPreferences)
                            }
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            
                            Text("Your preferences will apply to all conversations.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Save Preferences Button
                        Button(action: savePreferences) {
                            Text("Save Preferences")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            loadPersonalization()
        }
        .alert("Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your settings have been saved.")
        }
    }
    
    private func loadPersonalization() {
        let settings = PersonalizationStore().load()
        fullName = settings.fullName
        nickname = settings.nickname
        personalPreferences = settings.personalPreferences
        systemPrompt = settings.systemPrompt()
    }
    
    private func saveProfile() {
        let settings = PersonalizationSettings(
            fullName: fullName,
            nickname: nickname,
            personalPreferences: personalPreferences
        )
        PersonalizationStore().save(settings)
        systemPrompt = settings.systemPrompt()
        showingSaveConfirmation = true
    }
    
    private func savePreferences() {
        let settings = PersonalizationSettings(
            fullName: fullName,
            nickname: nickname,
            personalPreferences: personalPreferences
        )
        PersonalizationStore().save(settings)
        systemPrompt = settings.systemPrompt()
        showingSaveConfirmation = true
    }
}
