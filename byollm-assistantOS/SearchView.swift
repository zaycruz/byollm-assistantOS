//
//  SearchView.swift
//  byollm-assistantOS
//
//  Created by GPT-5.2 on 12/12/25.
//

import SwiftUI

struct SearchView: View {
    @State private var query: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                NatureTechBackground().ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Search")
                            .font(DesignSystem.Typography.header())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                        
                        DSChip(text: "Coming soon", isActive: false)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .background(DesignSystem.Colors.chrome.opacity(0.98))
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundStyle(DesignSystem.Colors.separator),
                        alignment: .bottom
                    )
                    
                    VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        
                        TextField("Search chats, notes, tasks…", text: $query)
                            .textFieldStyle(.plain)
                            .font(DesignSystem.Typography.body())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        
                        if !query.isEmpty {
                            Button(action: { query = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                            .stroke(DesignSystem.Colors.border.opacity(0.75), lineWidth: DesignSystem.Layout.borderWidth)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Unified search will appear here.\n(Coming soon)")
                            .font(DesignSystem.Typography.body())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    SearchView()
}


