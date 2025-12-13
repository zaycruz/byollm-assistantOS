//
//  ManageModelsView.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import SwiftUI

struct ManageModelsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            NatureTechBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("Models")
                        .font(DesignSystem.Typography.header())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    // Invisible spacer for centering
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(DesignSystem.Colors.separator),
                    alignment: .bottom
                )
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Ollama Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                DSSectionHeader(title: "Ollama")
                                
                                Spacer()
                                
                                Button(action: {
                                    // Add model action
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(DesignSystem.Colors.accent)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ModelCard(
                                    icon: "🦙",
                                    backgroundColor: Color(red: 0.0, green: 0.0, blue: 0.0),
                                    name: "Llama 3.2",
                                    description: "Meta's latest language model. Excels at conversational AI, content generation, and reasoning tasks.",
                                    modelsCount: "3 models",
                                    badges: []
                                )
                                
                                ModelCard(
                                    icon: "💎",
                                    backgroundColor: Color(red: 0.1, green: 0.1, blue: 0.2),
                                    name: "Qwen 2.5",
                                    description: "Advanced multilingual model by Alibaba. Strong performance in code generation and mathematical reasoning.",
                                    modelsCount: "5 models",
                                    badges: []
                                )
                                
                                ModelCard(
                                    icon: "⚡",
                                    backgroundColor: Color(red: 0.15, green: 0.1, blue: 0.0),
                                    name: "Phi 3.5",
                                    description: "Microsoft's efficient small language model. Optimized for on-device performance with impressive capabilities.",
                                    modelsCount: "2 models",
                                    badges: []
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Hugging Face Section
                        VStack(alignment: .leading, spacing: 12) {
                            DSSectionHeader(title: "Hugging Face")
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ModelCard(
                                    icon: "🤗",
                                    backgroundColor: Color(red: 0.95, green: 0.65, blue: 0.13).opacity(0.2),
                                    name: "SmolLM 2",
                                    description: "Compact and efficient language model. Perfect for resource-constrained environments while maintaining quality.",
                                    modelsCount: "4 models",
                                    badges: ["New"]
                                )
                                
                                ModelCard(
                                    icon: "🌟",
                                    backgroundColor: Color(red: 0.2, green: 0.15, blue: 0.25),
                                    name: "Mistral 7B",
                                    description: "High-performance open-source model. Outstanding balance of efficiency and capability for various tasks.",
                                    modelsCount: "2 models",
                                    badges: []
                                )
                                
                                ModelCard(
                                    icon: "🚀",
                                    backgroundColor: Color(red: 0.1, green: 0.2, blue: 0.15),
                                    name: "Falcon",
                                    description: "Technology Innovation Institute's powerful LLM. Trained on diverse data for robust general-purpose use.",
                                    modelsCount: "3 models",
                                    badges: []
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 20)
                }
            }
        }
    }
}

struct ModelCard: View {
    let icon: String
    let backgroundColor: Color
    let name: String
    let description: String
    let modelsCount: String
    let badges: [String]
    
    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(icon)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(backgroundColor.opacity(0.28))
                        .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                .stroke(DesignSystem.Colors.border.opacity(0.7), lineWidth: DesignSystem.Layout.borderWidth)
                        )
                    
                    Text(name)
                        .font(DesignSystem.Typography.body().weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                
                Text(description)
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 8) {
                    Text(modelsCount)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    
                    ForEach(badges, id: \.self) { badge in
                        DSChip(text: badge, isActive: true)
                    }
                }
            }
            .padding(16)
            .background(DesignSystem.Colors.surfaceElevated.opacity(0.88))
            .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.border.opacity(0.65), lineWidth: DesignSystem.Layout.borderWidth)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ManageModelsView()
}

