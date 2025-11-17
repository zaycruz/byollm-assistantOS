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
                    
                    Text("Manage models")
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
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Ollama Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Ollama")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Button(action: {
                                    // Add model action
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
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
                            Text("Hugging Face")
                                .font(.headline)
                                .foregroundColor(.gray)
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
                        .font(.title)
                        .frame(width: 44, height: 44)
                        .background(backgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 8) {
                    Text(modelsCount)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    ForEach(badges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

#Preview {
    ManageModelsView()
}

